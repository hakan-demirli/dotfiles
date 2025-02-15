import * as d3 from "https://cdn.skypack.dev/d3";
import { BaseChart } from "./chart_base.js";
import {
  fetchAndProcessData,
  padDataWithMissingIntervals,
} from "./data_handler.js";
import { DB_FILE } from "./constants.js";

export async function drawWindowRegexStackedChart(
  containerId,
  startDate = new Date(),
  numberOfDays = 7,
) {
  const chart = new BaseChart(containerId);
  chart.clearContainer();

  const allDaysData = [];
  for (let i = 0; i < numberOfDays; i++) {
    const date = new Date(startDate);
    date.setDate(startDate.getDate() - i);

    const { groupedData } = await fetchAndProcessData(date, DB_FILE);
    allDaysData.push({ date, groupedData });
  }

  let combinedGroupedData = {};
  for (const { groupedData } of allDaysData) {
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

  const { width, height, margin } = chart.getDimensions();

  const svg = chart.container
    .append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
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
      chart.showTooltip(event, `${d.key} : ${hours}h ${minutes}m ${seconds}s`);
    })
    .on("mousemove", (event) => {
      chart.moveTooltip(event);
    })
    .on("mouseout", function () {
      d3.select(this).style("opacity", 1);
      chart.hideTooltip();
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

  chart.addResizeListener(() =>
    drawWindowRegexStackedChart(containerId, startDate, numberOfDays),
  );
}
