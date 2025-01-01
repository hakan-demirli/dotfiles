import * as d3 from "https://cdn.skypack.dev/d3";
import flatpickr from "https://cdn.skypack.dev/flatpickr";
import { BaseChart } from "./chart_base.js";
import { processData, calculateWorkDuration } from "./data_handler.js";
import { getColorForWorkDuration } from "./utils.js";
import { DB_FILE } from "./constants.js";

export async function drawWindowRegexPieChart(
  containerId,
  selectedDate = new Date(),
) {
  console.log("drawWindowRegexPieChart called with date:", selectedDate);
  const chart = new BaseChart(containerId);
  chart.clearContainer();

  // Create a flex container for calendar and pie chart
  const flexContainer = chart.container
    .append("div")
    .style("display", "flex")
    .style("justify-content", "space-between")
    .style("height", "100%");

  // Calendar container
  const calendarContainer = flexContainer.append("div").style("width", "48%");

  // Pie chart container
  const pieChartContainer = flexContainer.append("div").style("width", "48%");

  // Initialize flatpickr inline
  flatpickr(calendarContainer.node(), {
    inline: true,
    dateFormat: "Y-m-d",
    defaultDate: selectedDate,
    onReady: async function (_, __, fp) {
      console.log("Flatpickr onReady");

      // Trigger an initial data load for today by calling onChange programmatically
      fp.setDate(selectedDate); // Set the default date (today)
      fp.close(); // Optionally close the calendar popup if you don't want it open initially

      fp.calendarContainer
        .querySelectorAll(".flatpickr-day")
        .forEach(async (day) => {
          const date = new Date(day.dateObj);
          const workDuration = await calculateWorkDuration(date, DB_FILE);
          const backgroundColor = getColorForWorkDuration(workDuration);
          day.style.backgroundColor = backgroundColor;

          const lightness = parseFloat(
            backgroundColor.match(/\d+\.?\d*%/g)?.[1],
          );
          day.style.color = lightness > 50 ? "black" : "white";
        });
    },
    onChange: function (selectedDates, dateStr) {
      console.log("Flatpickr onChange:", selectedDates);
      drawWindowRegexPieChart(containerId, selectedDates[0]);
    },
    onMonthChange: async function (_, __, fp) {
      console.log("Flatpickr onMonthChange");
      fp.calendarContainer
        .querySelectorAll(".flatpickr-day")
        .forEach(async (day) => {
          const date = new Date(day.dateObj);
          const workDuration = await calculateWorkDuration(date, DB_FILE);
          const backgroundColor = getColorForWorkDuration(workDuration);
          day.style.backgroundColor = backgroundColor;

          const lightness = parseFloat(
            backgroundColor.match(/\d+\.?\d*%/g)?.[1],
          );
          day.style.color = lightness > 50 ? "black" : "white";
        });
    },
  });

  const { durationData, hierarchicalData } = await processData(
    selectedDate,
    DB_FILE,
  );

  console.log("Processed data:", { durationData, hierarchicalData });

  if (durationData.length === 0) {
    console.error("No data available for the selected date.");
    const emptyData = {
      name: "Root",
      children: [],
    };

    const { width, height } = chart.getDimensions();
    const radius = Math.min(width, height) / 2;

    const svg = pieChartContainer
      .append("svg")
      .attr("width", "100%")
      .attr("height", "100%")
      .append("g");
    // .attr("transform", `translate(${width / 2},${height / 2})`);

    const root = d3.hierarchy(emptyData).sum((d) => d.value);
    console.log("Empty hierarchy root:", root);
    const partition = d3.partition().size([2 * Math.PI, radius]);

    const arc = d3
      .arc()
      .startAngle((d) => d.x0)
      .endAngle((d) => d.x1)
      .innerRadius((d) => d.y0)
      .outerRadius((d) => d.y1);

    partition(root);
    console.log("Empty root after partition:", root);

    svg
      .append("text")
      .attr("class", "no-data-text")
      .attr("text-anchor", "middle")
      .attr("dy", "0.35em")
      .style("font-size", "1.5em")
      .style("font-weight", "bold")
      .text("No data available");

    return;
  }

  const uncategorizedEntries = durationData.filter(
    (d) => d.group === "Uncategorized",
  );

  if (uncategorizedEntries.length > 0) {
    console.log("Uncategorized Entries:", uncategorizedEntries);
  }

  const { width, height } = chart.getDimensions();
  const pieWidth = width * 0.48;
  const pieHeight = height * 0.95;
  const radius = Math.min(pieWidth, pieHeight) / 1.62;

  const svg = pieChartContainer
    .append("svg")
    .attr("width", "100%")
    .attr("height", "100%")
    .append("g")
    .attr("transform", `translate(${pieWidth / 2}, ${pieHeight / 1.3})`);

  console.log("hierarchicalData before hierarchy:", hierarchicalData);
  const root = d3.hierarchy(hierarchicalData).sum((d) => d.value);
  console.log("Hierarchy root:", root);
  const partition = d3.partition().size([2 * Math.PI, radius]);

  console.log("Arc function:", d3.arc);
  const arc = d3
    .arc()
    .startAngle((d) => {
      console.log("Start angle called for:", d);
      return d.x0;
    })
    .endAngle((d) => {
      console.log("End angle called for:", d);
      return d.x1;
    })
    .innerRadius((d) => {
      console.log("Inner radius called for:", d);
      return d.y0;
    })
    .outerRadius((d) => {
      console.log("Outer radius called for:", d);
      return d.y1;
    });

  partition(root);
  console.log("Root after partition:", root);

  const numMainCategories = Object.keys(
    hierarchicalData.children.reduce((acc, d) => {
      acc[d.name] = 1;
      return acc;
    }, {}),
  ).length;

  console.log("Number of main categories:", numMainCategories);

  const hueScale = d3
    .scaleLinear()
    .domain([0, numMainCategories])
    .range([0, 360]);

  console.log("Hue scale:", hueScale);

  const color = (d) => {
    if (d.depth === 0) {
      console.log("Color for root:", d);
      return "#ddd";
    }
    if (d.depth === 1) {
      const index = d.parent.children.indexOf(d);
      const hue = hueScale(index);
      console.log("Color for main category:", d, "hue:", hue);
      return d3.hsl(hue, 0.8, 0.5).toString();
    } else {
      const parentColor = d3.hsl(color(d.parent));
      const numSiblings = d.parent.children.length;
      const siblingIndex = d.parent.children.indexOf(d);
      const lightnessScale = d3
        .scaleLinear()
        .domain([0, numSiblings - 1])
        .range([0.8, 0.4]);
      const lightness = lightnessScale(siblingIndex);
      console.log("Color for subcategory:", d, "lightness:", lightness);
      return d3.hsl(parentColor.h, parentColor.s, lightness).toString();
    }
  };

  console.log("Color function:", color);

  console.log("Root descendants:", root.descendants());

  const pathGroups = svg
    .selectAll("path")
    .data(root.descendants())
    .join("g")
    .attr("class", "path-group");

  pathGroups
    .append("path")
    .attr("d", (d) => {
      console.log("Drawing path for:", d);
      console.log("Path data:", arc(d));
      return arc(d);
    })
    .style("fill", (d) => {
      const calculatedColor = color(d);
      console.log("Filling path for:", d, "with color:", calculatedColor);
      return calculatedColor;
    })
    .style("stroke", "#fff")
    .on("mouseover", function (event, d) {
      console.log("Mouseover on:", d);
      d3.select(this).style("opacity", 0.7);
      const durationInSeconds = d.value;
      const hours = Math.floor(durationInSeconds / 3600);
      const minutes = Math.floor((durationInSeconds % 3600) / 60);
      const seconds = Math.floor(durationInSeconds % 60);
      chart.showTooltip(
        event,
        `${d.data.name}: ${hours}h ${minutes}m ${seconds}s`,
      );
    })
    .on("mousemove", (event) => {
      console.log("Mousemove");
      chart.moveTooltip(event);
    })
    .on("mouseout", function () {
      console.log("Mouseout");
      d3.select(this).style("opacity", 1);
      chart.hideTooltip();
    });

  pathGroups
    .append("text") // Use pathGroups instead of creating a new selection
    .attr("transform", (d) => {
      console.log("Text transform for:", d);
      const centroid = arc.centroid(d);
      console.log("Centroid:", centroid);
      return `translate(${centroid})`;
    })
    .attr("dy", "0.35em")
    .style("text-anchor", "middle")
    .text((d) => {
      const angle = (d.x1 - d.x0) * (180 / Math.PI);
      // console.log("Text for:", d, "angle:", angle);
      return angle > 10 ? d.data.name : "";
    });

  const totalDuration = durationData.reduce((sum, d) => sum + d.duration, 0);
  const totalHours = Math.floor(totalDuration / 3600);
  const totalMinutes = Math.floor((totalDuration % 3600) / 60);
  const formattedTotal = `${totalHours}h ${totalMinutes}m`;

  console.log("Total duration:", totalDuration);
  console.log("Formatted total:", formattedTotal);

  svg
    .append("text")
    .attr("class", "center-text")
    .attr("text-anchor", "middle")
    .attr("dy", "0.35em")
    .style("font-size", "1.5em")
    .style("font-weight", "bold")
    .text(formattedTotal);

  chart.addResizeListener(() => {
    console.log("Resizing chart");
    drawWindowRegexPieChart(containerId, selectedDate);
  });
}
