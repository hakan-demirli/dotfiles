import { fetchData } from "./api.js";
import * as d3 from "https://cdn.skypack.dev/d3";

// Keep a reference to the resize listener so it doesn't duplicate
let resizeListenerAdded = false;

export async function drawCpuChart(containerId) {
  let stroke_width = 1;
  let circle_radious = 1;

  const DB_FILE = "/home/emre/.local/share/quantifyself/system/system.duckdb";
  const QUERY = `
    SELECT timestamp, cpu_usage_percent
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
    console.error("No CPU data available.");
    return;
  }

  const parsedData = data.map((d) => ({
    timestamp: new Date(d[0]),
    cpuUsage: +d[1],
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
    .domain([0, 100]) // Fixed domain from 0 to 100
    .range([height, 0]);

  // Add X axis
  const timeFormatter = d3.timeFormat("%H"); // 24-hour format without AM/PM

  svg
    .append("g")
    .attr("transform", `translate(0,${height})`)
    .call(d3.axisBottom(x).ticks(15).tickFormat(timeFormatter));

  // Add Y axis
  svg.append("g").call(d3.axisLeft(y));

  // Define a threshold for gaps (5 minutes)
  const threshold = 5 * 60 * 1000; // 5 minutes in milliseconds

  // Function to add a horizontal line with an optional label
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

  // Calculate min, max, and median CPU usage
  const cpuUsages = parsedData.map((d) => d.cpuUsage);
  // const minCpuUsage = d3.min(cpuUsages); // Uncomment if you want to use minCpuUsage
  const maxCpuUsage = d3.max(cpuUsages);
  const medianCpuUsage = d3.median(cpuUsages);

  // Add horizontal lines for min, max, and median CPU usage
  // addHorizontalLine(minCpuUsage, "green", "none", `Min: ${minCpuUsage.toFixed(1)}%`); // Uncomment if needed
  addHorizontalLine(
    maxCpuUsage,
    "red",
    "none",
    `Max: ${maxCpuUsage.toFixed(1)}%`,
  );
  addHorizontalLine(
    medianCpuUsage,
    "blue",
    "4 4",
    `Median: ${medianCpuUsage.toFixed(1)}%`, // Dashed line for median
  );

  // Add line with gaps
  const line = d3
    .line()
    .defined((d, i, data) => {
      return i === 0 || d.timestamp - data[i - 1].timestamp <= threshold;
    })
    .x((d) => x(d.timestamp))
    .y((d) => y(d.cpuUsage));

  // Define the area generator
  const area = d3
    .area()
    .defined((d, i, data) => {
      return i === 0 || d.timestamp - data[i - 1].timestamp <= threshold;
    })
    .x((d) => x(d.timestamp))
    .y0(height) // Bottom of the area (aligned with the X-axis)
    .y1((d) => y(d.cpuUsage)); // Top of the area (aligned with the line)

  // Add the area path
  svg
    .append("path")
    .datum(parsedData)
    .attr("class", "area")
    .attr("d", area)
    .attr("fill", "steelblue")
    .attr("fill-opacity", 0.2); // Adjust opacity for a shadow effect

  // Add the line path on top of the area
  svg
    .append("path")
    .datum(parsedData)
    .attr("class", "line")
    .attr("d", line)
    .attr("fill", "none")
    .attr("stroke", "steelblue")
    .attr("stroke-width", stroke_width);

  svg
    .append("path")
    .datum(parsedData)
    .attr("class", "line")
    .attr("d", line)
    .attr("fill", "none")
    .attr("stroke", "steelblue")
    .attr("stroke-width", stroke_width);

  // Add circles at data points
  svg
    .selectAll(".data-point")
    .data(parsedData)
    .enter()
    .append("circle")
    .attr("class", "data-point")
    .attr("cx", (d) => x(d.timestamp))
    .attr("cy", (d) => y(d.cpuUsage))
    .attr("r", circle_radious)
    .attr("fill", "steelblue")
    .on("mouseover", function (event, d) {
      // Remove any existing tooltip
      d3.select(".tooltip").remove();

      // Create tooltip on hover
      const tooltip = container
        .append("div")
        .attr("class", "tooltip")
        .style("position", "absolute")
        .style("background", "white")
        .style("border", "1px solid #ccc")
        .style("padding", "5px")
        .style("border-radius", "5px")
        .style("pointer-events", "none")
        .style("font-size", "12px")
        .text(`${d.cpuUsage}%`);

      // Get container's position relative to the page
      const containerRect = container.node().getBoundingClientRect();
      const [mouseX, mouseY] = d3.pointer(event);

      tooltip
        .style("left", `${mouseX + containerRect.left + 3}px`)
        .style("top", `${mouseY + containerRect.top + 3}px`);
    })
    .on("mousemove", function (event) {
      const containerRect = container.node().getBoundingClientRect();
      const [mouseX, mouseY] = d3.pointer(event);

      d3.select(".tooltip")
        .style("left", `${mouseX + containerRect.left + 3}px`)
        .style("top", `${mouseY + containerRect.top + 3}px`);
    })
    .on("mouseout", function () {
      // Remove tooltip on mouse out
      d3.select(".tooltip").remove();
    });

  // Add resize event listener (only once)
  if (!resizeListenerAdded) {
    resizeListenerAdded = true;

    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        drawCpuChart(containerId);
      }, 300); // 300ms debounce
    });
  }
}
