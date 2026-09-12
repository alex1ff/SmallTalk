const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CITY_CATALOG_VERSION,
  CITY_CATALOG_SOURCE_PATH,
  EVENT_CITY_CATALOG,
  EventCityCatalogError,
  assertUniqueCityCatalogIdentities,
  buildCityLookup,
  normalizeEventCityIdentityInput,
  resolveEventCityIdentity,
  validateEventCityCatalog,
} = require("./event_city_catalog");

function assertCityCatalogError(fn, field, reason) {
  assert.throws(fn, (err) => {
    assert.equal(err instanceof EventCityCatalogError, true);
    assert.equal(err.field, field);
    assert.equal(err.reason, reason);
    return true;
  });
}

test("resolveEventCityIdentity returns canonical server-derived city fields", () => {
  const city = resolveEventCityIdentity(" ru ", "moscow");

  assert.equal(city.countryCode, "RU");
  assert.equal(city.cityKey, "moscow");
  assert.equal(city.cityNameRu, "Москва");
  assert.equal(city.cityNameEn, "Moscow");
  assert.equal(city.cityDisplayContext, "Россия");
  assert.equal(city.timeZoneId, "Europe/Moscow");
  assert.equal(city.catalogVersion, CITY_CATALOG_VERSION);
  assert.equal(CITY_CATALOG_SOURCE_PATH, "assets/jsons/events_city_catalog.json");
  assert.ok(city.aliases.includes("Москва"));
  assert.ok(Number.isInteger(city.priority));
});

test("normalizeEventCityIdentityInput validates identity syntax only", () => {
  assert.deepEqual(normalizeEventCityIdentityInput(" us ", "new_york"), {
    countryCode: "US",
    cityKey: "new_york",
  });

  assertCityCatalogError(
      () => normalizeEventCityIdentityInput("USA", "new_york"),
      "countryCode",
      "invalid_format",
  );
  assertCityCatalogError(
      () => normalizeEventCityIdentityInput("US", "New York"),
      "cityKey",
      "invalid_format",
  );
});

test("resolveEventCityIdentity rejects unknown canonical city", () => {
  assertCityCatalogError(
      () => resolveEventCityIdentity("RU", "unknown_city"),
      "cityKey",
      "unknown_city",
  );
});

test("event city catalog rejects duplicate city identities", () => {
  assertCityCatalogError(
      () => assertUniqueCityCatalogIdentities([
        EVENT_CITY_CATALOG[0],
        {...EVENT_CITY_CATALOG[0]},
      ]),
      "cityKey",
      "duplicate_city_identity",
  );
  assertCityCatalogError(
      () => buildCityLookup([
        EVENT_CITY_CATALOG[0],
        {...EVENT_CITY_CATALOG[0]},
      ]),
      "cityKey",
      "duplicate_city_identity",
  );
});

test("event city catalog rejects invalid timezone records", () => {
  assertCityCatalogError(
      () => validateEventCityCatalog([
        {
          countryCode: "RU",
          cityKey: "test_city",
          cityNameRu: "Тест",
          cityNameEn: "Test",
          cityDisplayContext: "Россия",
        },
      ]),
      "cityKey",
      "invalid_catalog_record",
  );
  assertCityCatalogError(
      () => validateEventCityCatalog([
        {
          countryCode: "RU",
          cityKey: "test_city",
          cityNameRu: "Тест",
          cityNameEn: "Test",
          cityDisplayContext: "Россия",
          timeZoneId: "Mars/Phobos",
          aliases: ["Test"],
          transliterations: ["Test"],
          priority: 1,
        },
      ]),
      "cityKey",
      "invalid_catalog_timezone",
  );
});
