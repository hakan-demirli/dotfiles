import { fetchData } from "./api.js";
import * as d3 from "https://cdn.skypack.dev/d3";

// Keep a reference to the resize listener so it doesn't duplicate
let resizeListenerAdded = false;

export async function drawRamHistoryChart(containerId) {
  const DB_FILE = "/home/emre/.local/share/quantifyself/system/system.duckdb";
  const QUERY = `
    SELECT timestamp, ram_total, ram_used, ram_free, ram_available
    FROM system_metrics
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

  // Parse data
  // data looks like: [[timestamp, ram_total, ram_used, ram_free, ram_available], ...]
  const parsedData = data.map((d) => {
    const timestamp = new Date(d[0]);
    const ramTotal = +d[1];
    const ramUsed = +d[2];

    // Compute RAM usage percentage
    const ramUsagePercent = (ramUsed / ramTotal) * 100;

    return {
      timestamp,
      ramUsage: ramUsagePercent,
    };
  });

  // Group data by hour of the day (0-23)
  const hourGroups = d3.group(parsedData, (d) => d.timestamp.getHours());

  // For each hour, calculate stats
  const hourlyStats = [];
  for (let hour = 0; hour < 24; hour++) {
    const group = hourGroups.get(hour) || [];
    const ramUsages = group.map((d) => d.ramUsage).sort(d3.ascending);
    if (ramUsages.length > 0) {
      const minRamUsage = d3.min(ramUsages);
      const maxRamUsage = d3.max(ramUsages);
      const q1 = d3.quantile(ramUsages, 0.25);
      const medianRamUsage = d3.quantile(ramUsages, 0.5);
      const q3 = d3.quantile(ramUsages, 0.75);

      hourlyStats.push({
        hour,
        min: minRamUsage,
        q1,
        median: medianRamUsage,
        q3,
        max: maxRamUsage,
      });
    } else {
      hourlyStats.push({
        hour,
        min: null,
        q1: null,
        median: null,
        q3: null,
        max: null,
      });
    }
  }

  // Clear the container and remove existing SVG
  const container = d3.select(containerId);
  container.selectAll("*").remove();

  // Get the container dimensions
  const containerWidth = parseInt(container.style("width"));
  const containerHeight = parseInt(container.style("height"));

  // Set up margins and calculate dynamic width/height
  const margin = { top: 25, right: 20, bottom: 50, left: 50 };
  const width = containerWidth - margin.left - margin.right;
  const height = containerHeight - margin.top - margin.bottom;

  // Create SVG container
  const svg = container
    .append("svg")
    .attr("width", containerWidth)
    .attr("height", containerHeight)
    .append("g")
    .attr("transform", `translate(${margin.left},${margin.top})`);

  // Y scale: 0 to 100% since we're dealing with a percentage of RAM usage
  const y = d3.scaleLinear().domain([0, 100]).range([height, 0]);

  // X scale: 24 hours, each hour is a band
  const x = d3
    .scaleBand()
    .domain(d3.range(0, 24))
    .range([0, width])
    .paddingInner(0.1);

  // Add axes
  svg
    .append("g")
    .attr("transform", `translate(0, ${height})`)
    .call(d3.axisBottom(x).tickFormat((d) => d.toString().padStart(2, "0")));

  svg.append("g").call(d3.axisLeft(y));

  // Box width (relative to band width)
  const boxWidth = x.bandwidth() * 0.5;

  // Draw the boxes
  hourlyStats.forEach((d) => {
    if (d.min === null) {
      // no data for this hour
      return;
    }
    const boxX = x(d.hour) + x.bandwidth() / 2;

    // Draw the main box (from Q1 to Q3)
    svg
      .append("rect")
      .attr("x", boxX - boxWidth / 2)
      .attr("y", y(d.q3))
      .attr("width", boxWidth)
      .attr("height", y(d.q1) - y(d.q3))
      .attr("fill", "steelblue")
      .attr("opacity", 0.5);

    // Median line
    svg
      .append("line")
      .attr("x1", boxX - boxWidth / 2)
      .attr("x2", boxX + boxWidth / 2)
      .attr("y1", y(d.median))
      .attr("y2", y(d.median))
      .attr("stroke", "black")
      .attr("stroke-width", 2);

    // Whiskers (from min to Q1 and Q3 to max)
    svg
      .append("line")
      .attr("x1", boxX)
      .attr("x2", boxX)
      .attr("y1", y(d.min))
      .attr("y2", y(d.q1))
      .attr("stroke", "black")
      .attr("stroke-width", 1);

    svg
      .append("line")
      .attr("x1", boxX)
      .attr("x2", boxX)
      .attr("y1", y(d.q3))
      .attr("y2", y(d.max))
      .attr("stroke", "black")
      .attr("stroke-width", 1);

    // Horizontal lines at min and max
    svg
      .append("line")
      .attr("x1", boxX - boxWidth / 4)
      .attr("x2", boxX + boxWidth / 4)
      .attr("y1", y(d.min))
      .attr("y2", y(d.min))
      .attr("stroke", "black")
      .attr("stroke-width", 1);

    svg
      .append("line")
      .attr("x1", boxX - boxWidth / 4)
      .attr("x2", boxX + boxWidth / 4)
      .attr("y1", y(d.max))
      .attr("y2", y(d.max))
      .attr("stroke", "black")
      .attr("stroke-width", 1);
  });

  // Optional: add a title
  svg
    .append("text")
    .attr("x", width / 2)
    .attr("y", -5)
    .attr("text-anchor", "middle")
    .text("RAM Usage");

  // Add resize event listener (only once)
  if (!resizeListenerAdded) {
    resizeListenerAdded = true;

    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        drawRamHistoryChart(containerId);
      }, 300); // 300ms debounce
    });
  }
}
