"use strict";
"require view";
"require dom";
"require fs";
"require uci";
"require poll";
"require ui";

const SENSORS = [
  { key: "cpu", label: "CPU", path: "/sys/class/thermal/thermal_zone0/temp" },
  {
    key: "phy",
    label: "PHY (Eth)",
    path: "/sys/class/hwmon/hwmon1/temp1_input",
  },
  {
    key: "w2g",
    label: "WiFi 2.4 GHz",
    path: "/sys/class/hwmon/hwmon3/temp1_input",
    throttle: "/sys/class/hwmon/hwmon3/throttle1",
    crit: "/sys/class/hwmon/hwmon3/temp1_crit",
  },
  {
    key: "w5g",
    label: "WiFi 5 GHz",
    path: "/sys/class/hwmon/hwmon4/temp1_input",
    throttle: "/sys/class/hwmon/hwmon4/throttle1",
    crit: "/sys/class/hwmon/hwmon4/temp1_crit",
  },
  {
    key: "w6g",
    label: "WiFi 6 GHz",
    path: "/sys/class/hwmon/hwmon5/temp1_input",
    throttle: "/sys/class/hwmon/hwmon5/throttle1",
    crit: "/sys/class/hwmon/hwmon5/temp1_crit",
  },
];

const FAN_RPM_PATH = "/sys/class/hwmon/hwmon2/fan1_input";
const FAN_PWM_PATH = "/sys/class/hwmon/hwmon2/pwm1";
const FAN_ENABLE_PATH = "/sys/class/hwmon/hwmon2/pwm1_enable";
const FAN_OVERRIDE = "/var/run/router-fan.override";

const MODES = [
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

function readInt(path) {
  return L.resolveDefault(fs.read(path), "0").then(function (s) {
    const n = parseInt((s || "0").trim(), 10);
    return Number.isFinite(n) ? n : 0;
  });
}

function tempClass(milliC) {
  const c = milliC / 1000;
  if (c >= 85) return "router-crit";
  if (c >= 75) return "router-hot";
  if (c >= 60) return "router-warm";
  return "router-ok";
}

function fmtTemp(milliC) {
  return "%.1f °C".format(milliC / 1000);
}
function fmtPercent(n255) {
  return "%d%%".format(Math.round((n255 * 100) / 255));
}

return view.extend({
  handleSaveApply: null,
  handleSave: null,
  handleReset: null,

  load() {
    return Promise.all([uci.load("router"), this.readAll()]);
  },

  readAll() {
    const tasks = [
      readInt(FAN_RPM_PATH),
      readInt(FAN_PWM_PATH),
      readInt(FAN_ENABLE_PATH),
      L.resolveDefault(fs.stat(FAN_OVERRIDE), null).then(function (st) {
        return st !== null;
      }),
    ];
    for (const s of SENSORS) {
      tasks.push(readInt(s.path));
      tasks.push(s.throttle ? readInt(s.throttle) : Promise.resolve(0));
      tasks.push(s.crit ? readInt(s.crit) : Promise.resolve(0));
    }
    return Promise.all(tasks);
  },

  renderSensors(values) {
    const pills = [];
    for (let i = 0; i < SENSORS.length; i++) {
      const s = SENSORS[i];
      const off = 4 + i * 3;
      const milli = values[off];
      const throttle = values[off + 1];
      const crit = values[off + 2];

      const cls = "router-pill " + tempClass(milli);

      const inner = [
        E("div", { class: "router-pill-label" }, [s.label]),
        E("div", { class: "router-pill-temp" }, [fmtTemp(milli)]),
      ];
      if (crit > 0)
        inner.push(
          E("div", { class: "router-pill-sub" }, [
            "critical: " + fmtTemp(crit),
          ]),
        );
      if (throttle > 0)
        inner.push(
          E("div", { class: "router-pill-throttle" }, ["⚠ throttled"]),
        );

      pills.push(E("div", { class: cls }, inner));
    }
    return pills;
  },

  renderFan(values, selectedMode, manualPwm) {
    const rpm = values[0];
    const pwm = values[1];
    const pwmEnable = values[2];
    const overridden = values[3];

    const self = this;
    const buttons = MODES.map(function (m) {
      const isActive = m.id === selectedMode;
      return E(
        "button",
        {
          class:
            "btn router-mode-btn " + (isActive ? "router-mode-active" : ""),
          title: m.hint,
          click: ui.createHandlerFn(this, "pickMode", m.id),
        },
        [m.label],
      );
    }, this);

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

    const stateBits = [];
    stateBits.push(
      E("span", { class: "router-state" }, [
        "mode_raw: " + { 0: "off", 1: "manual", 2: "auto" }[pwmEnable] ||
          String(pwmEnable),
      ]),
    );
    stateBits.push(
      E("span", { class: "router-state" }, [
        "pwm: " + pwm + " (" + fmtPercent(pwm) + ")",
      ]),
    );
    stateBits.push(E("span", { class: "router-state" }, ["rpm: " + rpm]));
    if (overridden)
      stateBits.push(
        E("span", { class: "router-state router-override" }, [
          "⚠ safety watchdog active",
        ]),
      );

    return E("div", { class: "router-card" }, [
      E("h3", {}, ["Fan"]),
      E("div", { class: "router-mode-row" }, buttons),
      E("div", { class: "router-hint" }, [
        MODES.find(function (m) {
          return m.id === selectedMode;
        }).hint,
      ]),
      sliderRow,
      E("div", { class: "router-state-row" }, stateBits),
    ]);
  },

  pickMode(mode) {
    uci.set("router", "fan", "mode", mode);
    return uci
      .save()
      .then(function () {
        return uci.apply();
      })
      .then(
        L.bind(function () {
          ui.addNotification(
            null,
            [E("p", {}, ["Fan mode set to ", E("b", {}, [mode]), "."])],
            "info",
          );
          return this.refresh();
        }, this),
      )
      .catch(function (err) {
        ui.addNotification(
          null,
          [E("p", {}, ["Failed to apply fan mode: ", err.message])],
          "danger",
        );
      });
  },

  changeManualPwm(ev) {
    const v = parseInt(ev.target.value, 10);
    if (!Number.isFinite(v) || v < 0 || v > 255) return;
    uci.set("router", "fan", "manual_pwm", String(v));
    uci.set("router", "fan", "mode", "manual");
    return uci
      .save()
      .then(function () {
        return uci.apply();
      })
      .then(
        L.bind(function () {
          return this.refresh();
        }, this),
      )
      .catch(function (err) {
        ui.addNotification(
          null,
          [E("p", {}, ["Failed to apply manual PWM: ", err.message])],
          "danger",
        );
      });
  },

  refresh() {
    return this.readAll().then(
      L.bind(function (values) {
        const sensorsEl = document.getElementById("router-sensors");
        if (sensorsEl) dom.content(sensorsEl, this.renderSensors(values));

        const fanEl = document.getElementById("router-fan");
        if (fanEl) {
          const mode = uci.get("router", "fan", "mode") || "auto";
          const manualPwm = parseInt(
            uci.get("router", "fan", "manual_pwm") || "128",
            10,
          );
          dom.content(fanEl, this.renderFan(values, mode, manualPwm));
        }
      }, this),
    );
  },

  render([_unused, values]) {
    const mode = uci.get("router", "fan", "mode") || "auto";
    const manualPwm = parseInt(
      uci.get("router", "fan", "manual_pwm") || "128",
      10,
    );

    poll.add(L.bind(this.refresh, this), 3);

    const style = E("style", {}, [
      ".router-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.6rem;margin:.6rem 0}" +
        ".router-pill{border-radius:8px;padding:.7rem .8rem;color:#fff;box-shadow:0 1px 2px rgba(0,0,0,.15)}" +
        ".router-pill-label{font-size:.85rem;opacity:.85}" +
        ".router-pill-temp{font-size:1.4rem;font-weight:600;margin-top:.2rem}" +
        ".router-pill-sub{font-size:.7rem;opacity:.7;margin-top:.15rem}" +
        ".router-pill-throttle{font-size:.75rem;background:rgba(0,0,0,.25);display:inline-block;padding:.1rem .3rem;border-radius:4px;margin-top:.3rem}" +
        ".router-ok{background:#3a8a3a}" +
        ".router-warm{background:#c08b1e}" +
        ".router-hot{background:#d46b1c}" +
        ".router-crit{background:#b03030}" +
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
        ".router-hint{font-size:.8rem;opacity:.7;margin:.2rem 0 .4rem 0}",
    ]);

    return E(
      [],
      [
        style,
        E("h2", {}, ["router Hardware"]),
        E("p", { class: "cbi-map-descr" }, [
          "Live sensor readings and fan control for the GL-BE10000. Fan mode persists in /etc/config/router and re-applies on boot.",
        ]),

        E("div", { class: "router-card" }, [
          E("h3", {}, ["Temperatures"]),
          E(
            "div",
            { id: "router-sensors", class: "router-grid" },
            this.renderSensors(values),
          ),
        ]),

        E("div", { id: "router-fan" }, this.renderFan(values, mode, manualPwm)),
      ],
    );
  },
});
