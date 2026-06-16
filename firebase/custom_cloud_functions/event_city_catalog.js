const CITY_KEY_RE = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;
const CITY_CATALOG_VERSION = "events-city-catalog-mvp-2026-06-16";

const EVENT_CITY_CATALOG = Object.freeze([
  {
    countryCode: "RU",
    cityKey: "moscow",
    cityNameRu: "Москва",
    cityNameEn: "Moscow",
    cityDisplayContext: "Россия",
    timeZoneId: "Europe/Moscow",
  },
  {
    countryCode: "RU",
    cityKey: "saint_petersburg",
    cityNameRu: "Санкт-Петербург",
    cityNameEn: "Saint Petersburg",
    cityDisplayContext: "Россия",
    timeZoneId: "Europe/Moscow",
  },
  {
    countryCode: "US",
    cityKey: "new_york",
    cityNameRu: "Нью-Йорк",
    cityNameEn: "New York",
    cityDisplayContext: "United States",
    timeZoneId: "America/New_York",
  },
  {
    countryCode: "GB",
    cityKey: "london",
    cityNameRu: "Лондон",
    cityNameEn: "London",
    cityDisplayContext: "United Kingdom",
    timeZoneId: "Europe/London",
  },
  {
    countryCode: "DE",
    cityKey: "berlin",
    cityNameRu: "Берлин",
    cityNameEn: "Berlin",
    cityDisplayContext: "Deutschland",
    timeZoneId: "Europe/Berlin",
  },
  {
    countryCode: "FR",
    cityKey: "paris",
    cityNameRu: "Париж",
    cityNameEn: "Paris",
    cityDisplayContext: "France",
    timeZoneId: "Europe/Paris",
  },
  {
    countryCode: "IT",
    cityKey: "rome",
    cityNameRu: "Рим",
    cityNameEn: "Rome",
    cityDisplayContext: "Italia",
    timeZoneId: "Europe/Rome",
  },
  {
    countryCode: "ES",
    cityKey: "madrid",
    cityNameRu: "Мадрид",
    cityNameEn: "Madrid",
    cityDisplayContext: "España",
    timeZoneId: "Europe/Madrid",
  },
  {
    countryCode: "TR",
    cityKey: "istanbul",
    cityNameRu: "Стамбул",
    cityNameEn: "Istanbul",
    cityDisplayContext: "Türkiye",
    timeZoneId: "Europe/Istanbul",
  },
  {
    countryCode: "AE",
    cityKey: "dubai",
    cityNameRu: "Дубай",
    cityNameEn: "Dubai",
    cityDisplayContext: "United Arab Emirates",
    timeZoneId: "Asia/Dubai",
  },
  {
    countryCode: "KZ",
    cityKey: "almaty",
    cityNameRu: "Алматы",
    cityNameEn: "Almaty",
    cityDisplayContext: "Қазақстан",
    timeZoneId: "Asia/Almaty",
  },
  {
    countryCode: "AM",
    cityKey: "yerevan",
    cityNameRu: "Ереван",
    cityNameEn: "Yerevan",
    cityDisplayContext: "Հայաստան",
    timeZoneId: "Asia/Yerevan",
  },
  {
    countryCode: "GE",
    cityKey: "tbilisi",
    cityNameRu: "Тбилиси",
    cityNameEn: "Tbilisi",
    cityDisplayContext: "საქართველო",
    timeZoneId: "Asia/Tbilisi",
  },
]);

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
      city.timeZoneId.trim() === ""
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

module.exports = {
  CITY_CATALOG_VERSION,
  CITY_KEY_RE,
  EVENT_CITY_CATALOG,
  EventCityCatalogError,
  assertUniqueCityCatalogIdentities,
  assertValidTimeZoneId,
  buildCityLookup,
  normalizeEventCityIdentityInput,
  resolveEventCityIdentity,
  validateEventCityCatalog,
};
