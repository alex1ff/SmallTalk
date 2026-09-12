#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_SOURCE_PATH = path.resolve(
    __dirname,
    "../../../assets/jsons/events_city_catalog.json",
);
const DEFAULT_OUTPUT_PATH = path.resolve(
    __dirname,
    "../generated/event_city_catalog.generated.json",
);
const CITY_KEY_RE = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function assertPlainObject(value, field) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${field} must be an object`);
  }
}

function assertString(value, field, {nullable = false} = {}) {
  if (nullable && value === null) {
    return;
  }
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${field} must be a non-empty string`);
  }
}

function assertStringArray(value, field) {
  if (!Array.isArray(value)) {
    throw new Error(`${field} must be an array`);
  }
  for (const item of value) {
    assertString(item, field);
  }
}

function assertValidTimeZoneId(timeZoneId, field) {
  assertString(timeZoneId, field);
  try {
    new Intl.DateTimeFormat("en-US", {timeZone: timeZoneId}).format();
  } catch {
    throw new Error(`${field} must be a valid IANA timezone`);
  }
}

function normalizeCityRecord(city, index) {
  assertPlainObject(city, `cities[${index}]`);
  assertString(city.countryCode, `cities[${index}].countryCode`);
  assertString(city.cityKey, `cities[${index}].cityKey`);
  const countryCode = city.countryCode.trim().toUpperCase();
  const cityKey = city.cityKey.trim();
  if (city.countryCode !== countryCode) {
    throw new Error(`cities[${index}].countryCode must already be uppercase`);
  }
  if (city.cityKey !== cityKey) {
    throw new Error(`cities[${index}].cityKey must not have surrounding space`);
  }
  if (!/^[A-Z]{2}$/.test(countryCode)) {
    throw new Error(`cities[${index}].countryCode must be ISO alpha-2`);
  }
  if (!CITY_KEY_RE.test(cityKey)) {
    throw new Error(`cities[${index}].cityKey is invalid`);
  }

  assertString(city.nameRu, `cities[${index}].nameRu`);
  assertString(city.nameEn, `cities[${index}].nameEn`);
  assertString(city.regionCode, `cities[${index}].regionCode`, {
    nullable: true,
  });
  assertString(city.regionNameRu, `cities[${index}].regionNameRu`, {
    nullable: true,
  });
  assertString(city.regionNameEn, `cities[${index}].regionNameEn`, {
    nullable: true,
  });
  assertValidTimeZoneId(city.timeZoneId, `cities[${index}].timeZoneId`);
  assertString(city.displayContext, `cities[${index}].displayContext`);
  assertStringArray(city.aliases, `cities[${index}].aliases`);
  assertStringArray(city.transliterations, `cities[${index}].transliterations`);
  if (!Number.isInteger(city.priority)) {
    throw new Error(`cities[${index}].priority must be an integer`);
  }

  return {
    countryCode,
    cityKey,
    cityNameRu: city.nameRu.trim(),
    cityNameEn: city.nameEn.trim(),
    cityDisplayContext: city.displayContext.trim(),
    regionCode: city.regionCode,
    regionNameRu: city.regionNameRu,
    regionNameEn: city.regionNameEn,
    timeZoneId: city.timeZoneId.trim(),
    aliases: city.aliases.map((item) => item.trim()),
    transliterations: city.transliterations.map((item) => item.trim()),
    priority: city.priority,
  };
}

function buildGeneratedCatalog(source, {
  sourcePath = "assets/jsons/events_city_catalog.json",
} = {}) {
  assertPlainObject(source, "source");
  assertString(source.catalogVersion, "catalogVersion");
  if (!Array.isArray(source.cities) || source.cities.length === 0) {
    throw new Error("cities must be a non-empty array");
  }

  const seen = new Set();
  const cities = source.cities.map((city, index) => {
    const generated = normalizeCityRecord(city, index);
    const identity = `${generated.countryCode}:${generated.cityKey}`;
    if (seen.has(identity)) {
      throw new Error(`Duplicate city identity: ${identity}`);
    }
    seen.add(identity);
    return generated;
  });

  cities.sort((left, right) =>
    left.countryCode.localeCompare(right.countryCode) ||
      left.cityKey.localeCompare(right.cityKey),
  );

  return {
    catalogVersion: source.catalogVersion.trim(),
    generatedFrom: sourcePath,
    cities,
  };
}

function writeGeneratedCatalog({
  sourcePath = DEFAULT_SOURCE_PATH,
  outputPath = DEFAULT_OUTPUT_PATH,
} = {}) {
  const source = readJson(sourcePath);
  const generated = buildGeneratedCatalog(source);
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(
      outputPath,
      `${JSON.stringify(generated, null, 2)}\n`,
      "utf8",
  );
  return generated;
}

function main() {
  const sourcePath = process.argv[2] ?
    path.resolve(process.argv[2]) :
    DEFAULT_SOURCE_PATH;
  const outputPath = process.argv[3] ?
    path.resolve(process.argv[3]) :
    DEFAULT_OUTPUT_PATH;
  writeGeneratedCatalog({sourcePath, outputPath});
  process.stdout.write(`Generated ${outputPath}\n`);
}

if (require.main === module) {
  main();
}

module.exports = {
  DEFAULT_OUTPUT_PATH,
  DEFAULT_SOURCE_PATH,
  buildGeneratedCatalog,
  normalizeCityRecord,
  writeGeneratedCatalog,
};
