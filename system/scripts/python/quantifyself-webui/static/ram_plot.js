import { fetchData } from "./api.js";
import * as d3 from "https://cdn.skypack.dev/d3";

// Keep a reference to the resize listener so it doesn't duplicate
let resizeListenerAdded = false;

export async function drawRamChart(containerId) {
  let stroke_width = 1.5;

  const DB_FILE = "/home/emre/.local/share/quantifyself/system/system.duckdb";
  const QUERY = `
    SELECT timestamp, ram_total, ram_used, ram_free, ram_available
    FROM system_metrics
    WHERE timestamp >= NOW() - INTERVAL 1 DAY
    ORDER BY timestamp;
  `;

  const payload = {
    db_file: DB_FILE,
    query: QUERY,
  };

  const data = await fetchData(payload);

  if (data.length === 0) {
    console.error("No RAM data available.");
    return;
  }

  const parsedData = data.map((d) => ({
    timestamp: new Date(d[0]),
    ramTotal: +d[1] / 1024 ** 3, // Convert to GB
    ramUsed: +d[2] / 1024 ** 3, // Convert to GB
    ramFree: +d[3] / 1024 ** 3, // Convert to GB
    ramAvailable: +d[4] / 1024 ** 3, // Convert to GB
  }));

  // Clear the container and remove existing SVG
  const container = d3.select(containerId);
  container.selectAll("*").remove();

  // Get the container dimensions
  const containerWidth = parseInt(container.style("width"));
  const containerHeight = parseInt(container.style("height"));

  // Set up margins and calculate dynamic width/height
  const margin = { top: 10, right: 20, bottom: 50, left: 50 };
  const width = containerWidth - margin.left - margin.right;
  const height = containerHeight - margin.top - margin.bottom;

  // Create SVG container
  const svg = container
    .append("svg")
    .attr("width", containerWidth)
    .attr("height", containerHeight)
    .append("g")
    .attr("transform", `translate(${margin.left},${margin.top})`);

  // Set up scales
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfDay = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    23,
    59,
    59,
    999,
  );

  const x = d3
    .scaleTime()
    .domain([startOfDay, endOfDay]) // Fixed domain from midnight to midnight
    .range([0, width]);

  const y = d3
    .scaleLinear()
    .domain([0, d3.max(parsedData, (d) => d.ramTotal)]) // Dynamic domain based on ramTotal
    .range([height, 0]);

  // Add X axis
  const timeFormatter = d3.timeFormat("%H"); // 24-hour format without AM/PM
  svg
    .append("g")
    .attr("transform", `translate(0,${height})`)
    .call(d3.axisBottom(x).ticks(15).tickFormat(timeFormatter));

  // Add Y-axis with "GB" formatting
  svg.append("g").call(
    d3.axisLeft(y).tickFormat((d) => `${d.toFixed(1)} GB`), // Format ticks with GB
  );

  // Define a threshold for gaps (5 minutes)
  const threshold = 5 * 60 * 1000; // 5 minutes in milliseconds

  // Define a line generator with gaps for each metric
  const lineGenerator = (metric) =>
    d3
      .line()
      .defined((d, i, data) => {
        return i === 0 || d.timestamp - data[i - 1].timestamp <= threshold;
      })
      .x((d) => x(d.timestamp))
      .y((d) => y(d[metric]));

  // Define colors for each metric
  const colors = {
    ramTotal: "steelblue",
    ramUsed: "green",
    ramFree: "orange",
    ramAvailable: "purple",
  };

  // Plot each RAM metric with gaps
  Object.keys(colors).forEach((metric) => {
    svg
      .append("path")
      .datum(parsedData)
      .attr("class", "line")
      .attr("d", lineGenerator(metric))
      .attr("fill", "none")
      .attr("stroke", colors[metric])
      .attr("stroke-width", stroke_width);
  });

  // Calculate min, max, and median RAM used
  const ramUsages = parsedData.map((d) => d.ramUsed);
  const minRamUsed = d3.min(ramUsages);
  const maxRamUsed = d3.max(ramUsages);
  const medianRamUsed = d3.median(ramUsages);

  // Function to add a horizontal line
  function addHorizontalLine(value, color, dashArray = "none", label = "") {
    svg
      .append("line")
      .attr("x1", 0)
      .attr("x2", width)
      .attr("y1", y(value))
      .attr("y2", y(value))
      .attr("stroke", color)
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", dashArray);

    if (label) {
      svg
        .append("text")
        .attr("x", width - 5) // Position label near the right end of the line
        .attr("y", y(value) - 5) // Slightly above the line
        .text(label)
        .attr("font-size", "12px")
        .attr("text-anchor", "end")
        .attr("fill", color);
    }
  }

  // Add horizontal lines for min, max, and median RAM used
  addHorizontalLine(
    minRamUsed,
    "green",
    "none",
    `Min: ${minRamUsed.toFixed(1)} GB`,
  );
  addHorizontalLine(
    maxRamUsed,
    "red",
    "none",
    `Max: ${maxRamUsed.toFixed(1)} GB`,
  );
  addHorizontalLine(
    medianRamUsed,
    "blue",
    "4 4",
    `Median: ${medianRamUsed.toFixed(1)} GB`, // Dashed line for median
  );

  // Add legend
  const legend = svg
    .append("g")
    .attr("transform", `translate(${width - 100},${margin.top})`);

  Object.entries(colors).forEach(([metric, color], index) => {
    const yOffset = index * 20;

    legend
      .append("circle")
      .attr("cx", 0)
      .attr("cy", yOffset)
      .attr("r", 5)
      .attr("fill", color);

    legend
      .append("text")
      .attr("x", 10)
      .attr("y", yOffset + 4)
      .text(metric)
      .attr("font-size", "12px")
      .attr("fill", "black");
  });

  // Add resize event listener (only once)
  if (!resizeListenerAdded) {
    resizeListenerAdded = true;

    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        drawRamChart(containerId);
      }, 300); // 300ms debounce
    });
  }
}
