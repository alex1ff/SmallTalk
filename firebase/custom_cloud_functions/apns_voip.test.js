const test = require("node:test");
const assert = require("node:assert/strict");
const {EventEmitter} = require("node:events");
const crypto = require("node:crypto");
const http2 = require("node:http2");

function buildSigningKey() {
  const {privateKey} = crypto.generateKeyPairSync("ec", {
    namedCurve: "P-256",
  });
  return privateKey.export({
    type: "pkcs8",
    format: "pem",
  });
}

async function withMockedApnsTransport(run) {
  const originalConnect = http2.connect;
  const originalEnv = {
    APNS_KEY_P8: process.env.APNS_KEY_P8,
    APNS_KEY_ID: process.env.APNS_KEY_ID,
    APNS_TEAM_ID: process.env.APNS_TEAM_ID,
  };
  const client = new EventEmitter();
  const request = new EventEmitter();
  let clientErrorListenerCount = 0;
  let clientDestroyError = null;
  let requestPayload = "";
  let requestCount = 0;
  let closeCount = 0;

  client.request = () => {
    requestCount += 1;
    return request;
  };
  client.close = () => {
    closeCount += 1;
  };
  client.destroy = (error) => {
    clientDestroyError = error;
    client.emit("error", error);
  };
  client.on = function(eventName, listener) {
    if (eventName === "error") {
      clientErrorListenerCount += 1;
    }
    return EventEmitter.prototype.on.call(this, eventName, listener);
  };
  request.setEncoding = () => {};
  request.end = (payload) => {
    requestPayload = payload;
  };
  request.destroy = () => {};

  http2.connect = () => client;
  process.env.APNS_KEY_P8 = buildSigningKey();
  process.env.APNS_KEY_ID = "KEYID12345";
  process.env.APNS_TEAM_ID = "TEAMID12345";
  delete require.cache[require.resolve("./apns_voip")];
  const {sendApnsVoip} = require("./apns_voip");

  try {
    await run({
      client,
      request,
      sendApnsVoip,
      state: {
        get clientDestroyError() {
          return clientDestroyError;
        },
        get clientErrorListenerCount() {
          return clientErrorListenerCount;
        },
        get closeCount() {
          return closeCount;
        },
        get requestPayload() {
          return requestPayload;
        },
        get requestCount() {
          return requestCount;
        },
      },
    });
  } finally {
    http2.connect = originalConnect;
    Object.entries(originalEnv).forEach(([key, value]) => {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    });
    delete require.cache[require.resolve("./apns_voip")];
  }
}

test("sendApnsVoip resolves successful response", async () => {
  await withMockedApnsTransport(async ({request, sendApnsVoip, state}) => {
    const sendPromise = sendApnsVoip({
      deviceToken: "token",
      topic: "com.example.app.voip",
      payload: {type: "incoming_call"},
    });
    request.emit("response", {":status": 200});
    request.emit("data", "ok");
    request.emit("end");

    assert.deepEqual(await sendPromise, {
      statusCode: 200,
      responseData: "ok",
    });
    assert.equal(state.closeCount, 1);
    assert.equal(JSON.parse(state.requestPayload).type, "incoming_call");
  });
});

test("sendApnsVoip rejects APNS error response", async () => {
  await withMockedApnsTransport(async ({request, sendApnsVoip, state}) => {
    const sendPromise = sendApnsVoip({
      deviceToken: "token",
      topic: "com.example.app.voip",
      payload: {type: "incoming_call"},
    });
    request.emit("response", {":status": 410});
    request.emit("data", "{\"reason\":\"Unregistered\"}");
    request.emit("end");

    await assert.rejects(sendPromise, /APNs error 410/);
    assert.equal(state.closeCount, 1);
  });
});

test("sendApnsVoip abort handles client error", async () => {
  await withMockedApnsTransport(async ({sendApnsVoip, state}) => {
    const controller = new AbortController();
    const timeoutError = new Error("push_timeout");
    const sendPromise = sendApnsVoip({
      deviceToken: "token",
      topic: "com.example.app.voip",
      payload: {type: "incoming_call"},
      signal: controller.signal,
    });
    controller.abort(timeoutError);

    await assert.rejects(sendPromise, /push_timeout/);
    assert.equal(state.clientErrorListenerCount, 1);
    assert.equal(state.clientDestroyError, timeoutError);
  });
});

test("sendApnsVoip skips request when signal is already aborted", async () => {
  await withMockedApnsTransport(async ({sendApnsVoip, state}) => {
    const controller = new AbortController();
    const timeoutError = new Error("push_timeout");
    controller.abort(timeoutError);

    await assert.rejects(
      () => sendApnsVoip({
        deviceToken: "token",
        topic: "com.example.app.voip",
        payload: {type: "incoming_call"},
        signal: controller.signal,
      }),
      /push_timeout/,
    );
    assert.equal(state.requestCount, 0);
    assert.equal(state.clientDestroyError, timeoutError);
  });
});
