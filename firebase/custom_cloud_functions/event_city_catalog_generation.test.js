const fs = require("node:fs");
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  DEFAULT_OUTPUT_PATH,
  DEFAULT_SOURCE_PATH,
  buildGeneratedCatalog,
} = require("./scripts/generate_event_city_catalog");

test("generated backend city catalog matches app source catalog", () => {
  const source = JSON.parse(fs.readFileSync(DEFAULT_SOURCE_PATH, "utf8"));
  const generated = JSON.parse(fs.readFileSync(DEFAULT_OUTPUT_PATH, "utf8"));

  assert.deepEqual(generated, buildGeneratedCatalog(source));
});

test("app city catalog source has expected MVP city schema", () => {
  const source = JSON.parse(fs.readFileSync(DEFAULT_SOURCE_PATH, "utf8"));

  assert.equal(source.catalogVersion, generatedCatalogVersion(source));
  assert.ok(source.cities.length >= 10);
  assert.ok(source.cities.every((city) =>
    Object.prototype.hasOwnProperty.call(city, "aliases") &&
      Object.prototype.hasOwnProperty.call(city, "transliterations") &&
      Object.prototype.hasOwnProperty.call(city, "displayContext") &&
      Object.prototype.hasOwnProperty.call(city, "timeZoneId") &&
      Object.prototype.hasOwnProperty.call(city, "priority"),
  ));
});

test("generator rejects non-canonical source city identities", () => {
  const source = JSON.parse(fs.readFileSync(DEFAULT_SOURCE_PATH, "utf8"));
  const lowercaseCountry = {
    ...source,
    cities: [{...source.cities[0], countryCode: "ru"}],
  };
  const spacedCityKey = {
    ...source,
    cities: [{...source.cities[0], cityKey: " moscow "}],
  };

  assert.throws(
      () => buildGeneratedCatalog(lowercaseCountry),
      /countryCode must already be uppercase/,
  );
  assert.throws(
      () => buildGeneratedCatalog(spacedCityKey),
      /cityKey must not have surrounding space/,
  );
});

function generatedCatalogVersion(source) {
  return buildGeneratedCatalog(source).catalogVersion;
}
