const CITY_KEY_RE = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;
const GENERATED_CITY_CATALOG = require(
    "./generated/event_city_catalog.generated.json",
);
const {isSupportedLocation} = require("./supported_locations");
const CITY_CATALOG_VERSION = GENERATED_CITY_CATALOG.catalogVersion;
const CITY_CATALOG_SOURCE_PATH = GENERATED_CITY_CATALOG.generatedFrom;
const EVENT_CITY_CATALOG = Object.freeze(
    GENERATED_CITY_CATALOG.cities.map((city) => Object.freeze({...city})),
);

class EventCityCatalogError extends Error {
  constructor(field, reason, message, options = {}) {
    super(message || `${field}:${reason}`);
    this.name = "EventCityCatalogError";
    this.field = field;
    this.reason = reason;
    this.internal = options.internal === true;
    this.timeZoneId = options.timeZoneId || "";
  }
}

function buildCityLookup(catalog = EVENT_CITY_CATALOG) {
  assertUniqueCityCatalogIdentities(catalog);
  const lookup = new Map();
  for (const city of catalog) {
    lookup.set(`${city.countryCode}:${city.cityKey}`, city);
  }
  return lookup;
}

function assertValidTimeZoneId(timeZoneId) {
  if (typeof timeZoneId !== "string" || timeZoneId.trim() === "") {
    throw new EventCityCatalogError(
        "cityKey",
        "invalid_catalog_timezone",
        "Configured city timezone is invalid",
        {internal: true, timeZoneId: ""},
    );
  }
  try {
    new Intl.DateTimeFormat("en-US", {timeZone: timeZoneId}).format();
  } catch (err) {
    throw new EventCityCatalogError(
        "cityKey",
        "invalid_catalog_timezone",
        "Configured city timezone is invalid",
        {internal: true, timeZoneId},
    );
  }
}

function assertUniqueCityCatalogIdentities(catalog = EVENT_CITY_CATALOG) {
  const seen = new Set();
  for (const city of catalog) {
    const identity = `${city.countryCode}:${city.cityKey}`;
    if (seen.has(identity)) {
      throw new EventCityCatalogError(
          "cityKey",
          "duplicate_city_identity",
          `Duplicate city identity: ${identity}`,
          {internal: true},
      );
    }
    seen.add(identity);
  }
}

function validateEventCityCatalog(catalog = EVENT_CITY_CATALOG) {
  assertUniqueCityCatalogIdentities(catalog);
  for (const city of catalog) {
    const identity = normalizeEventCityIdentityInput(
        city.countryCode,
        city.cityKey,
    );
    if (
      identity.countryCode !== city.countryCode ||
      identity.cityKey !== city.cityKey ||
      typeof city.cityNameRu !== "string" ||
      city.cityNameRu.trim() === "" ||
      typeof city.cityNameEn !== "string" ||
      city.cityNameEn.trim() === "" ||
      typeof city.cityDisplayContext !== "string" ||
      city.cityDisplayContext.trim() === "" ||
      typeof city.timeZoneId !== "string" ||
      city.timeZoneId.trim() === "" ||
      !Array.isArray(city.aliases) ||
      !Array.isArray(city.transliterations) ||
      !Number.isInteger(city.priority)
    ) {
      throw new EventCityCatalogError(
          "cityKey",
          "invalid_catalog_record",
          `Invalid city catalog record: ${city.countryCode}:${city.cityKey}`,
          {internal: true},
      );
    }
    assertValidTimeZoneId(city.timeZoneId);
  }
}

function normalizeEventCityIdentityInput(countryCodeValue, cityKeyValue) {
  if (typeof countryCodeValue !== "string") {
    throw new EventCityCatalogError("countryCode", "invalid_type");
  }
  if (typeof cityKeyValue !== "string") {
    throw new EventCityCatalogError("cityKey", "invalid_type");
  }

  const countryCode = countryCodeValue.trim().toUpperCase();
  const cityKey = cityKeyValue.trim();
  if (!/^[A-Z]{2}$/.test(countryCode)) {
    throw new EventCityCatalogError("countryCode", "invalid_format");
  }
  if (!CITY_KEY_RE.test(cityKey)) {
    throw new EventCityCatalogError("cityKey", "invalid_format");
  }

  return {countryCode, cityKey};
}

validateEventCityCatalog(EVENT_CITY_CATALOG);
const CITY_BY_IDENTITY = buildCityLookup();

function resolveEventCityIdentity(
    countryCodeValue,
    cityKeyValue,
    {lookup = CITY_BY_IDENTITY} = {},
) {
  const {countryCode, cityKey} = normalizeEventCityIdentityInput(
      countryCodeValue,
      cityKeyValue,
  );
  const city = lookup.get(`${countryCode}:${cityKey}`);
  if (!city) {
    throw new EventCityCatalogError("cityKey", "unknown_city");
  }
  assertValidTimeZoneId(city.timeZoneId);
  return {
    ...city,
    catalogVersion: CITY_CATALOG_VERSION,
  };
}

function resolveSupportedEventCityIdentity(countryCodeValue, cityKeyValue) {
  const city = resolveEventCityIdentity(countryCodeValue, cityKeyValue);
  if (!isSupportedLocation(city.countryCode, city.cityKey)) {
    throw new EventCityCatalogError("cityKey", "unsupported_city");
  }
  return city;
}

module.exports = {
  CITY_CATALOG_VERSION,
  CITY_CATALOG_SOURCE_PATH,
  CITY_KEY_RE,
  EVENT_CITY_CATALOG,
  EventCityCatalogError,
  assertUniqueCityCatalogIdentities,
  assertValidTimeZoneId,
  buildCityLookup,
  normalizeEventCityIdentityInput,
  resolveEventCityIdentity,
  resolveSupportedEventCityIdentity,
  validateEventCityCatalog,
};
