import * as d3 from "https://cdn.skypack.dev/d3";
import {
  fetchAndProcessData,
  padDataWithMissingIntervals,
} from "./data_handler.js";
import { DB_FILE, TIMEZONE_OFFSET } from "./constants.js";

let resizeListenerAdded = false;

// Helper function for color calculations
function calculateHSL(hue, saturation, lightness) {
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}

// Helper function to get a color for a subgroup
function getColorForSubgroup(
  groups,
  subgroupsSorted,
  groupIndex,
  subgroup,
  allDaysData,
) {
  if (!subgroup) return "#ddd";
  const foundGroupIndex = groups.findIndex((group) =>
    allDaysData.some(({ groupedData }) =>
      Object.values(groupedData).some(
        (timeGroup) =>
          timeGroup[group] && timeGroup[group][subgroup] !== undefined,
      ),
    ),
  );
  if (foundGroupIndex === -1) return "#ddd"; // if subgroup is not mapped to a group.

  const hueScale = (max) => (foundGroupIndex / max) * 360;
  const hue = hueScale(groups.length);

  const subGroupIndex = subgroupsSorted.indexOf(subgroup);
  const lightnessScale = (max) => 0.8 - (subGroupIndex / max) * 0.4;
  const lightness = lightnessScale(subgroupsSorted.length) * 100;

  return calculateHSL(hue, 80, lightness);
}

export async function drawWindowRegexGridChart(
  containerId,
  startDate = new Date(),
  numberOfDays = 30,
) {
  // 1. Remove '#' prefix for getElementById
  const containerIdWithoutHash = containerId.startsWith("#")
    ? containerId.substring(1)
    : containerId;

  // 2. Get the existing container correctly
  const container = document.getElementById(containerIdWithoutHash);

  // 3. Remove chart creation logic
  // document.body.appendChild(container);

  // Clear existing content within the container
  while (container.firstChild) {
    container.removeChild(container.firstChild);
  }

  container.style.overflowX = "auto";

  // Fetch and process data for each day
  const allDaysData = [];
  for (let i = 0; i < numberOfDays; i++) {
    const date = new Date(startDate);
    date.setDate(startDate.getDate() - i);
    // const formattedDate = date.toISOString().split("T")[0];
    const localDate = new Date(
      date.getTime() - date.getTimezoneOffset() * 60000,
    );
    const formattedDate = localDate.toISOString().split("T")[0];

    const { groupedData } = await fetchAndProcessData(date, DB_FILE);
    allDaysData.push({ date: formattedDate, groupedData });
  }

  // --- Responsive Sizing ---
  const containerWidth = container.offsetWidth; // Get container width
  const aspectRatio = 0.5; // Example aspect ratio (width/height)
  let containerHeight = containerWidth * aspectRatio;

  // Ensure a minimum height if needed
  const minHeight = 300; // Example minimum height
  containerHeight = Math.max(containerHeight, minHeight);

  // Set up the grid dimensions based on percentages
  const intervals = Array.from({ length: 24 * 4 }, (_, i) => i); // 15-minute intervals
  const numColumns = intervals.length + 1; // +1 for the date column
  const cellWidthPercentage = 100 / numColumns; // Calculate cell width as a percentage
  const cellHeight = 25; // Example cell height (adjust as needed)
  const gridSpacing = "2px";

  // --- Color Scale Logic ---
  const allGroups = new Set();
  const allSubgroups = new Set();

  allDaysData.forEach(({ groupedData }) => {
    for (const timeKey in groupedData) {
      for (const group in groupedData[timeKey]) {
        allGroups.add(group);
        for (const subgroup in groupedData[timeKey][group]) {
          allSubgroups.add(subgroup);
        }
      }
    }
  });

  const groups = Array.from(allGroups);
  const subgroups = Array.from(allSubgroups);

  const getParentGroup = (subgroup) => {
    for (const { groupedData } of allDaysData) {
      for (const timeKey in groupedData) {
        for (const group in groupedData[timeKey]) {
          if (groupedData[timeKey][group][subgroup] !== undefined) {
            return group;
          }
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
  // --- End of Color Scale Logic ---

  // --- Create Legend ---
  const legendContainer = document.createElement("div");
  legendContainer.style.display = "flex";
  legendContainer.style.flexWrap = "wrap";
  legendContainer.style.marginBottom = "10px"; // Add spacing between legend and table
  legendContainer.style.flexDirection = "column"; // Stack elements vertically

  groups.forEach((group, index) => {
    const legendItem = document.createElement("div");
    legendItem.style.display = "flex";
    legendItem.style.alignItems = "center";
    legendItem.style.marginRight = "15px";

    const colorBox = document.createElement("div");
    colorBox.style.width = "20px";
    colorBox.style.height = "20px";
    colorBox.style.backgroundColor = getColorForSubgroup(
      groups,
      subgroupsSorted,
      index,
      subgroupsSorted.find((subgroup) => getParentGroup(subgroup) === group), // Find a subgroup within the group
      allDaysData,
    );

    const label = document.createElement("span");
    label.textContent = group;
    label.style.marginLeft = "5px";

    legendItem.appendChild(colorBox);
    legendItem.appendChild(label);
    legendContainer.appendChild(legendItem);
  });

  container.appendChild(legendContainer);
  // --- End of Legend Creation ---

  // Create the table
  const table = document.createElement("table");
  table.style.width = "95%"; // Table takes full container width
  table.style.tableLayout = "fixed";
  table.style.borderCollapse = "separate";
  table.style.borderSpacing = gridSpacing;
  table.style.alignSelf = "flex-start";
  container.appendChild(table);

  // Create table header (time intervals)
  const headerRow = table.insertRow();
  headerRow.insertCell().textContent = "Date"; // Header for the date column
  for (let hour = 0; hour < 24; hour++) {
    const cell = headerRow.insertCell();
    cell.colSpan = 4; // Span 4 cells for each hour
    cell.style.width = `${4 * cellWidthPercentage}%`; // Use percentage width
    cell.style.height = `${cellHeight}px`;
    cell.style.textAlign = "center";
    cell.textContent = `${hour.toString().padStart(2, "0")}`;
  }

  // Create rows for each day
  allDaysData.forEach(({ date, groupedData }, dayIndex) => {
    const row = table.insertRow();

    // Date cell
    const dateCell = row.insertCell();
    dateCell.textContent = date;
    dateCell.style.width = `${cellWidthPercentage}%`; // Percentage width
    dateCell.style.height = `${cellHeight}px`;
    dateCell.style.textAlign = "center";

    // Data cells
    intervals.forEach((interval) => {
      const cell = row.insertCell();
      cell.style.width = `${cellWidthPercentage}%`; // Percentage width
      cell.style.height = `${cellHeight}px`;
      cell.style.textAlign = "center";
      cell.style.position = "relative";

      // Access data for the current interval directly
      const intervalData = groupedData[interval];
      let cellData = { date, interval, subgroups: [] };

      if (intervalData) {
        // Flatten the structure and create a sortable array of subgroups with start times
        Object.keys(intervalData).forEach((group) => {
          Object.keys(intervalData[group]).forEach((subgroup) => {
            const duration = intervalData[group][subgroup];
            // Calculate start time based on interval and position within the interval
            const startTime = interval * 15 * 60; // Convert interval to seconds

            cellData.subgroups.push({
              subgroup,
              duration,
              startTime,
              group, // Add group for color mapping
            });
          });
        });

        // Sort subgroups by their start time
        cellData.subgroups.sort((a, b) => a.startTime - b.startTime);
      }

      // Calculate total duration of all subgroups in this cell for proportional width calculation
      const totalDuration = cellData.subgroups.reduce(
        (acc, curr) => acc + curr.duration,
        0,
      );

      if (cellData.subgroups.length > 0) {
        let currentPosition = 0; // Keep track of the starting position for each subgroup div

        cellData.subgroups.forEach(
          ({ subgroup, duration, startTime, group }, index) => {
            const subgroupDiv = document.createElement("div");
            subgroupDiv.style.backgroundColor = getColorForSubgroup(
              groups,
              subgroupsSorted,
              groups.indexOf(group),
              subgroup,
              allDaysData,
            );

            // Calculate width based on the proportion of duration to the total duration
            const divWidth = (duration / totalDuration) * 100;

            // Set position, width, and height
            subgroupDiv.style.position = "absolute";
            subgroupDiv.style.left = `${currentPosition}%`;
            subgroupDiv.style.top = "0";
            subgroupDiv.style.width = `${divWidth}%`;
            subgroupDiv.style.height = "100%";

            // Update the starting position for the next subgroup div
            currentPosition += divWidth;

            subgroupDiv.title = `Date: ${date}\nInterval: ${Math.floor(
              interval / 4,
            )}:${((interval % 4) * 15).toString().padStart(2, "0")}\nSubgroup: ${subgroup}\nDuration: ${duration.toFixed(
              0,
            )}s`;
            cell.appendChild(subgroupDiv);
          },
        );
      } else {
        // Default color for empty cells
        cell.style.backgroundColor = "#ddd";
      }
    });
  });

  // Add resize listener
  if (!resizeListenerAdded) {
    resizeListenerAdded = true;
    let resizeTimeout;
    window.addEventListener("resize", () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(
        () => drawWindowRegexGridChart(containerId, startDate, numberOfDays),
        300,
      );
    });
  }
}
