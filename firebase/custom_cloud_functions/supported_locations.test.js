const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SUPPORTED_LOCATIONS,
  normalizeSupportedLocation,
} = require("./supported_locations");

test("supported locations expose the four canonical identities", () => {
  assert.deepEqual(
      SUPPORTED_LOCATIONS.map(({countryCode, cityKey}) =>
        `${countryCode}:${cityKey}`,
      ),
      ["US:new_york", "ID:bali", "AE:dubai", "TH:phuket"],
  );
});

test("supported location normalization rejects legacy country-only values", () => {
  assert.deepEqual(normalizeSupportedLocation(" us ", " NEW_YORK "), {
    countryCode: "US",
    cityKey: "new_york",
    identity: "US:new_york",
  });
  assert.equal(normalizeSupportedLocation("US", ""), null);
  assert.equal(normalizeSupportedLocation("US", "los_angeles"), null);
  assert.equal(normalizeSupportedLocation("RU", "moscow"), null);
});
