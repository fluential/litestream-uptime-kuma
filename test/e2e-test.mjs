#!/usr/bin/env node

/**
 * End-to-end test for Litestream + Uptime Kuma.
 *
 * Tests: admin setup via socket.io, login, add HTTP monitor,
 * wait for heartbeat, verify Litestream replication to S3.
 *
 * Requires: socket.io-client (installed as part of Uptime Kuma deps
 * in the container, or install locally: npm i socket.io-client)
 *
 * Usage: node test/e2e-test.mjs [--kuma-url URL] [--s3-endpoint URL]
 */

import { io } from "socket.io-client";
import { execSync } from "child_process";

const KUMA_URL = process.env.KUMA_URL || "http://localhost:3001";
const S3_ENDPOINT = process.env.S3_ENDPOINT || "http://localhost:9000";
const S3_BUCKET = process.env.S3_BUCKET || "uptime-kuma";
const S3_ACCESS_KEY = process.env.S3_ACCESS_KEY || "minioadmin";
const S3_SECRET_KEY = process.env.S3_SECRET_KEY || "minioadmin123";

const ADMIN_USER = "admin";
const ADMIN_PASS = "TestPass123!";
const MONITOR_URL = "https://dns.google";
const MONITOR_NAME = "E2E Test - Google DNS";

let exitCode = 0;
const results = [];

function log(msg) {
  console.log(`[e2e] ${msg}`);
}

function pass(name) {
  results.push({ name, status: "PASS" });
  log(`PASS: ${name}`);
}

function fail(name, err) {
  results.push({ name, status: "FAIL", error: err });
  log(`FAIL: ${name} — ${err}`);
  exitCode = 1;
}

function socketEmit(socket, event, ...args) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(`Timeout: ${event}`)), 15000);
    socket.emit(event, ...args, (response) => {
      clearTimeout(timeout);
      resolve(response);
    });
  });
}

function waitForEvent(socket, event, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(`Timeout waiting for: ${event}`)), timeoutMs);
    socket.once(event, (data) => {
      clearTimeout(timeout);
      resolve(data);
    });
  });
}

async function waitForKuma(maxWaitSec = 120) {
  log(`Waiting for Kuma at ${KUMA_URL} ...`);
  const start = Date.now();
  while (Date.now() - start < maxWaitSec * 1000) {
    try {
      const res = await fetch(`${KUMA_URL}/api/entry-page`);
      if (res.ok) {
        pass("Kuma is reachable");
        return;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 2000));
  }
  fail("Kuma is reachable", `Not responding after ${maxWaitSec}s`);
  process.exit(1);
}

async function checkS3HasLTXFiles() {
  try {
    const output = execSync(
      `AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY} AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY} ` +
        `aws --endpoint-url ${S3_ENDPOINT} --region us-east-1 ` +
        `s3 ls s3://${S3_BUCKET}/ --recursive 2>&1`,
      { encoding: "utf-8" }
    );
    const ltxFiles = output.split("\n").filter((l) => l.includes(".ltx"));
    if (ltxFiles.length > 0) {
      pass(`S3 has ${ltxFiles.length} LTX files`);
      for (const f of ltxFiles.slice(0, 5)) {
        log(`  ${f.trim()}`);
      }
    } else {
      fail("S3 has LTX files", "No .ltx files found in bucket");
    }
  } catch (err) {
    fail("S3 has LTX files", err.message);
  }
}

async function run() {
  // 1. Wait for Kuma
  await waitForKuma();

  // 2. Connect socket.io
  log("Connecting to Kuma via socket.io...");
  const socket = io(KUMA_URL, {
    transports: ["websocket"],
    reconnection: false,
  });

  await new Promise((resolve, reject) => {
    socket.on("connect", resolve);
    socket.on("connect_error", (err) => reject(new Error(`Socket connect failed: ${err.message}`)));
    setTimeout(() => reject(new Error("Socket connect timeout")), 10000);
  });
  pass("Socket.io connected");

  try {
    // 3. Check if setup is needed
    const needSetup = await socketEmit(socket, "needSetup");
    log(`needSetup: ${needSetup}`);

    if (needSetup) {
      // 4. Create admin account
      const setupRes = await socketEmit(socket, "setup", ADMIN_USER, ADMIN_PASS);
      if (setupRes.ok) {
        pass("Admin account created");
      } else {
        fail("Admin account created", setupRes.msg);
        return;
      }
    } else {
      pass("Admin account created (already exists)");
    }

    // 5. Login
    const loginRes = await socketEmit(socket, "login", {
      username: ADMIN_USER,
      password: ADMIN_PASS,
    });
    if (loginRes.ok) {
      pass("Login successful");
    } else {
      fail("Login successful", loginRes.msg);
      return;
    }

    // 6. Wait for initial monitorList push
    const monitorListPromise = waitForEvent(socket, "monitorList", 10000).catch(() => ({}));
    const initialList = await monitorListPromise;
    const existingCount = Object.keys(initialList).length;
    log(`Existing monitors: ${existingCount}`);

    // 7. Add a test monitor
    const addRes = await socketEmit(socket, "add", {
      type: "http",
      name: MONITOR_NAME,
      url: MONITOR_URL,
      method: "GET",
      interval: 30,
      retryInterval: 30,
      resendInterval: 0,
      maxretries: 0,
      notificationIDList: [],
      accepted_statuscodes: ["200-299"],
      conditions: "[]",
      active: true,
    });
    if (addRes.ok) {
      pass(`Monitor added (ID: ${addRes.monitorID})`);
    } else {
      fail("Monitor added", addRes.msg);
      return;
    }

    // 8. Wait for first heartbeat
    log("Waiting for first heartbeat...");
    const heartbeat = await waitForEvent(socket, "heartbeat", 60000);
    if (heartbeat && heartbeat.status === 1) {
      pass(`Heartbeat received — status UP, ping ${heartbeat.ping}ms`);
    } else if (heartbeat) {
      fail("Heartbeat received", `Unexpected status: ${heartbeat.status}`);
    }

    // 9. Wait for sync interval to pass, then check S3
    log("Waiting 10s for Litestream sync...");
    await new Promise((r) => setTimeout(r, 10000));
    await checkS3HasLTXFiles();
  } finally {
    socket.disconnect();
  }

  // Print summary
  console.log("\n" + "=".repeat(50));
  console.log("E2E TEST RESULTS");
  console.log("=".repeat(50));
  for (const r of results) {
    const icon = r.status === "PASS" ? "OK" : "XX";
    console.log(`  [${icon}] ${r.name}${r.error ? ` — ${r.error}` : ""}`);
  }
  const passed = results.filter((r) => r.status === "PASS").length;
  console.log(`\n${passed}/${results.length} passed`);
  console.log("=".repeat(50));

  process.exit(exitCode);
}

run().catch((err) => {
  console.error(`[e2e] Fatal error: ${err.message}`);
  process.exit(1);
});
