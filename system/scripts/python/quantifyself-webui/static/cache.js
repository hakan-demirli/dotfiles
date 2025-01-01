const cache = {};

function generateCacheKey(prefix, ...args) {
  return `${prefix}__${args.join("__")}`;
}

export function getCached(prefix, key, compute) {
  const cacheKey = generateCacheKey(prefix, key);
  if (cache[cacheKey] === undefined) {
    cache[cacheKey] = compute();
  }
  return cache[cacheKey];
}
