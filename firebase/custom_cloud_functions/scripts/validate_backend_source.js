#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const {
  parseFunctionsListJson,
} = require("./validate_deployment_readiness");

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");
const DEFAULT_CONFIG_PATH = path.join(REPO_ROOT, "firebase", "firebase.json");
const DEFAULT_MANIFEST_PATH = path.join(
    REPO_ROOT,
    "firebase",
    "backend_sources.json",
);

function parseArgs(argv = process.argv.slice(2)) {
  const options = {
    configPath: DEFAULT_CONFIG_PATH,
    manifestPath: DEFAULT_MANIFEST_PATH,
    productionJson: false,
    json: false,
    outputPath: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--config") {
      options.configPath = path.resolve(argv[index + 1] || "");
      index += 1;
    } else if (arg === "--manifest") {
      options.manifestPath = path.resolve(argv[index + 1] || "");
      index += 1;
    } else if (arg === "--production-json") {
      options.productionJson = true;
    } else if (arg === "--json") {
      options.json = true;
    } else if (arg === "--output") {
      options.outputPath = path.resolve(argv[index + 1] || "");
      index += 1;
    }
  }

  return options;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function readExports(sourcePath) {
  const source = fs.readFileSync(sourcePath, "utf8");
  const exports = [];
  const exportPattern = /exports\.([A-Za-z0-9_$]+)\s*=/g;
  let match = exportPattern.exec(source);
  while (match) {
    exports.push(match[1]);
    match = exportPattern.exec(source);
  }
  return [...new Set(exports)].sort();
}

function validateBackendSource({
  config,
  manifest,
  repoRoot = REPO_ROOT,
} = {}) {
  const failures = [];
  const warnings = [];
  const configuredFunctions = Array.isArray(config?.functions) ?
    config.functions : [];
  const manifestEntries = Array.isArray(manifest?.configured) ?
    manifest.configured : [];
  const retiredEntries = Array.isArray(manifest?.retired) ?
    manifest.retired : [];
  const canonical = manifest?.canonical || {};

  if (configuredFunctions.length === 0) {
    failures.push({
      reason: "missing_functions_config",
      message: "firebase.json does not configure a functions source",
    });
  }

  if (!canonical.codebase || !canonical.source || !canonical.index) {
    failures.push({
      reason: "invalid_canonical_manifest",
      message: "canonical codebase/source/index must be declared",
    });
  }

  const expectedCanonicalIndex = `${canonical.source}/index.js`;
  if (canonical.index && canonical.index !== expectedCanonicalIndex) {
    failures.push({
      reason: "canonical_index_mismatch",
      message: `canonical index must be ${expectedCanonicalIndex}`,
    });
  }

  const canonicalIndexPath = path.join(
      repoRoot,
      "firebase",
      canonical.index || "",
  );
  if (canonical.index && !fs.existsSync(canonicalIndexPath)) {
    failures.push({
      reason: "missing_canonical_index",
      message: `${canonical.index} does not exist`,
    });
  }

  const canonicalEntries = manifestEntries.filter((entry) =>
    entry.status === "canonical",
  );
  if (canonicalEntries.length !== 1 ||
      canonicalEntries[0]?.codebase !== canonical.codebase) {
    failures.push({
      reason: "canonical_count_mismatch",
      message: "manifest must declare exactly one canonical codebase",
    });
  }

  if (manifestEntries.length !== 1) {
    failures.push({
      reason: "configured_manifest_count_mismatch",
      message: "manifest must track exactly one configured codebase",
    });
  }

  if (configuredFunctions.length !== 1 ||
      configuredFunctions[0]?.codebase !== canonical.codebase ||
      configuredFunctions[0]?.source !== canonical.source) {
    failures.push({
      reason: "firebase_canonical_config_mismatch",
      message: "firebase.json must configure only the canonical codebase/source",
    });
  }

  const configKeys = new Set();
  for (const configured of configuredFunctions) {
    const codebase = String(configured.codebase || "").trim();
    const source = String(configured.source || "").trim();
    const key = `${codebase}:${source}`;
    if (!codebase || !source || configKeys.has(key)) {
      failures.push({
        reason: "invalid_or_duplicate_config",
        message: `invalid or duplicate functions entry ${key}`,
      });
      continue;
    }
    configKeys.add(key);

    const entry = manifestEntries.find((item) =>
      item.codebase === codebase && item.source === source,
    );
    if (!entry) {
      failures.push({
        reason: "untracked_codebase",
        codebase,
        source,
        message: `${key} is configured in firebase.json but missing from manifest`,
      });
      continue;
    }

    const indexPath = path.join(repoRoot, "firebase", source, "index.js");
    if (!fs.existsSync(indexPath)) {
      failures.push({
        reason: "missing_source_index",
        codebase,
        source,
        message: `${source}/index.js does not exist`,
      });
      continue;
    }

    if (entry.status === "legacy-inventory-required") {
      warnings.push({
        reason: "legacy_codebase_configured",
        codebase,
        message: `${key} remains configured until production inventory is confirmed`,
      });
    }

    const knownExports = entry.knownExports;
    if (Array.isArray(knownExports)) {
      const actualExports = readExports(indexPath);
      const unknownExports = actualExports.filter((name) =>
        !knownExports.includes(name),
      );
      const missingExports = knownExports.filter((name) =>
        !actualExports.includes(name),
      );
      if (unknownExports.length || missingExports.length) {
        failures.push({
          reason: "legacy_export_inventory_mismatch",
          codebase,
          actualExports,
          knownExports,
          unknownExports,
          missingExports,
          message: `${key} export inventory is stale`,
        });
      }
    }
  }

  for (const entry of manifestEntries) {
    if (!entry.codebase || !entry.source || !entry.status) {
      failures.push({
        reason: "invalid_manifest_entry",
        message: "every manifest entry needs codebase, source and status",
      });
    }
  }

  for (const entry of retiredEntries) {
    if (!entry.codebase || entry.status !== "retired" ||
        !entry.reason || !Array.isArray(entry.knownExports)) {
      failures.push({
        reason: "invalid_retired_manifest_entry",
        message: "retired entries need codebase, reason and knownExports",
      });
    }
    if (configuredFunctions.some((configured) =>
      configured.codebase === entry.codebase,
    )) {
      failures.push({
        reason: "retired_codebase_still_configured",
        codebase: entry.codebase,
        message: `${entry.codebase} is marked retired but still configured`,
      });
    }
  }

  return {
    ok: failures.length === 0,
    canonicalCodebase: canonical.codebase || null,
    configuredCodebases: [...configKeys],
    failures,
    warnings,
  };
}

function validateProductionInventory(functionsList, {
  canonicalCodebase = "custom_cloud_functions",
  knownCodebases = ["custom_cloud_functions", "functions"],
  retiredFunctionIds = [],
  expectedFunctionIds = null,
} = {}) {
  const failures = [];
  const warnings = [];
  const deployedIds = new Set();
  const inventory = [];
  for (const fn of functionsList || []) {
    const codebase = String(fn.codebase || "").trim();
    const id = String(fn.id || "").trim();
    if (!id) {
      failures.push({
        reason: "production_function_id_missing",
        message: "functions:list returned a function without id",
      });
      continue;
    }
    if (deployedIds.has(id)) {
      failures.push({
        reason: "production_duplicate_function_id",
        id,
        message: `functions:list returned duplicate id ${id}`,
      });
    }
    deployedIds.add(id);
    inventory.push({
      id,
      codebase: codebase || null,
      region: fn.region || null,
      platform: fn.platform || null,
      runtime: fn.runtime || null,
      state: fn.state || null,
      hash: fn.hash || null,
      serviceAccount: fn.serviceAccount || null,
      trigger: readTriggerMetadata(fn),
    });

    if (retiredFunctionIds.includes(id)) {
      failures.push({
        reason: "production_retired_function",
        id,
        codebase,
        message: `${id} is retired and must not be deployed`,
      });
    } else if (!codebase) {
      failures.push({
        reason: "production_codebase_missing",
        id,
        message: `${id} has no codebase in functions:list output`,
      });
    } else if (!knownCodebases.includes(codebase)) {
      failures.push({
        reason: "production_unknown_codebase",
        id,
        codebase,
        message: `${id} is deployed from an untracked codebase ${codebase}`,
      });
    } else if (codebase !== canonicalCodebase) {
      failures.push({
        reason: "production_noncanonical_codebase",
        id,
        codebase,
        message: `${id} is still deployed from noncanonical codebase ${codebase}`,
      });
    }
  }

  if (Array.isArray(expectedFunctionIds)) {
    if (expectedFunctionIds.length === 0) {
      failures.push({
        reason: "canonical_export_set_empty",
        message: "canonical source must export at least one function",
      });
    }
    const expectedIds = new Set(expectedFunctionIds);
    for (const id of expectedIds) {
      if (!deployedIds.has(id)) {
        failures.push({
          reason: "production_function_missing",
          id,
          message: `${id} is exported by the canonical source but not deployed`,
        });
      }
    }
    for (const id of deployedIds) {
      if (!expectedIds.has(id)) {
        failures.push({
          reason: "production_function_unexpected",
          id,
          message: `${id} is deployed but not exported by the canonical source`,
        });
      }
    }
  }

  return {
    ok: failures.length === 0,
    failures,
    warnings,
    inspectedFunctions: (functionsList || []).length,
    inventory: inventory.sort((left, right) => left.id.localeCompare(right.id)),
  };
}

function readTriggerMetadata(fn = {}) {
  if (fn.callableTrigger) return "callable";
  if (fn.httpsTrigger) return "https";
  if (fn.scheduleTrigger) return "scheduled";
  if (fn.eventTrigger) {
    return String(fn.eventTrigger.eventType || "event");
  }
  return "unknown";
}

function formatReport(report) {
  const lines = [
    `Backend source validation: ${report.ok ? "PASS" : "FAIL"}`,
    `canonical=${report.canonicalCodebase || "unknown"}`,
  ];
  for (const failure of report.failures || []) {
    lines.push(`FAIL ${failure.reason}: ${failure.message}`);
  }
  for (const warning of report.warnings || []) {
    lines.push(`WARN ${warning.reason}: ${warning.message}`);
  }
  return lines.join("\n");
}

async function readStdin() {
  return await new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => data += chunk);
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
}

async function main() {
  const options = parseArgs();
  const config = readJson(options.configPath);
  const manifest = readJson(options.manifestPath);
  const localReport = validateBackendSource({config, manifest});
  let report = localReport;

  if (options.productionJson) {
    const rawInput = await readStdin();
    const functionsList = parseFunctionsListJson(rawInput);
    const productionReport = validateProductionInventory(functionsList, {
      canonicalCodebase: manifest.canonical.codebase,
      knownCodebases: [
        ...manifest.configured.map((entry) => entry.codebase),
        ...(manifest.retired || []).map((entry) => entry.codebase),
      ],
      retiredFunctionIds: (manifest.retired || [])
        .flatMap((entry) => entry.knownExports || []),
      expectedFunctionIds: readExports(path.join(
          REPO_ROOT,
          "firebase",
          manifest.canonical.index,
      )),
    });
    report = {
      ...localReport,
      ok: localReport.ok && productionReport.ok,
      failures: [...localReport.failures, ...productionReport.failures],
      warnings: [...localReport.warnings, ...productionReport.warnings],
      inspectedFunctions: productionReport.inspectedFunctions,
      generatedAtUtc: new Date().toISOString(),
      productionInventory: productionReport.inventory,
    };
  }

  if (options.outputPath) {
    fs.mkdirSync(path.dirname(options.outputPath), {recursive: true});
    fs.writeFileSync(
        options.outputPath,
        `${JSON.stringify(report, null, 2)}\n`,
        "utf8",
    );
  }

  if (options.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(`${formatReport(report)}\n`);
  }
  process.exitCode = report.ok ? 0 : 1;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`validate_backend_source failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = {
  formatReport,
  readExports,
  readTriggerMetadata,
  validateBackendSource,
  validateProductionInventory,
};
