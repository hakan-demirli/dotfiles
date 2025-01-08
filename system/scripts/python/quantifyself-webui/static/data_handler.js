import { fetchData } from "./api.js";
import { getWindowCategories } from "./window_category.js";
import { getCached } from "./cache.js";
import { get15MinuteInterval } from "./utils.js";
import { TIMEZONE_OFFSET, IDLE_MAX_DURATION } from "./constants.js";

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

function classifyRow(categories, clientClass, clientTitle) {
  return getCached("classifyRow", `${clientClass}__${clientTitle}`, () => {
    for (const category of categories) {
      for (const [subgroup, subgroupDetails] of Object.entries(
        category.childs,
      )) {
        for (const matchRule of subgroupDetails.match) {
          const titleRegex = new RegExp(matchRule.Title);
          const classRegex = new RegExp(matchRule.Class);

          const titleMatch = titleRegex.test(clientTitle);
          const classMatch = classRegex.test(clientClass);
          if (titleMatch && classMatch) {
            return { group: category.name, subgroup };
          }
        }
      }
    }
    return { group: "Uncategorized", subgroup: null };
  });
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
      timestamp: localTimestamp,
      clientClass,
      clientTitle,
      group,
      subgroup,
    };
  });
}

function calculateDurations(enrichedData, idleMaxDuration) {
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

async function getWindowCategoriesCached() {
  return getCached("windowCategories", "windowCategories", async () => {
    return await getWindowCategories();
  });
}

export async function processData(date, dbFile) {
  const dateString = date.toISOString().split("T")[0];

  return getCached("processedData", dateString, async () => {
    const data = await fetchDataForDate(date, dbFile);

    if (data.length === 0) {
      return {
        durationData: [],
        groupedData: {},
        hierarchicalData: {
          name: "Root",
          children: [],
        },
      };
    }

    const categories = await getWindowCategoriesCached();
    const enrichedData = transformData(data, categories, TIMEZONE_OFFSET);
    const durationData = calculateDurations(enrichedData, IDLE_MAX_DURATION);

    // Group durations for sunburst chart (CORRECTED LOGIC)
    const groupedData = {};
    durationData.forEach(({ group, subgroup, duration }) => {
      if (!groupedData[group]) {
        groupedData[group] = {};
      }
      if (!groupedData[group][subgroup]) {
        groupedData[group][subgroup] = 0;
      }
      groupedData[group][subgroup] += duration;
    });

    // Group durations for stacked area chart
    const timeGroupedData = {};
    durationData.forEach(({ timestamp, group, subgroup, duration }) => {
      const timeKey = get15MinuteInterval(timestamp);
      if (!timeGroupedData[timeKey]) {
        timeGroupedData[timeKey] = {};
      }
      if (!timeGroupedData[timeKey][group]) {
        timeGroupedData[timeKey][group] = {};
      }
      if (!timeGroupedData[timeKey][group][subgroup]) {
        timeGroupedData[timeKey][group][subgroup] = 0;
      }
      timeGroupedData[timeKey][group][subgroup] += duration;
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

    return { durationData, groupedData: timeGroupedData, hierarchicalData };
  });
}
export async function calculateWorkDuration(date, dbFile) {
  const dateString = date.toISOString().split("T")[0];

  return getCached("workDuration", dateString, async () => {
    const { durationData } = await processData(date, dbFile);

    if (durationData.length === 0) {
      return 0;
    }

    let workDuration = 0;
    durationData.forEach((d) => {
      if (d.group === "Work") workDuration += d.duration;
    });

    return workDuration;
  });
}

export function padDataWithMissingIntervals(
  combinedGroupedData,
  groups,
  subgroups,
) {
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

export async function fetchAndProcessData(date, dbFile) {
  const processed = await processData(date, dbFile);
  return processed;
}