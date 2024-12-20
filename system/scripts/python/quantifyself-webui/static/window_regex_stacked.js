import { fetchData } from "./api.js";
import { getWindowCategories } from "./window_category.js";
import * as d3 from "https://cdn.skypack.dev/d3";

let resizeListenerAdded = false;

// Cache for various operations
const cache = {
  workDuration: {},
  classifyRow: {},
  color: {},
  processedData: {},
  windowCategories: null,
};

// Helper function to generate cache keys
function generateCacheKey(prefix, ...args) {
  return `${prefix}__${args.join("__")}`;
}

async function getWindowCategoriesCached() {
  if (cache.windowCategories) {
    return cache.windowCategories;
  }
  cache.windowCategories = await getWindowCategories();
  return cache.windowCategories;
}

function classifyRow(categories, clientClass, clientTitle) {
  const cacheKey = generateCacheKey("classifyRow", clientClass, clientTitle);
  if (cache.classifyRow[cacheKey]) {
    return cache.classifyRow[cacheKey];
  }

  for (const category of categories) {
    for (const [subgroup, subgroupDetails] of Object.entries(category.childs)) {
      for (const matchRule of subgroupDetails.match) {
        // Convert Title and Class to RegExp
        const titleRegex = new RegExp(matchRule.Title);
        const classRegex = new RegExp(matchRule.Class);

        const titleMatch = titleRegex.test(clientTitle);
        const classMatch = classRegex.test(clientClass);
        if (titleMatch && classMatch) {
          const result = { group: category.name, subgroup }; // Use the category name
          cache.classifyRow[cacheKey] = result;
          return result;
        }
      }
    }
  }
  const result = { group: "Uncategorized", subgroup: null };
  cache.classifyRow[cacheKey] = result;
  return result;
}

async function fetchDataForDate(date, dbFile) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  const query = `
    SELECT timestamp, client_class, client_title
    FROM window_metrics
    WHERE timestamp >= '${startOfDay.toISOString()}'
    AND timestamp < '${endOfDay.toISOString()}'
    ORDER BY timestamp;
  `;

  const payload = { db_file: dbFile, query };
  return fetchData(payload);
}

function transformData(data, categories, timezoneOffset) {
  return data.map(([timestampStr, clientClass, clientTitle]) => {
    const timestamp = new Date(timestampStr);
    // Convert UTC timestamp to local timestamp
    const localTimestamp = new Date(
      timestamp.getTime() + timezoneOffset * 60 * 60 * 1000,
    );
    const { group, subgroup } = classifyRow(
      categories,
      clientClass,
      clientTitle,
    );
    return {
      timestamp: localTimestamp, // Store local timestamp
      clientClass,
      clientTitle,
      group,
      subgroup,
    };
  });
}

function calculateDurations(enrichedData, idleMaxDuration = 60) {
  const durationData = [];
  for (let i = 0; i < enrichedData.length; i++) {
    const current = enrichedData[i];
    const next = enrichedData[i + 1];
    const duration =
      next && (next.timestamp - current.timestamp) / 1000 <= idleMaxDuration
        ? (next.timestamp - current.timestamp) / 1000
        : 5;
    durationData.push({ ...current, duration });
  }
  return durationData;
}

function get15MinuteInterval(date) {
  const hours = date.getHours();
  const minutes = date.getMinutes();
  const interval = Math.floor(minutes / 15);
  return hours * 4 + interval;
}

async function fetchAndProcessData(date, dbFile, timezoneOffset) {
  const dateString = date.toISOString().split("T")[0];
  const cacheKey = generateCacheKey("processedData", dateString);

  if (cache.processedData[cacheKey]) {
    return cache.processedData[cacheKey];
  }

  const data = await fetchDataForDate(date, dbFile);

  if (data.length === 0) {
    cache.processedData[cacheKey] = {
      durationData: [],
      groupedData: {},
    };
    return cache.processedData[cacheKey];
  }

  const categories = await getWindowCategoriesCached();
  const enrichedData = transformData(data, categories, timezoneOffset); // Pass timezoneOffset
  const durationData = calculateDurations(enrichedData, 300);

  const groupedData = {};
  durationData.forEach(({ timestamp, group, subgroup, duration }) => {
    const timeKey = get15MinuteInterval(timestamp); // Use 15 min interval key
    if (!groupedData[timeKey]) {
      groupedData[timeKey] = {};
    }
    if (!groupedData[timeKey][group]) {
      groupedData[timeKey][group] = {};
    }
    if (!groupedData[timeKey][group][subgroup]) {
      groupedData[timeKey][group][subgroup] = 0;
    }
    groupedData[timeKey][group][subgroup] += duration;
  });

  cache.processedData[cacheKey] = { durationData, groupedData };
  return cache.processedData[cacheKey];
}

async function calculateWorkDuration(date, dbFile, timezoneOffset) {
  const dateString = date.toISOString().split("T")[0];
  const cacheKey = generateCacheKey("workDuration", dateString);
  if (cache.workDuration[cacheKey] !== undefined) {
    return cache.workDuration[cacheKey];
  }

  const data = await fetchDataForDate(date, dbFile);

  if (data.length === 0) {
    cache.workDuration[cacheKey] = 0;
    return 0;
  }

  const categories = await getWindowCategoriesCached();
  const enrichedData = transformData(data, categories, timezoneOffset);
  const durationData = calculateDurations(enrichedData);

  let workDuration = 0;
  durationData.forEach((d) => {
    if (d.group === "Work") workDuration += d.duration;
  });

  cache.workDuration[cacheKey] = workDuration;
  return workDuration;
}

function getColorForWorkDuration(durationInSeconds) {
  const cacheKey = generateCacheKey("color", durationInSeconds);
  if (cache.color[cacheKey]) {
    return cache.color[cacheKey];
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

  cache.color[cacheKey] = color;
  return color;
}

function padDataWithMissingIntervals(combinedGroupedData, groups, subgroups) {
  const allIntervals = Array.from({ length: 24 * 4 }, (_, i) => i); // 24 hours * 4 intervals per hour
  const paddedData = allIntervals.map((interval) => {
    const entry = { time: interval };
    groups.forEach((group) => {
      entry[group] = {};
      subgroups.forEach((subgroup) => {
        entry[group][subgroup] =
          combinedGroupedData[interval]?.[group]?.[subgroup] || 0;
      });
    });
    return entry;
  });
  return paddedData;
}

export async function drawWindowRegexStackedChart(
  containerId,
  startDate = new Date(),
  numberOfDays = 7,
) {
  const DB_FILE = "/home/emre/.local/share/quantifyself/window/window.duckdb";
  const TIMEZONE_OFFSET = 3; // Your Timezone Offset (GMT+3)

  const container = d3.select(containerId);
  container.selectAll("*").remove();

  const allDaysData = [];
  for (let i = 0; i < numberOfDays; i++) {
    const date = new Date(startDate);
    date.setDate(startDate.getDate() - i);

    const { durationData, groupedData } = await fetchAndProcessData(
      date,
      DB_FILE,
      TIMEZONE_OFFSET,
    );
    allDaysData.push({ date, durationData, groupedData });
  }

  let combinedGroupedData = {};
  for (const { date, groupedData } of allDaysData) {
    for (const timeKey in groupedData) {
      if (!combinedGroupedData[timeKey]) {
        combinedGroupedData[timeKey] = {};
      }

      for (const group in groupedData[timeKey]) {
        if (!combinedGroupedData[timeKey][group]) {
          combinedGroupedData[timeKey][group] = {};
        }
        for (const subgroup in groupedData[timeKey][group]) {
          if (!combinedGroupedData[timeKey][group][subgroup]) {
            combinedGroupedData[timeKey][group][subgroup] = 0;
          }
          combinedGroupedData[timeKey][group][subgroup] +=
            groupedData[timeKey][group][subgroup];
        }
      }
    }
  }

  const allGroups = new Set();
  const allSubgroups = new Set();
  for (const timeKey in combinedGroupedData) {
    for (const group in combinedGroupedData[timeKey]) {
      allGroups.add(group);
      for (const subgroup in combinedGroupedData[timeKey][group]) {
        allSubgroups.add(subgroup);
      }
    }
  }
  const groups = Array.from(allGroups);
  const subgroups = Array.from(allSubgroups);

  const getParentGroup = (subgroup) => {
    for (const timeKey in combinedGroupedData) {
      for (const group in combinedGroupedData[timeKey]) {
        if (combinedGroupedData[timeKey][group][subgroup] !== undefined) {
          return group;
        }
      }
    }
  };

  // Sort subgroups by parent group
  const subgroupsSorted = [...subgroups].filter(Boolean).sort((a, b) => {
    const groupA = getParentGroup(a);
    const groupB = getParentGroup(b);

    const groupAIndex = groups.indexOf(groupA);
    const groupBIndex = groups.indexOf(groupB);

    if (groupAIndex < groupBIndex) return -1;
    if (groupAIndex > groupBIndex) return 1;
    return 0;
  });

  const timeSeriesData = padDataWithMissingIntervals(
    combinedGroupedData,
    groups,
    subgroups,
  );

  const containerWidth = parseInt(container.style("width"));
  const containerHeight = parseInt(container.style("height"));
  const margin = { top: 20, right: 30, bottom: 80, left: 50 }; // Increased bottom margin for legend
  const width = containerWidth - margin.left - margin.right;
  const height = containerHeight - margin.top - margin.bottom;

  const svg = container
    .append("svg")
    .attr("width", containerWidth)
    .attr("height", containerHeight)
    .append("g")
    .attr("transform", `translate(${margin.left},${margin.top})`);

  const timeValues = Array.from({ length: 24 * 4 }, (_, i) => i); // 24 hours * 4 intervals
  const x = d3.scalePoint().domain(timeValues).range([0, width]);

  svg
    .append("g")
    .attr("transform", `translate(0,${height})`)
    .call(
      d3
        .axisBottom(x)
        .tickValues(timeValues.filter((d) => d % 4 === 0)) // Show only hourly ticks
        .tickFormat((d) => `${d / 4}`),
    );

  const maxTotalDuration = d3.max(timeSeriesData, (d) => {
    return groups.reduce((sum, group) => {
      return (
        sum +
        subgroups.reduce(
          (subSum, subgroup) => subSum + (d[group]?.[subgroup] || 0),
          0,
        )
      );
    }, 0);
  });

  const y = d3.scaleLinear().domain([0, maxTotalDuration]).range([height, 0]);

  svg.append("g").call(d3.axisLeft(y));

  // --- Color Scale Logic Starts Here ---
  const numMainCategories = groups.length;
  const hueScale = d3
    .scaleLinear()
    .domain([0, numMainCategories])
    .range([0, 360]);

  const groupColors = {};
  const colorScale = (subgroup) => {
    if (!subgroup) return "#ddd";
    const groupIndex = groups.findIndex((group) =>
      Object.values(combinedGroupedData).some(
        (timeGroup) =>
          timeGroup[group] && timeGroup[group][subgroup] !== undefined,
      ),
    );
    if (groupIndex === -1) return "#ddd"; // if subgroup is not mapped to a group.
    const hue = hueScale(groupIndex);
    const parentColor = d3.hsl(hue, 0.8, 0.5); // base color for groups

    const parentGroupName = groups[groupIndex];
    if (!groupColors[parentGroupName]) {
      groupColors[parentGroupName] = parentColor.toString();
    }

    const subGroupIndex = subgroupsSorted.findIndex((s) => s === subgroup);
    const numSiblings = subgroupsSorted.length;
    const lightnessScale = d3
      .scaleLinear()
      .domain([0, numSiblings - 1])
      .range([0.8, 0.4]);
    const lightness = lightnessScale(subGroupIndex);
    return d3.hsl(parentColor.h, parentColor.s, lightness).toString();
  };
  // --- Color Scale Logic Ends Here ---

  const stack = d3
    .stack()
    .keys(subgroupsSorted)
    .value((d, key) => {
      return groups.reduce((sum, group) => {
        return sum + (d[group]?.[key] || 0);
      }, 0);
    });

  const series = stack(timeSeriesData);

  const area = d3
    .area()
    .x((d, i) => x(timeSeriesData[i].time))
    .y0((d) => y(d[0]))
    .y1((d) => y(d[1]));

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
    .selectAll(".area-group")
    .data(series)
    .enter()
    .append("path")
    .attr("class", "area-group")
    .style("fill", (d) => colorScale(d.key))
    .attr("d", area)
    .on("mouseover", function (event, d) {
      d3.select(this).style("opacity", 0.7);
      const totalDuration = d.reduce(
        (sum, entry) => sum + (entry[1] - entry[0]),
        0,
      );
      const hours = Math.floor(totalDuration / 3600);
      const minutes = Math.floor((totalDuration % 3600) / 60);
      const seconds = Math.floor(totalDuration % 60);
      tooltip
        .style("display", "block")
        .html(`${d.key} : ${hours}h ${minutes}m ${seconds}s`)
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

  // ------ Legend Changes Start Here ------
  const legend = svg
    .append("g")
    .attr("class", "legend")
    .attr("transform", `translate(0, ${height + margin.bottom - 60})`); // Position at the bottom

  const legendItemWidth = 150;
  const legendItemHeight = 20;
  const numLegendCols = Math.floor(width / legendItemWidth); // Number of columns in the legend
  const legendData = Object.entries(groupColors);

  const legendItems = legend
    .selectAll(".legend-item")
    .data(legendData)
    .enter()
    .append("g")
    .attr("class", "legend-item")
    .attr("transform", (d, i) => {
      const col = i % numLegendCols;
      const row = Math.floor(i / numLegendCols);
      return `translate(${col * legendItemWidth}, ${row * legendItemHeight})`;
    });

  legendItems
    .append("rect")
    .attr("width", 18)
    .attr("height", 18)
    .attr("fill", ([, color]) => color);

  legendItems
    .append("text")
    .attr("x", 24)
    .attr("y", 9)
    .attr("dy", "0.35em")
    .style("fill", "white")
    .text(([group]) => group);
  // ------ Legend Changes End Here ------

  if (!resizeListenerAdded) {
    resizeListenerAdded = true;
    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(
        () => drawWindowRegexStackedChart(containerId, startDate, numberOfDays),
        300,
      );
    });
  }
}
