const REQUIRED_METADATA = [
  "commit",
  "dirtyState",
  "flutterVersion",
  "dartVersion",
  "buildMode",
  "deviceModel",
  "osVersion",
  "deviceKind",
  "refreshRateHz",
  "scenarioVersion",
  "collectionMethod",
  "network",
  "authState",
  "cacheState",
];
const VALID_STATUSES = new Set(["measured", "blocked", "not_collected"]);
const VALID_DIRECTIONS = new Set(["lower_is_better", "higher_is_better"]);
const VALID_BUILD_MODES = new Set(["profile", "release"]);
const VALID_DEVICE_KINDS = new Set(["physical", "emulator", "browser"]);
const VALID_DIRTY_STATES = new Set(["clean", "dirty"]);
const VALID_MEASUREMENT_TYPES = new Set(["runtime", "static"]);
const PROVENANCE_METADATA = new Set(["commit", "dirtyState"]);

function isFiniteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function validatePerformanceSnapshot(snapshot) {
  const errors = [];
  if (!snapshot || snapshot.schemaVersion !== 1) {
    errors.push("schemaVersion must be 1");
  }
  const metadata = snapshot?.metadata;
  for (const field of REQUIRED_METADATA) {
    if (metadata?.[field] === undefined || metadata[field] === null || metadata[field] === "") {
      errors.push(`metadata.${field} is required`);
    }
  }
  for (const field of REQUIRED_METADATA.filter((field) => field !== "refreshRateHz")) {
    if (typeof metadata?.[field] !== "string") {
      errors.push(`metadata.${field} must be a non-empty string`);
    }
  }
  if (!VALID_BUILD_MODES.has(metadata?.buildMode)) {
    errors.push("metadata.buildMode must be profile or release");
  }
  if (!VALID_DEVICE_KINDS.has(metadata?.deviceKind)) {
    errors.push("metadata.deviceKind must be physical, emulator or browser");
  }
  if (!VALID_DIRTY_STATES.has(metadata?.dirtyState)) {
    errors.push("metadata.dirtyState must be clean or dirty");
  }
  const refreshRateIsValid = metadata?.deviceKind === "browser"
    ? metadata?.refreshRateHz === "not_applicable"
    : Number.isInteger(metadata?.refreshRateHz) && metadata.refreshRateHz > 0;
  if (!refreshRateIsValid) {
    errors.push("metadata.refreshRateHz must be a positive integer, or not_applicable for browser");
  }
  if (!snapshot?.metrics || typeof snapshot.metrics !== "object" || Array.isArray(snapshot.metrics)) {
    errors.push("metrics must be a map");
    return errors;
  }
  for (const [name, metric] of Object.entries(snapshot.metrics)) {
    if (!VALID_STATUSES.has(metric?.status)) {
      errors.push(`metrics.${name}.status is invalid`);
      continue;
    }
    if (typeof metric.unit !== "string" || metric.unit.length === 0) {
      errors.push(`metrics.${name}.unit is required`);
    }
    if (!VALID_DIRECTIONS.has(metric.direction)) {
      errors.push(`metrics.${name}.direction is invalid`);
    }
    if (!Array.isArray(metric.samples)) {
      errors.push(`metrics.${name}.samples must be an array`);
    } else if (metric.status === "measured") {
      const samplesAreFinite = metric.samples.length > 0 &&
        metric.samples.every((sample) => isFiniteNumber(sample));
      if (!samplesAreFinite) {
        errors.push(`metrics.${name}.measured samples must be finite and non-empty`);
      }
      if (!VALID_MEASUREMENT_TYPES.has(metric.measurementType)) {
        errors.push(`metrics.${name}.measurementType must be runtime or static`);
      } else if (samplesAreFinite && metric.measurementType === "runtime" && metric.samples.length < 5) {
        errors.push(`metrics.${name}.runtime requires at least 5 samples`);
      } else if (samplesAreFinite && metric.measurementType === "static" && metric.samples.length !== 1) {
        errors.push(`metrics.${name}.static requires exactly 1 sample`);
      }
    } else if (metric.samples.length !== 0) {
      errors.push(`metrics.${name}.${metric.status} samples must be empty`);
    }
    if ((metric.status === "blocked" || metric.status === "not_collected") &&
        (typeof metric.reason !== "string" || metric.reason.trim().length === 0)) {
      errors.push(`metrics.${name}.${metric.status} requires reason`);
    }
    if (metric.budget !== undefined && metric.budget !== null) {
      if (typeof metric.budget !== "object" ||
          (metric.budget.maxRegressionPercent !== null &&
           (!isFiniteNumber(metric.budget.maxRegressionPercent) || metric.budget.maxRegressionPercent < 0))) {
        errors.push(`metrics.${name}.budget.maxRegressionPercent must be null or non-negative`);
      }
    }
  }
  return errors;
}

function compatibleSnapshots(baseline, candidate) {
  return REQUIRED_METADATA.filter((field) => !PROVENANCE_METADATA.has(field)).every((field) =>
    baseline.metadata[field] === candidate.metadata[field]);
}

function comparePerformanceSnapshots(baseline, candidate) {
  const validationErrors = [
    ...validatePerformanceSnapshot(baseline).map((error) => `baseline: ${error}`),
    ...validatePerformanceSnapshot(candidate).map((error) => `candidate: ${error}`),
  ];
  if (validationErrors.length > 0) return {status: "invalid", errors: validationErrors};
  if (!compatibleSnapshots(baseline, candidate)) {
    return {status: "incompatible", metrics: {}, reason: "device/build/scenario/method fingerprints differ"};
  }
  const metrics = {};
  for (const name of new Set([...Object.keys(baseline.metrics), ...Object.keys(candidate.metrics)])) {
    const base = baseline.metrics[name];
    const next = candidate.metrics[name];
    const baselineBudget = base?.budget?.maxRegressionPercent;
    if (!next || next.status !== "measured") {
      if (base?.status === "measured" && baselineBudget !== null && baselineBudget !== undefined) {
        metrics[name] = {
          status: "incomplete",
          reason: next?.reason ?? "budgeted candidate metric missing",
        };
      } else {
        metrics[name] = {
          status: next?.status ?? "not_collected",
          reason: next?.reason ?? "candidate metric missing",
        };
      }
      continue;
    }
    if (!base || base.status !== "measured") {
      metrics[name] = {status: "unbudgeted", reason: "baseline metric is not measured"};
      continue;
    }
    if (base.unit !== next.unit || base.direction !== next.direction ||
        base.measurementType !== next.measurementType) {
      metrics[name] = {
        status: "incompatible",
        reason: "metric unit, direction or measurement type differs",
      };
      continue;
    }
    const budget = baselineBudget;
    if (budget === null || budget === undefined) {
      metrics[name] = {status: "unbudgeted", reason: "no explicit regression budget"};
      continue;
    }
    const baselineValue = base.samples.reduce((sum, value) => sum + value, 0) / base.samples.length;
    const candidateValue = next.samples.reduce((sum, value) => sum + value, 0) / next.samples.length;
    const changePercent = baselineValue === 0
      ? (candidateValue === 0 ? 0 : Infinity)
      : ((candidateValue - baselineValue) / Math.abs(baselineValue)) * 100;
    const regressionPercent = next.direction === "lower_is_better"
      ? changePercent
      : -changePercent;
    metrics[name] = {
      status: regressionPercent <= budget ? "pass" : "regression",
      baselineValue,
      candidateValue,
      regressionPercent,
      budgetPercent: budget,
      budgetSource: "baseline",
    };
  }
  return {status: "compared", metrics};
}

module.exports = {
  REQUIRED_METADATA,
  comparePerformanceSnapshots,
  validatePerformanceSnapshot,
};
