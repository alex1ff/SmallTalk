const SUPPORTED_LOCATIONS = Object.freeze([
  Object.freeze({countryCode: "US", cityKey: "new_york"}),
  Object.freeze({countryCode: "ID", cityKey: "bali"}),
  Object.freeze({countryCode: "AE", cityKey: "dubai"}),
  Object.freeze({countryCode: "TH", cityKey: "phuket"}),
]);

const SUPPORTED_LOCATION_IDENTITIES = new Set(
    SUPPORTED_LOCATIONS.map(
        ({countryCode, cityKey}) => `${countryCode}:${cityKey}`,
    ),
);

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeSupportedLocation(countryCodeValue, cityKeyValue) {
  const countryCode = normalizeString(countryCodeValue).toUpperCase();
  const cityKey = normalizeString(cityKeyValue).toLowerCase();
  if (!countryCode && !cityKey) {
    return null;
  }
  if (!countryCode || !cityKey) {
    return null;
  }
  const identity = `${countryCode}:${cityKey}`;
  return SUPPORTED_LOCATION_IDENTITIES.has(identity) ?
    {countryCode, cityKey, identity} :
    null;
}

function isSupportedLocation(countryCodeValue, cityKeyValue) {
  return normalizeSupportedLocation(countryCodeValue, cityKeyValue) !== null;
}

module.exports = {
  SUPPORTED_LOCATIONS,
  SUPPORTED_LOCATION_IDENTITIES,
  isSupportedLocation,
  normalizeSupportedLocation,
};
