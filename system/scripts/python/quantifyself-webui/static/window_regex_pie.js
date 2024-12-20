import { fetchData } from "./api.js";
import { getWindowCategories } from "./window_category.js";
import * as d3 from "https://cdn.skypack.dev/d3";
import flatpickr from "https://cdn.skypack.dev/flatpickr";

let resizeListenerAdded = false;

// 1. Cache for work duration
const workDurationCache = {};
const classifyRowCache = {};
const colorCache = {};

let windowCategoriesCache = null;

async function getWindowCategoriesCached() {
  if (windowCategoriesCache) {
    return windowCategoriesCache;
  }
  windowCategoriesCache = await getWindowCategories();
  return windowCategoriesCache;
}

function classifyRow(categories, clientClass, clientTitle) {
  const cacheKey = `${clientClass}__${clientTitle}`;
  if (classifyRowCache[cacheKey]) {
    return classifyRowCache[cacheKey];
  }

  for (const category of categories) {
    // Iterate over the array
    for (const [subgroup, subgroupDetails] of Object.entries(category.childs)) {
      for (const matchRule of subgroupDetails.match) {
        // Convert Title and Class strings to RegExp
        const titleRegex = new RegExp(matchRule.Title);
        const classRegex = new RegExp(matchRule.Class);

        const titleMatch = titleRegex.test(clientTitle);
        const classMatch = classRegex.test(clientClass);
        if (titleMatch && classMatch) {
          const result = { group: category.name, subgroup }; // Use category name
          classifyRowCache[cacheKey] = result;
          return result;
        }
      }
    }
  }
  const result = { group: "Uncategorized", subgroup: null };
  classifyRowCache[cacheKey] = result;
  return result;
}

async function calculateWorkDuration(date, dbFile) {
  const dateString = date.toISOString().split("T")[0]; // Format to 'YYYY-MM-DD'

  // 2. Check cache first
  if (workDurationCache[dateString] !== undefined) {
    return workDurationCache[dateString];
  }

  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  const QUERY = `
    SELECT timestamp, client_class, client_title
    FROM window_metrics
    WHERE timestamp >= '${startOfDay.toISOString()}'
    AND timestamp < '${endOfDay.toISOString()}'
    ORDER BY timestamp;
    `;

  const payload = { db_file: dbFile, query: QUERY };
  const data = await fetchData(payload);

  if (data.length === 0) {
    workDurationCache[dateString] = 0; // Cache the zero result
    return 0;
  }

  const categories = await getWindowCategoriesCached();
  const enrichedData = data.map(([timestampStr, clientClass, clientTitle]) => {
    const { group, subgroup } = classifyRow(
      categories,
      clientClass,
      clientTitle,
    );
    return {
      timestamp: new Date(timestampStr),
      clientClass,
      clientTitle,
      group,
      subgroup,
    };
  });

  const durationData = [];
  const idleMaxDuration = 60; // seconds
  for (let i = 0; i < enrichedData.length; i++) {
    const current = enrichedData[i];
    const next = enrichedData[i + 1];
    const duration =
      next && (next.timestamp - current.timestamp) / 1000 <= idleMaxDuration
        ? (next.timestamp - current.timestamp) / 1000
        : 5;
    durationData.push({ ...current, duration });
  }

  let workDuration = 0;
  durationData.forEach((d) => {
    if (d.group === "Work") workDuration += d.duration;
  });

  workDurationCache[dateString] = workDuration; // Store in cache
  return workDuration;
}

function getColorForWorkDuration(durationInSeconds) {
  if (colorCache[durationInSeconds]) {
    return colorCache[durationInSeconds];
  }
  const maxHours = 12;
  const maxWorkDuration = maxHours * 60 * 60;
  const clampedDuration = Math.min(durationInSeconds, maxWorkDuration);
  const percentage = clampedDuration / maxWorkDuration;

  const lightness = 100 * (1 - percentage);
  const lightnessCapped = Math.max(25, Math.min(lightness, 99));

  let color = `hsl(120, 100%, ${lightnessCapped}%)`; // 120 is green in HSL

  if (percentage === 0) {
    color = `transparent`;
  }
  colorCache[durationInSeconds] = color;
  return color;
}

const processedDataCache = {};
async function processData(date, dbFile) {
  const dateString = date.toISOString().split("T")[0];
  if (processedDataCache[dateString]) {
    return processedDataCache[dateString];
  }
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);
  const QUERY = `
              SELECT timestamp, client_class, client_title
              FROM window_metrics
              WHERE timestamp >= '${startOfDay.toISOString()}'
              AND timestamp < '${endOfDay.toISOString()}'
              ORDER BY timestamp;
              `;
  const payload = { db_file: dbFile, query: QUERY };
  const data = await fetchData(payload);
  if (data.length === 0) {
    processedDataCache[dateString] = {
      durationData: [],
      hierarchicalData: {
        name: "Root",
        children: [],
      },
    };
    return processedDataCache[dateString];
  }
  const categories = await getWindowCategoriesCached();
  const enrichedData = data.map(([timestampStr, clientClass, clientTitle]) => {
    const { group, subgroup } = classifyRow(
      categories,
      clientClass,
      clientTitle,
    );
    return {
      timestamp: new Date(timestampStr),
      clientClass,
      clientTitle,
      group,
      subgroup,
    };
  });
  const durationData = [];
  for (let i = 0; i < enrichedData.length; i++) {
    const current = enrichedData[i];
    const next = enrichedData[i + 1];
    const idleMaxDuration = 60; // seconds
    const duration =
      next && (next.timestamp - current.timestamp) / 1000 <= idleMaxDuration
        ? (next.timestamp - current.timestamp) / 1000
        : 5;
    durationData.push({ ...current, duration });
  }
  // Group durations
  const groupedData = {};
  durationData.forEach(({ group, subgroup, duration }) => {
    if (!groupedData[group]) groupedData[group] = {};
    if (!groupedData[group][subgroup]) groupedData[group][subgroup] = 0;
    groupedData[group][subgroup] += duration;
  });
  const hierarchicalData = {
    name: "Root",
    children: Object.entries(groupedData).map(
      ([mainCategory, subCategories]) => ({
        name: mainCategory,
        children: Object.entries(subCategories).map(
          ([subCategory, duration]) => ({
            name: subCategory,
            value: duration,
          }),
        ),
      }),
    ),
  };
  processedDataCache[dateString] = { durationData, hierarchicalData };
  return processedDataCache[dateString];
}

export async function drawWindowRegexPieChart(
  containerId,
  selectedDate = new Date(),
) {
  const DB_FILE = "/home/emre/.local/share/quantifyself/window/window.duckdb";

  // Ensure the container is cleared before rendering
  const container = d3.select(containerId);
  container.selectAll("*").remove();

  // Calendar container
  const calendarContainer = container
    .append("div")
    .style("margin-bottom", "0.1rem")
    .style("width", "4rem"); // Adjust width as needed

  // Initialize flatpickr inline
  flatpickr(calendarContainer.node(), {
    inline: true,
    dateFormat: "Y-m-d",
    defaultDate: selectedDate,
    onReady: async function (_, __, fp) {
      // Apply colors to day elements
      fp.calendarContainer
        .querySelectorAll(".flatpickr-day")
        .forEach(async (day) => {
          const date = new Date(day.dateObj);
          const workDuration = await calculateWorkDuration(date, DB_FILE);
          const backgroundColor = getColorForWorkDuration(workDuration);
          day.style.backgroundColor = backgroundColor;

          // Calculate lightness or contrast to adjust text color
          const lightness = parseFloat(
            backgroundColor.match(/\d+\.?\d*%/g)?.[1],
          ); // Extract lightness from HSL
          day.style.color = lightness > 50 ? "black" : "white"; // Dark text for light backgrounds, white for dark
        });
    },
    onChange: function (selectedDates, dateStr) {
      // Fetch data for the selected date, but don't re-render the calendar.
      drawWindowRegexPieChart(containerId, selectedDates[0]);
    },
    onMonthChange: async function (_, __, fp) {
      // Reapply colors when the month changes
      fp.calendarContainer
        .querySelectorAll(".flatpickr-day")
        .forEach(async (day) => {
          const date = new Date(day.dateObj);
          const workDuration = await calculateWorkDuration(date, DB_FILE);
          const backgroundColor = getColorForWorkDuration(workDuration);
          day.style.backgroundColor = backgroundColor;

          // Calculate lightness or contrast to adjust text color
          const lightness = parseFloat(
            backgroundColor.match(/\d+\.?\d*%/g)?.[1],
          ); // Extract lightness from HSL
          day.style.color = lightness > 50 ? "black" : "white"; // Dark text for light backgrounds, white for dark
        });
    },
  });

  const { durationData, hierarchicalData } = await processData(
    selectedDate,
    DB_FILE,
  );

  if (durationData.length === 0) {
    console.error("No data available for the selected date.");
    // Render an empty sunburst chart with a placeholder
    const emptyData = {
      name: "Root",
      children: [],
    };

    const containerWidth = parseInt(container.style("width"));
    const containerHeight = parseInt(container.style("height"));
    const radius = Math.min(containerWidth, containerHeight) / 2;

    const svg = container
      .append("svg")
      .attr("width", containerWidth)
      .attr("height", containerHeight)
      .append("g")
      .attr(
        "transform",
        `translate(${containerWidth / 2},${containerHeight / 2})`,
      );

    const root = d3.hierarchy(emptyData).sum((d) => d.value);
    const partition = d3.partition().size([2 * Math.PI, radius]);

    const arc = d3
      .arc()
      .startAngle((d) => d.x0)
      .endAngle((d) => d.x1)
      .innerRadius((d) => d.y0)
      .outerRadius((d) => d.y1);

    partition(root);

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

  // D3 chart rendering
  const containerWidth = parseInt(container.style("width"));
  const containerHeight = parseInt(container.style("height"));
  const radius = Math.min(containerWidth, containerHeight) / 2;

  const svg = container
    .append("svg")
    .attr("width", containerWidth)
    .attr("height", containerHeight)
    .append("g")
    .attr(
      "transform",
      `translate(${containerWidth / 3.3},${containerHeight / 2})`,
    );

  const root = d3.hierarchy(hierarchicalData).sum((d) => d.value);
  const partition = d3.partition().size([2 * Math.PI, radius]);

  const arc = d3
    .arc()
    .startAngle((d) => d.x0)
    .endAngle((d) => d.x1)
    .innerRadius((d) => d.y0)
    .outerRadius((d) => d.y1);

  partition(root);

  // Set up HSL color scale
  const numMainCategories = Object.keys(
    hierarchicalData.children.reduce((acc, d) => {
      acc[d.name] = 1;
      return acc;
    }, {}),
  ).length;

  const hueScale = d3
    .scaleLinear()
    .domain([0, numMainCategories])
    .range([0, 360]); // Hue range from 0 to 360 degrees

  const color = (d) => {
    if (d.depth === 0) return "#ddd"; // Base color for root
    if (d.depth === 1) {
      const index = d.parent.children.indexOf(d);
      const hue = hueScale(index);
      return d3.hsl(hue, 0.8, 0.5).toString(); // Main category color (adjust saturation and lightness as needed)
    } else {
      // Subcategory color based on parent's hue and depth
      const parentColor = d3.hsl(color(d.parent));
      const numSiblings = d.parent.children.length;
      const siblingIndex = d.parent.children.indexOf(d);
      const lightnessScale = d3
        .scaleLinear()
        .domain([0, numSiblings - 1])
        .range([0.8, 0.4]);
      const lightness = lightnessScale(siblingIndex);
      return d3.hsl(parentColor.h, parentColor.s, lightness).toString();
    }
  };

  const tooltip = d3
    .select("body")
    .append("div")
    .attr("class", "tooltip")
    .style("position", "absolute")
    .style("background-color", "white")
    .style("border", "1px solid #ccc")
    .style("padding", "5px")
    .style("display", "none")
    .style("pointer-events", "none");

  svg
    .selectAll("path")
    .data(root.descendants())
    .join("path")
    .attr("d", arc)
    .style("fill", color) // Use the color function
    .style("stroke", "#fff")
    .on("mouseover", function (event, d) {
      d3.select(this).style("opacity", 0.7);
      const durationInSeconds = d.value;
      const hours = Math.floor(durationInSeconds / 3600);
      const minutes = Math.floor((durationInSeconds % 3600) / 60);
      const seconds = Math.floor(durationInSeconds % 60);
      tooltip
        .style("display", "block")
        .html(`${d.data.name}: ${hours}h ${minutes}m ${seconds}s`)
        .style("left", `${event.pageX + 10}px`)
        .style("top", `${event.pageY - 20}px`);
    })
    .on("mousemove", (event) => {
      tooltip
        .style("left", `${event.pageX + 10}px`)
        .style("top", `${event.pageY - 20}px`);
    })
    .on("mouseout", function () {
      d3.select(this).style("opacity", 1);
      tooltip.style("display", "none");
    });

  svg
    .selectAll("text")
    .data(root.descendants())
    .join("text")
    .attr("transform", (d) => `translate(${arc.centroid(d)})`)
    .attr("dy", "0.35em")
    .style("text-anchor", "middle")
    .text((d) => {
      const angle = (d.x1 - d.x0) * (180 / Math.PI); // Convert radians to degrees
      return angle > 10 ? d.data.name : ""; // Only display label if slice is greater than 10 degrees
    });

  const totalDuration = durationData.reduce((sum, d) => sum + d.duration, 0);
  const totalHours = Math.floor(totalDuration / 3600);
  const totalMinutes = Math.floor((totalDuration % 3600) / 60);
  const formattedTotal = `${totalHours}h ${totalMinutes}m`;
  svg
    .append("text")
    .attr("class", "center-text")
    .attr("text-anchor", "middle")
    .attr("dy", "0.35em") // Adjust vertical alignment
    .style("font-size", "1.5em") // Adjust size as needed
    .style("font-weight", "bold")
    .text(formattedTotal);

  // Resize listener
  if (!resizeListenerAdded) {
    resizeListenerAdded = true;
    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(
        () => drawWindowRegexPieChart(containerId, selectedDate),
        300,
      );
    });
  }
}
