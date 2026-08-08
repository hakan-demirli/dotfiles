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
const FAN_OVERRIDE = "/var/run/r01-fan.override";

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
  if (c >= 85) return "r01-crit";
  if (c >= 75) return "r01-hot";
  if (c >= 60) return "r01-warm";
  return "r01-ok";
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
    return Promise.all([uci.load("r01"), this.readAll()]);
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

      const cls = "r01-pill " + tempClass(milli);

      const inner = [
        E("div", { class: "r01-pill-label" }, [s.label]),
        E("div", { class: "r01-pill-temp" }, [fmtTemp(milli)]),
      ];
      if (crit > 0)
        inner.push(
          E("div", { class: "r01-pill-sub" }, ["critical: " + fmtTemp(crit)]),
        );
      if (throttle > 0)
        inner.push(E("div", { class: "r01-pill-throttle" }, ["⚠ throttled"]));

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
          class: "btn r01-mode-btn " + (isActive ? "r01-mode-active" : ""),
          title: m.hint,
          click: ui.createHandlerFn(this, "pickMode", m.id),
        },
        [m.label],
      );
    }, this);

    const sliderRow = E(
      "div",
      {
        class: "r01-slider-row",
        style: selectedMode === "manual" ? "" : "display:none",
      },
      [
        E("label", { for: "r01-pwm-slider" }, ["Manual PWM"]),
        E("input", {
          type: "range",
          min: "0",
          max: "255",
          step: "1",
          value: String(manualPwm),
          id: "r01-pwm-slider",
          change: ui.createHandlerFn(self, "changeManualPwm"),
          input: function (ev) {
            document.getElementById("r01-pwm-value").textContent =
              ev.target.value +
              " (" +
              Math.round((ev.target.value * 100) / 255) +
              "%)";
          },
        }),
        E("span", { id: "r01-pwm-value" }, [
          manualPwm + " (" + Math.round((manualPwm * 100) / 255) + "%)",
        ]),
      ],
    );

    const stateBits = [];
    stateBits.push(
      E("span", { class: "r01-state" }, [
        "mode_raw: " + { 0: "off", 1: "manual", 2: "auto" }[pwmEnable] ||
          String(pwmEnable),
      ]),
    );
    stateBits.push(
      E("span", { class: "r01-state" }, [
        "pwm: " + pwm + " (" + fmtPercent(pwm) + ")",
      ]),
    );
    stateBits.push(E("span", { class: "r01-state" }, ["rpm: " + rpm]));
    if (overridden)
      stateBits.push(
        E("span", { class: "r01-state r01-override" }, [
          "⚠ safety watchdog active",
        ]),
      );

    return E("div", { class: "r01-card" }, [
      E("h3", {}, ["Fan"]),
      E("div", { class: "r01-mode-row" }, buttons),
      E("div", { class: "r01-hint" }, [
        MODES.find(function (m) {
          return m.id === selectedMode;
        }).hint,
      ]),
      sliderRow,
      E("div", { class: "r01-state-row" }, stateBits),
    ]);
  },

  pickMode(mode) {
    uci.set("r01", "fan", "mode", mode);
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
    uci.set("r01", "fan", "manual_pwm", String(v));
    uci.set("r01", "fan", "mode", "manual");
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
        const sensorsEl = document.getElementById("r01-sensors");
        if (sensorsEl) dom.content(sensorsEl, this.renderSensors(values));

        const fanEl = document.getElementById("r01-fan");
        if (fanEl) {
          const mode = uci.get("r01", "fan", "mode") || "auto";
          const manualPwm = parseInt(
            uci.get("r01", "fan", "manual_pwm") || "128",
            10,
          );
          dom.content(fanEl, this.renderFan(values, mode, manualPwm));
        }
      }, this),
    );
  },

  render([_unused, values]) {
    const mode = uci.get("r01", "fan", "mode") || "auto";
    const manualPwm = parseInt(
      uci.get("r01", "fan", "manual_pwm") || "128",
      10,
    );

    poll.add(L.bind(this.refresh, this), 3);

    const style = E("style", {}, [
      ".r01-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.6rem;margin:.6rem 0}" +
        ".r01-pill{border-radius:8px;padding:.7rem .8rem;color:#fff;box-shadow:0 1px 2px rgba(0,0,0,.15)}" +
        ".r01-pill-label{font-size:.85rem;opacity:.85}" +
        ".r01-pill-temp{font-size:1.4rem;font-weight:600;margin-top:.2rem}" +
        ".r01-pill-sub{font-size:.7rem;opacity:.7;margin-top:.15rem}" +
        ".r01-pill-throttle{font-size:.75rem;background:rgba(0,0,0,.25);display:inline-block;padding:.1rem .3rem;border-radius:4px;margin-top:.3rem}" +
        ".r01-ok{background:#3a8a3a}" +
        ".r01-warm{background:#c08b1e}" +
        ".r01-hot{background:#d46b1c}" +
        ".r01-crit{background:#b03030}" +
        ".r01-card{border:1px solid #ccc;border-radius:8px;padding:.8rem 1rem;margin:.8rem 0;background:rgba(0,0,0,.02)}" +
        ".r01-card h3{margin-top:0}" +
        ".r01-mode-row{display:flex;flex-wrap:wrap;gap:.4rem;margin:.4rem 0}" +
        ".r01-mode-btn{min-width:7rem}" +
        ".r01-mode-active{background:#3070d0;color:#fff;border-color:#3070d0}" +
        ".r01-slider-row{margin-top:.6rem;display:flex;align-items:center;gap:.6rem;flex-wrap:wrap}" +
        ".r01-slider-row input[type=range]{flex:1;min-width:200px}" +
        ".r01-state-row{margin-top:.6rem;display:flex;flex-wrap:wrap;gap:.8rem;font-family:monospace;font-size:.85rem;opacity:.85}" +
        ".r01-state{padding:.15rem .4rem;border-radius:4px;background:rgba(0,0,0,.05)}" +
        ".r01-override{background:#b03030;color:#fff}" +
        ".r01-hint{font-size:.8rem;opacity:.7;margin:.2rem 0 .4rem 0}",
    ]);

    return E(
      [],
      [
        style,
        E("h2", {}, ["r01 Hardware"]),
        E("p", { class: "cbi-map-descr" }, [
          "Live sensor readings and fan control for the GL-BE10000. Fan mode persists in /etc/config/r01 and re-applies on boot.",
        ]),

        E("div", { class: "r01-card" }, [
          E("h3", {}, ["Temperatures"]),
          E(
            "div",
            { id: "r01-sensors", class: "r01-grid" },
            this.renderSensors(values),
          ),
        ]),

        E("div", { id: "r01-fan" }, this.renderFan(values, mode, manualPwm)),
      ],
    );
  },
});
