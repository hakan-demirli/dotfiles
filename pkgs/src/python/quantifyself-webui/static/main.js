import { drawCpuChart } from "./cpu_plot.js";
import { drawCpuHistoryChart } from "./cpu_history_plot.js";
import { drawRamHistoryChart } from "./ram_history_plot.js";
import { drawRamChart } from "./ram_plot.js";
import { drawWindowRegexPieChart } from "./window_regex_pie.js";
import { drawWindowRegexStackedChart } from "./window_regex_stacked.js";
import { drawWindowRegexGridChart } from "./daily_grid_plot.js";

const plots = [
  // {
  //   id: "cpu-chart",
  //   title: "CPU Usage",
  //   drawFunction: drawCpuChart,
  //   unit: "one-unit",
  // },
  // {
  //   id: "ram-chart",
  //   title: "RAM Usage",
  //   drawFunction: drawRamChart,
  //   unit: "one-unit",
  // },
  {
    id: "window-regex-stacked-chart",
    title: "Window Regex Stacked",
    drawFunction: drawWindowRegexStackedChart,
    unit: "two-unit",
  },
  {
    id: "window-regex-pie-chart",
    title: "Window Regex Pie",
    drawFunction: drawWindowRegexPieChart,
    unit: "two-unit",
  },
  // {
  //   id: "cpu-history-chart",
  //   title: "CPU History",
  //   drawFunction: drawCpuHistoryChart,
  //   unit: "one-unit",
  //   // gridColumn: "1 / -1",
  // },
  // {
  //   id: "ram-history-chart",
  //   title: "RAM History",
  //   drawFunction: drawRamHistoryChart,
  //   unit: "one-unit",
  // },
  {
    id: "window-regex-grid-chart",
    title: "Window Grid",
    drawFunction: drawWindowRegexGridChart,
    unit: "four-unit",
  },
];

document.addEventListener("DOMContentLoaded", () => {
  const dashboard = document.getElementById("dashboard");

  plots.forEach(({ id, title, drawFunction, unit, gridColumn }) => {
    const chartContainer = document.createElement("div");
    chartContainer.id = id;
    chartContainer.classList.add("chart", unit);

    if (gridColumn) {
      chartContainer.style.gridColumn = gridColumn; // Explicit column placement
    }

    const chartTitle = document.createElement("h3");
    chartTitle.textContent = title;
    chartTitle.style.textAlign = "center";
    chartContainer.appendChild(chartTitle);

    dashboard.appendChild(chartContainer);
    drawFunction(`#${id}`);
  });
});
