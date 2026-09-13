const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const repoRoot = path.join(__dirname, "..", "..");
const manifest = JSON.parse(fs.readFileSync(
  path.join(repoRoot, "audit", "legacy_fallback_manifest.json"),
  "utf8",
));
const expectedEntryIds = new Set([
  "voip-legacy-user-token-read",
  "match-profile-raw-country-level",
  "video-session-participant-aliases",
  "active-call-history-alias-query",
  "unused-generated-history-helper",
]);

test("legacy fallback manifest is complete and references real source files", () => {
  assert.equal(manifest.schemaVersion, 1);
  assert.ok(Array.isArray(manifest.entries));
  assert.deepEqual(new Set(manifest.entries.map((entry) => entry.id)), expectedEntryIds);
  const ids = new Set();
  for (const entry of manifest.entries) {
    assert.match(entry.id, /^[a-z0-9-]+$/);
    assert.equal(ids.has(entry.id), false);
    ids.add(entry.id);
    for (const required of ["fieldsOrBranch", "canonicalFields", "legacyFields", "owner", "sources", "writeClassification", "privacyRisk", "retirementPrerequisites"]) {
      assert.ok(entry[required], `${entry.id} missing ${required}`);
    }
    for (const fields of [entry.fieldsOrBranch, entry.canonicalFields, entry.legacyFields]) {
      assert.ok(Array.isArray(fields) && fields.length > 0);
    }
    const legacyFields = new Set(entry.legacyFields);
    assert.equal(
      entry.canonicalFields.filter((field) => legacyFields.has(field)).length,
      0,
    );
    assert.ok(Array.isArray(entry.sources) && entry.sources.length > 0);
    for (const source of entry.sources) {
      assert.ok(fs.existsSync(path.join(repoRoot, source.path)), source.path);
      assert.match(source.symbol, /\S/);
      const sourceText = fs.readFileSync(path.join(repoRoot, source.path), "utf8");
      assert.match(sourceText, new RegExp(source.symbol.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
      assert.match(
        fs.readFileSync(path.join(repoRoot, source.path), "utf8"),
        new RegExp(source.contains.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")),
      );
    }
    if (entry.clientVersionEvidence == null) {
      assert.ok(entry.retirementPrerequisites.includes("owner approval"));
    }
    if (entry.productionUsageEvidence == null) {
      assert.ok(entry.retirementPrerequisites.some((item) => /usage|telemetry|confirmation|aggregate/i.test(item)));
    }
  }
  assert.equal(ids.size, manifest.entries.length);
});

test("manifest does not authorize retirement without evidence", () => {
  for (const entry of manifest.entries) {
    assert.equal(entry.retireNow, undefined);
    assert.equal(entry.minimumSupportedClientVersion, undefined);
    assert.equal(entry.retirementDate, undefined);
  }
});
