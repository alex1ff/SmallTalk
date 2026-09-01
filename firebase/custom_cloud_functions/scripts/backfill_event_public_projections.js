#!/usr/bin/env node

const {spawnSync} = require("node:child_process");
const crypto = require("node:crypto");

const DEFAULT_PROJECT_ID = "smalltalk-2109b";
const DEFAULT_REGION = "us-central1";
const DEFAULT_MAX_RUNS = 100;
const POLL_INTERVAL_MS = 2000;
const RUN_TIMEOUT_MS = 120000;
const API_ATTEMPTS = 5;
let cachedFirebaseAccessToken = null;

function parseFirebaseJson(rawOutput) {
  const raw = String(rawOutput || "");
  const start = raw.indexOf("{");
  if (start < 0) throw new Error("Firebase CLI returned no JSON");
  return JSON.parse(raw.slice(start));
}

function schedulerTopicName(region = DEFAULT_REGION) {
  return `firebase-schedule-repairEventPublicProjections-${region}`;
}

function backfillPassComplete(document) {
  const fields = document?.fields || {};
  return fields.eventPassComplete?.booleanValue === true &&
    fields.projectionPassComplete?.booleanValue === true;
}

function updatedAtValue(document) {
  return document?.fields?.updatedAt?.timestampValue || "";
}

function firebaseAccessToken() {
  if (cachedFirebaseAccessToken) return cachedFirebaseAccessToken;
  const result = spawnSync("npx", [
    "-y",
    "firebase-tools@latest",
    "login:list",
    "--json",
  ], {encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]});
  if (result.status !== 0) {
    throw new Error("Firebase CLI authentication is unavailable");
  }
  const response = parseFirebaseJson(result.stdout);
  const token = response.result?.[0]?.tokens?.access_token;
  if (typeof token !== "string" || token.length === 0) {
    throw new Error("Firebase CLI returned no access token");
  }
  cachedFirebaseAccessToken = token;
  return cachedFirebaseAccessToken;
}

async function authorizedJson(url, {method = "GET", body} = {}) {
  const requestBody = body == null ? null : JSON.stringify(body);
  let lastError = null;
  for (let attempt = 0; attempt < API_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${firebaseAccessToken()}`,
          "Content-Type": "application/json",
        },
        ...(requestBody == null ? {} : {body: requestBody}),
      });
      if (response.status === 404 && method === "GET") return null;
      const text = await response.text();
      if (response.ok) return text ? JSON.parse(text) : {};
      lastError = new Error(
          `Google API ${response.status}: ${text.slice(0, 500)}`,
      );
      if (response.status === 401) cachedFirebaseAccessToken = null;
      if (response.status < 500 && response.status !== 401 &&
          response.status !== 429) {
        lastError.nonRetryable = true;
        throw lastError;
      }
    } catch (error) {
      if (error?.nonRetryable === true) throw error;
      lastError = error;
    }
    if (attempt + 1 < API_ATTEMPTS) {
      await new Promise((resolve) => {
        setTimeout(resolve, 1000 * (attempt + 1));
      });
    }
  }
  throw lastError || new Error("Google API request failed");
}

async function readRepairState(projectId) {
  const path = "maintenance/eventPublicProjectionRepair";
  return authorizedJson(
      `https://firestore.googleapis.com/v1/projects/${projectId}` +
      `/databases/(default)/documents/${path}`,
  );
}

async function resetRepairState(projectId) {
  const path = "maintenance/eventPublicProjectionRepair";
  const passId = crypto.randomUUID();
  const fields = [
    "eventCursorId",
    "projectionCursorId",
    "eventPassComplete",
    "projectionPassComplete",
    "passId",
    "updatedAt",
  ];
  const updateMask = fields
      .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
      .join("&");
  return authorizedJson(
      `https://firestore.googleapis.com/v1/projects/${projectId}` +
      `/databases/(default)/documents/${path}?${updateMask}`,
      {
        method: "PATCH",
        body: {fields: {
          eventCursorId: {nullValue: null},
          projectionCursorId: {nullValue: null},
          eventPassComplete: {booleanValue: false},
          projectionPassComplete: {booleanValue: false},
          passId: {stringValue: passId},
          updatedAt: {timestampValue: new Date().toISOString()},
        }},
      },
  );
}

async function publishRepairRun(projectId, region) {
  const topic = schedulerTopicName(region);
  return authorizedJson(
      `https://pubsub.googleapis.com/v1/projects/${projectId}` +
      `/topics/${topic}:publish`,
      {method: "POST", body: {messages: [{data: "e30="}]}},
  );
}

async function waitForRepairRun(projectId, previousUpdatedAt) {
  const deadline = Date.now() + RUN_TIMEOUT_MS;
  while (Date.now() < deadline) {
    await new Promise((resolve) => {
      setTimeout(resolve, POLL_INTERVAL_MS);
    });
    const state = await readRepairState(projectId);
    if (updatedAtValue(state) && updatedAtValue(state) !== previousUpdatedAt) {
      return state;
    }
  }
  throw new Error("Timed out waiting for projection repair function");
}

async function runBackfill({
  projectId = DEFAULT_PROJECT_ID,
  region = DEFAULT_REGION,
  maxRuns = DEFAULT_MAX_RUNS,
  resetState = resetRepairState,
  publish = publishRepairRun,
  wait = waitForRepairRun,
} = {}) {
  // A deployment must start from the beginning even when an older repair
  // stopped mid-pass. The new pass id also prevents an in-flight old worker
  // from committing stale cursors after this reset.
  let state = await resetState(projectId);
  for (let run = 1; run <= maxRuns; run += 1) {
    const previousUpdatedAt = updatedAtValue(state);
    await publish(projectId, region);
    state = await wait(projectId, previousUpdatedAt);
    if (backfillPassComplete(state)) {
      return {runs: run};
    }
  }
  throw new Error(`Backfill did not complete after ${maxRuns} runs`);
}

async function main() {
  const projectId = process.argv[2] || DEFAULT_PROJECT_ID;
  const result = await runBackfill({projectId});
  console.log(`Event projection backfill complete (runs=${result.runs})`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {
  backfillPassComplete,
  parseFirebaseJson,
  resetRepairState,
  runBackfill,
  schedulerTopicName,
  updatedAtValue,
};
