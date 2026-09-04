"use strict";
"require view";
"require dom";
"require fs";
"require uci";
"require poll";
"require ui";

const HARDWARE_STATUS = "/usr/libexec/router-hardware-status";
const CAPTIVE_STATUS = "/usr/libexec/router-captive-status";
const ETHERNET_STATUS = "/usr/libexec/router-ethernet-status";
const ETHERNET_APPLY = "/usr/libexec/router-ethernet-apply";

const SENSORS = [
  { key: "cpu", label: "CPU" },
  { key: "phy", label: "PHY (Eth)" },
  { key: "w2g", label: "WiFi 2.4 GHz" },
  { key: "w5g", label: "WiFi 5 GHz" },
  { key: "w6g", label: "WiFi 6 GHz" },
];

const FAN_MODES = [
  { id: "auto", label: "Auto", hint: "Kernel thermal governor decides." },
  {
    id: "quiet",
    label: "Quiet",
    hint: "Fan off. Watchdog falls back to Auto on overheat.",
  },
  { id: "aggressive", label: "Aggressive", hint: "Fan always at 100%." },
  {
    id: "manual",
    label: "Manual",
    hint: "Set PWM duty directly with the slider below.",
  },
];

const ETHERNET_MODES = [
  {
    id: "dual-lan",
    label: "2x LAN",
    hint: "Both ports are LAN. Wi-Fi is the only uplink. Use this when the venue has no Ethernet.",
  },
  {
    id: "wired-wan",
    label: "WAN + LAN",
    hint: "eth0 takes the venue uplink over DHCP, eth1 stays LAN. Wi-Fi remains a fallback at a higher metric.",
  },
];

const CAPTIVE_STATES = {
  online: {
    label: "Online",
    css: "router-ok",
    hint: "The uplink answers the connectivity probe. No portal in the way.",
  },
  portal: {
    label: "Captive portal",
    css: "router-warm",
    hint: "The uplink intercepts traffic. Open the portal below and sign in.",
  },
  offline: {
    label: "Offline",
    css: "router-unavailable",
    hint: "The probe did not complete. There is no usable uplink right now.",
  },
};

const CAPTIVE_STALE_AFTER = 180;

function numberOrNull(value) {
  return Number.isFinite(value) ? value : null;
}

function stringOrNull(value) {
  return typeof value === "string" && value !== "" ? value : null;
}

function boolOrNull(value) {
  return typeof value === "boolean" ? value : null;
}

function fmtTemp(milliC) {
  return "%.1f °C".format(milliC / 1000);
}

function fmtPercent(n255) {
  return "%d%%".format(Math.round((n255 * 100) / 255));
}

function fmtDuration(seconds) {
  const total = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(total / 60);
  if (minutes < 1) return "%d s".format(total);
  return "%d min %d s".format(minutes, total % 60);
}

function tempClass(milliC) {
  const c = milliC / 1000;
  if (c >= 85) return "router-crit";
  if (c >= 75) return "router-hot";
  if (c >= 60) return "router-warm";
  return "router-ok";
}

function emptyHardware(error) {
  const sensors = {};
  for (const sensor of SENSORS)
    sensors[sensor.key] = { temp: null, throttle: null, crit: null };
  return {
    sensors,
    fan: { rpm: null, pwm: null, enable: null, override: false },
    error: error || null,
  };
}

function normalizeHardware(raw) {
  if (!raw || typeof raw !== "object")
    throw new TypeError("Invalid hardware reply");

  const status = emptyHardware(null);
  for (const sensor of SENSORS) {
    const value = raw.sensors && raw.sensors[sensor.key];
    if (value && typeof value === "object") {
      status.sensors[sensor.key] = {
        temp: numberOrNull(value.temp),
        throttle: numberOrNull(value.throttle),
        crit: numberOrNull(value.crit),
      };
    }
  }
  if (raw.fan && typeof raw.fan === "object") {
    status.fan = {
      rpm: numberOrNull(raw.fan.rpm),
      pwm: numberOrNull(raw.fan.pwm),
      enable: numberOrNull(raw.fan.enable),
      override: raw.fan.override === true,
    };
  }
  return status;
}

function emptyCaptive(error) {
  return {
    enabled: null,
    state: null,
    age: null,
    portalUrl: null,
    portalHost: null,
    rebindProtection: null,
    bypass: { active: false, remaining: null, domains: [] },
    error: error || null,
  };
}

function normalizeCaptive(raw) {
  if (!raw || typeof raw !== "object")
    throw new TypeError("Invalid captive reply");

  const status = emptyCaptive(null);
  status.enabled = boolOrNull(raw.enabled);
  status.state = stringOrNull(raw.state);
  status.age = numberOrNull(raw.age);
  status.portalUrl = stringOrNull(raw.portal_url);
  status.portalHost = stringOrNull(raw.portal_host);
  status.rebindProtection = boolOrNull(raw.rebind_protection);

  if (raw.bypass && typeof raw.bypass === "object") {
    status.bypass = {
      active: raw.bypass.active === true,
      remaining: numberOrNull(raw.bypass.remaining),
      domains: Array.isArray(raw.bypass.domains)
        ? raw.bypass.domains.filter(function (d) {
            return typeof d === "string" && d !== "";
          })
        : [],
    };
  }
  return status;
}

function emptyEthernet(error) {
  return {
    mode: null,
    desired: null,
    ports: {},
    wan: { up: null, address: null },
    error: error || null,
  };
}

function normalizeEthernet(raw) {
  if (!raw || typeof raw !== "object")
    throw new TypeError("Invalid ethernet reply");

  const status = emptyEthernet(null);
  status.mode = stringOrNull(raw.mode);
  status.desired = stringOrNull(raw.desired);

  if (raw.ports && typeof raw.ports === "object") {
    for (const name of Object.keys(raw.ports)) {
      const port = raw.ports[name];
      if (!port || typeof port !== "object") continue;
      status.ports[name] = {
        role: stringOrNull(port.role),
        carrier: boolOrNull(port.carrier),
      };
    }
  }
  if (raw.wan && typeof raw.wan === "object") {
    status.wan = {
      up: boolOrNull(raw.wan.up),
      address: stringOrNull(raw.wan.address),
    };
  }
  return status;
}

function readJSON(command, normalize, fallback) {
  return fs
    .exec_direct(command, null, "json")
    .then(normalize)
    .catch(function (err) {
      return fallback(err.message || String(err));
    });
}

function errorBanner(id, message) {
  return E(
    "div",
    {
      id,
      class: "alert-message warning",
      style: message ? "" : "display:none",
    },
    message ? [message] : [],
  );
}

function setBanner(id, message) {
  const el = document.getElementById(id);
  if (!el) return;
  el.style.display = message ? "" : "none";
  dom.content(el, message ? [message] : []);
}

return view.extend({
  handleSaveApply: null,
  handleSave: null,
  handleReset: null,

  load() {
    return Promise.all([uci.load("router"), this.readAll()]);
  },

  readAll() {
    return Promise.all([
      readJSON(HARDWARE_STATUS, normalizeHardware, emptyHardware),
      readJSON(CAPTIVE_STATUS, normalizeCaptive, emptyCaptive),
      readJSON(ETHERNET_STATUS, normalizeEthernet, emptyEthernet),
    ]).then(function ([hardware, captive, ethernet]) {
      return { hardware, captive, ethernet };
    });
  },

  renderEthernet(ethernet) {
    const self = this;
    const active = ethernet.mode;
    const pending =
      ethernet.desired !== null &&
      ethernet.mode !== null &&
      ethernet.desired !== ethernet.mode;

    const buttons = ETHERNET_MODES.map(function (m) {
      return E(
        "button",
        {
          class:
            "btn router-mode-btn " +
            (m.id === active ? "router-mode-active" : ""),
          title: m.hint,
          click: ui.createHandlerFn(self, "pickEthernetMode", m.id),
        },
        [m.label],
      );
    });

    const selected = ETHERNET_MODES.find(function (m) {
      return m.id === active;
    });

    const portPills = Object.keys(ethernet.ports)
      .sort()
      .map(function (name) {
        const port = ethernet.ports[name];
        const linked = port.carrier === true;
        const css =
          port.role === "wan"
            ? linked
              ? "router-ok"
              : "router-warm"
            : "router-unavailable";
        return E("div", { class: "router-pill " + css }, [
          E("div", { class: "router-pill-label" }, [name]),
          E("div", { class: "router-pill-temp" }, [
            port.role === null ? "Unavailable" : port.role.toUpperCase(),
          ]),
          E("div", { class: "router-pill-sub" }, [
            port.carrier === null
              ? "link unavailable"
              : linked
                ? "cable connected"
                : "no cable",
          ]),
        ]);
      });

    const notes = [];
    if (pending)
      notes.push(
        E("div", { class: "router-state router-override" }, [
          "requested " + ethernet.desired + ", still running " + ethernet.mode,
        ]),
      );
    if (active === "unknown")
      notes.push(
        E("div", { class: "router-state router-override" }, [
          "network config does not match either layout",
        ]),
      );
    if (active === "wired-wan")
      notes.push(
        E("div", { class: "router-state" }, [
          ethernet.wan.up === true
            ? "wan: up" +
              (ethernet.wan.address ? " " + ethernet.wan.address : "")
            : "wan: down",
        ]),
      );

    return E("div", { class: "router-card" }, [
      E("h3", {}, ["Ethernet ports"]),
      E("div", { class: "router-mode-row" }, buttons),
      E("div", { class: "router-hint" }, [
        selected
          ? selected.hint
          : "Current layout could not be determined from the network config.",
      ]),
      E("div", { class: "router-grid" }, portPills),
      notes.length ? E("div", { class: "router-state-row" }, notes) : E([], []),
      E("div", { class: "router-hint" }, [
        "eth1 always stays LAN. Switching drops anything connected through eth0.",
      ]),
    ]);
  },

  pickEthernetMode(mode) {
    const current = ETHERNET_MODES.find(function (m) {
      return m.id === mode;
    });
    if (!current) return Promise.resolve();

    return ui
      .showModal("Switch ethernet mode", [
        E("p", {}, [current.hint]),
        E("p", {}, [
          "Anything connected through eth0 loses its link while the change " +
            "applies. eth1 and Wi-Fi are unaffected.",
        ]),
        E("div", { class: "right" }, [
          E("button", { class: "btn", click: ui.hideModal }, ["Cancel"]),
          " ",
          E(
            "button",
            {
              class: "btn cbi-button-action",
              click: ui.createHandlerFn(this, "applyEthernetMode", mode),
            },
            ["Switch to " + current.label],
          ),
        ]),
      ])
      .catch(function () {});
  },

  applyEthernetMode(mode) {
    ui.hideModal();
    return fs
      .exec_direct(ETHERNET_APPLY, [mode], "json")
      .then(
        L.bind(function () {
          ui.addNotification(
            null,
            [E("p", {}, ["Ethernet mode set to ", E("b", {}, [mode]), "."])],
            "info",
          );
          return this.refresh();
        }, this),
      )
      .catch(function (err) {
        ui.addNotification(
          null,
          [E("p", {}, ["Failed to switch ethernet mode: ", err.message])],
          "danger",
        );
      });
  },

  renderCaptive(captive) {
    const known =
      captive.state !== null && CAPTIVE_STATES[captive.state] !== undefined;
    const stale = captive.age === null || captive.age > CAPTIVE_STALE_AFTER;
    const meta = known
      ? CAPTIVE_STATES[captive.state]
      : {
          label: "Unavailable",
          css: "router-unavailable",
          hint: "No probe result has been published yet.",
        };

    const pill = [
      E("div", { class: "router-pill-label" }, ["Uplink"]),
      E("div", { class: "router-pill-temp" }, [meta.label]),
    ];
    if (captive.portalHost)
      pill.push(E("div", { class: "router-pill-sub" }, [captive.portalHost]));
    if (known && stale)
      pill.push(E("div", { class: "router-pill-sub" }, ["result is stale"]));

    const protection =
      captive.rebindProtection === null
        ? { text: "Unavailable", css: "router-unavailable" }
        : captive.rebindProtection
          ? { text: "Enabled", css: "router-ok" }
          : { text: "Disabled", css: "router-warm" };

    const body = [
      E("h3", {}, ["Captive portal"]),
      E("div", { class: "router-grid" }, [
        E("div", { class: "router-pill " + meta.css }, pill),
        E("div", { class: "router-pill " + protection.css }, [
          E("div", { class: "router-pill-label" }, ["DNS rebind protection"]),
          E("div", { class: "router-pill-temp" }, [protection.text]),
        ]),
      ]),
      E("div", { class: "router-hint" }, [meta.hint]),
    ];

    if (captive.portalUrl)
      body.push(
        E("div", { class: "router-hint" }, [
          "Portal: ",
          E(
            "a",
            { href: captive.portalUrl, target: "_blank", rel: "noreferrer" },
            [captive.portalUrl],
          ),
        ]),
      );

    if (captive.enabled === false) {
      body.push(
        E("div", { class: "router-hint" }, [
          "Handling is disabled in /etc/config/router; no portal is detected " +
            "and no domain is allowlisted.",
        ]),
      );
    } else if (captive.bypass.active) {
      body.push(
        E("div", { class: "router-state-row" }, [
          E("span", { class: "router-state router-override" }, [
            "rebind allowlist active",
          ]),
          E("span", { class: "router-state" }, [
            captive.bypass.remaining === null
              ? "expires in: unavailable"
              : "expires in: " + fmtDuration(captive.bypass.remaining),
          ]),
        ]),
      );
      body.push(
        E(
          "div",
          { class: "router-domain-row" },
          captive.bypass.domains.map(function (domain) {
            return E("span", { class: "router-domain" }, [domain]);
          }),
        ),
      );
    } else {
      body.push(
        E("div", { class: "router-hint" }, [
          "No allowlist entry is active. Rebind protection applies to every domain.",
        ]),
      );
    }

    return E("div", { class: "router-card" }, body);
  },

  renderSensors(hardware) {
    return SENSORS.map(function (s) {
      const reading = hardware.sensors[s.key];
      const milli = reading.temp;
      const available = Number.isFinite(milli);
      const inner = [
        E("div", { class: "router-pill-label" }, [s.label]),
        E("div", { class: "router-pill-temp" }, [
          available ? fmtTemp(milli) : "Unavailable",
        ]),
      ];
      if (!available)
        inner.push(
          E("div", { class: "router-pill-sub" }, ["sensor read failed"]),
        );
      if (Number.isFinite(reading.crit) && reading.crit > 0)
        inner.push(
          E("div", { class: "router-pill-sub" }, [
            "critical: " + fmtTemp(reading.crit),
          ]),
        );
      if (Number.isFinite(reading.throttle) && reading.throttle > 0)
        inner.push(
          E("div", { class: "router-pill-throttle" }, ["⚠ throttled"]),
        );
      return E(
        "div",
        {
          class:
            "router-pill " +
            (available ? tempClass(milli) : "router-unavailable"),
        },
        inner,
      );
    });
  },

  renderFan(hardware, selectedMode, manualPwm) {
    const self = this;
    const { rpm, pwm, enable: pwmEnable, override } = hardware.fan;

    const buttons = FAN_MODES.map(function (m) {
      return E(
        "button",
        {
          class:
            "btn router-mode-btn " +
            (m.id === selectedMode ? "router-mode-active" : ""),
          title: m.hint,
          click: ui.createHandlerFn(self, "pickFanMode", m.id),
        },
        [m.label],
      );
    });

    const sliderRow = E(
      "div",
      {
        class: "router-slider-row",
        style: selectedMode === "manual" ? "" : "display:none",
      },
      [
        E("label", { for: "router-pwm-slider" }, ["Manual PWM"]),
        E("input", {
          type: "range",
          min: "0",
          max: "255",
          step: "1",
          value: String(manualPwm),
          id: "router-pwm-slider",
          change: ui.createHandlerFn(self, "changeManualPwm"),
          input: function (ev) {
            document.getElementById("router-pwm-value").textContent =
              ev.target.value +
              " (" +
              Math.round((ev.target.value * 100) / 255) +
              "%)";
          },
        }),
        E("span", { id: "router-pwm-value" }, [
          manualPwm + " (" + Math.round((manualPwm * 100) / 255) + "%)",
        ]),
      ],
    );

    const rawMode = Number.isFinite(pwmEnable)
      ? { 0: "off", 1: "manual", 2: "auto" }[pwmEnable] || String(pwmEnable)
      : "unavailable";

    const stateBits = [
      E("span", { class: "router-state" }, ["mode_raw: " + rawMode]),
      E("span", { class: "router-state" }, [
        Number.isFinite(pwm)
          ? "pwm: " + pwm + " (" + fmtPercent(pwm) + ")"
          : "pwm: unavailable",
      ]),
      E("span", { class: "router-state" }, [
        Number.isFinite(rpm) ? "rpm: " + rpm : "rpm: unavailable",
      ]),
    ];
    if (override)
      stateBits.push(
        E("span", { class: "router-state router-override" }, [
          "⚠ safety watchdog active",
        ]),
      );

    return E("div", { class: "router-card" }, [
      E("h3", {}, ["Fan"]),
      E("div", { class: "router-mode-row" }, buttons),
      E("div", { class: "router-hint" }, [
        FAN_MODES.find(function (m) {
          return m.id === selectedMode;
        }).hint,
      ]),
      sliderRow,
      E("div", { class: "router-state-row" }, stateBits),
    ]);
  },

  pickFanMode(mode) {
    uci.set("router", "fan", "mode", mode);
    return this.commitFan("Fan mode set to " + mode + ".");
  },

  changeManualPwm(ev) {
    const v = parseInt(ev.target.value, 10);
    if (!Number.isFinite(v) || v < 0 || v > 255) return;
    uci.set("router", "fan", "manual_pwm", String(v));
    uci.set("router", "fan", "mode", "manual");
    return this.commitFan(null);
  },

  commitFan(message) {
    return uci
      .save()
      .then(function () {
        return uci.apply();
      })
      .then(
        L.bind(function () {
          if (message)
            ui.addNotification(null, [E("p", {}, [message])], "info");
          return this.refresh();
        }, this),
      )
      .catch(function (err) {
        ui.addNotification(
          null,
          [E("p", {}, ["Failed to apply: ", err.message])],
          "danger",
        );
      });
  },

  refresh() {
    return this.readAll().then(
      L.bind(function (status) {
        setBanner(
          "router-status-error",
          status.hardware.error
            ? "Sensor RPC failed: " + status.hardware.error
            : status.captive.error
              ? "Captive status failed: " + status.captive.error
              : status.ethernet.error
                ? "Ethernet status failed: " + status.ethernet.error
                : null,
        );

        const ethernetEl = document.getElementById("router-ethernet");
        if (ethernetEl)
          dom.content(ethernetEl, this.renderEthernet(status.ethernet));

        const captiveEl = document.getElementById("router-captive");
        if (captiveEl)
          dom.content(captiveEl, this.renderCaptive(status.captive));

        const sensorsEl = document.getElementById("router-sensors");
        if (sensorsEl)
          dom.content(sensorsEl, this.renderSensors(status.hardware));

        const fanEl = document.getElementById("router-fan");
        if (fanEl) {
          const mode = uci.get("router", "fan", "mode") || "auto";
          const manualPwm = parseInt(
            uci.get("router", "fan", "manual_pwm") || "128",
            10,
          );
          dom.content(fanEl, this.renderFan(status.hardware, mode, manualPwm));
        }
      }, this),
    );
  },

  render([_unused, status]) {
    const fanMode = uci.get("router", "fan", "mode") || "auto";
    const manualPwm = parseInt(
      uci.get("router", "fan", "manual_pwm") || "128",
      10,
    );

    poll.add(L.bind(this.refresh, this), 5);

    const style = E("style", {}, [
      ".router-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:.6rem;margin:.6rem 0}" +
        ".router-pill{border-radius:8px;padding:.7rem .8rem;color:#fff;box-shadow:0 1px 2px rgba(0,0,0,.15)}" +
        ".router-pill-label{font-size:.85rem;opacity:.85}" +
        ".router-pill-temp{font-size:1.4rem;font-weight:600;margin-top:.2rem}" +
        ".router-pill-sub{font-size:.7rem;opacity:.75;margin-top:.15rem;word-break:break-all}" +
        ".router-pill-throttle{font-size:.75rem;background:rgba(0,0,0,.25);display:inline-block;padding:.1rem .3rem;border-radius:4px;margin-top:.3rem}" +
        ".router-ok{background:#3a8a3a}" +
        ".router-warm{background:#c08b1e}" +
        ".router-hot{background:#d46b1c}" +
        ".router-crit{background:#b03030}" +
        ".router-unavailable{background:#666}" +
        ".router-card{border:1px solid #ccc;border-radius:8px;padding:.8rem 1rem;margin:.8rem 0;background:rgba(0,0,0,.02)}" +
        ".router-card h3{margin-top:0}" +
        ".router-mode-row{display:flex;flex-wrap:wrap;gap:.4rem;margin:.4rem 0}" +
        ".router-mode-btn{min-width:7rem}" +
        ".router-mode-active{background:#3070d0;color:#fff;border-color:#3070d0}" +
        ".router-slider-row{margin-top:.6rem;display:flex;align-items:center;gap:.6rem;flex-wrap:wrap}" +
        ".router-slider-row input[type=range]{flex:1;min-width:200px}" +
        ".router-state-row{margin-top:.6rem;display:flex;flex-wrap:wrap;gap:.8rem;font-family:monospace;font-size:.85rem;opacity:.85}" +
        ".router-state{padding:.15rem .4rem;border-radius:4px;background:rgba(0,0,0,.05)}" +
        ".router-override{background:#b03030;color:#fff}" +
        ".router-domain-row{margin-top:.5rem;display:flex;flex-wrap:wrap;gap:.35rem}" +
        ".router-domain{font-family:monospace;font-size:.8rem;padding:.15rem .45rem;border-radius:4px;background:rgba(0,0,0,.08)}" +
        ".router-hint{font-size:.8rem;opacity:.7;margin:.2rem 0 .4rem 0}",
    ]);

    return E(
      [],
      [
        style,
        E("h2", {}, ["Router"]),
        E("p", { class: "cbi-map-descr" }, [
          "Uplink, port roles and hardware for the GL-BE10000. All state " +
            "persists in /etc/config/router and re-applies on boot.",
        ]),
        errorBanner(
          "router-status-error",
          status.hardware.error
            ? "Sensor RPC failed: " + status.hardware.error
            : status.captive.error
              ? "Captive status failed: " + status.captive.error
              : status.ethernet.error
                ? "Ethernet status failed: " + status.ethernet.error
                : null,
        ),

        E(
          "div",
          { id: "router-ethernet" },
          this.renderEthernet(status.ethernet),
        ),
        E("div", { id: "router-captive" }, this.renderCaptive(status.captive)),

        E("div", { class: "router-card" }, [
          E("h3", {}, ["Temperatures"]),
          E(
            "div",
            { id: "router-sensors", class: "router-grid" },
            this.renderSensors(status.hardware),
          ),
        ]),

        E(
          "div",
          { id: "router-fan" },
          this.renderFan(status.hardware, fanMode, manualPwm),
        ),
      ],
    );
  },
});
