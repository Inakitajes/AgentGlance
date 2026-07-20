// Regression tests for Sources/AgentGlanceCore/Resources/opencode/agentglance.js.
// Run with: node Tests/OpenCodePlugin/agentglance_test.mjs
//
// There is no JS runner wired into the Swift build (Package.swift can't
// execute Node) — this exercises the plugin through the exact public
// interface OpenCode itself calls (`AgentGlancePlugin({client, directory})`
// then `.event({event})`), so it stays honest about real usage instead of
// reaching into internals.
import assert from "node:assert/strict";
import { copyFile, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const pluginPath = join(
  import.meta.dirname,
  "../../Sources/AgentGlanceCore/Resources/opencode/agentglance.js",
);

async function withPlugin(run) {
  const stateDirectory = await mkdtemp(join(tmpdir(), "agentglance-test-"));
  process.env.AGENTGLANCE_HOME = stateDirectory;
  try {
    // The resource ships as plain .js with no nearby package.json, so
    // Node's loader treats it as CommonJS despite its ESM syntax — OpenCode's
    // own loader isn't so strict. Import a fresh .mjs copy per call: forces
    // ESM interpretation and, since the module keeps session state in
    // module-level Maps, guarantees a clean instance instead of a cached one.
    const moduleCopy = join(stateDirectory, "agentglance.mjs");
    await copyFile(pluginPath, moduleCopy);
    const { AgentGlancePlugin } = await import(pathToFileURL(moduleCopy).href);
    const fakeClient = {
      session: { get: async () => ({ data: { parentID: undefined } }) },
      app: { log: async () => {} },
    };
    const plugin = await AgentGlancePlugin({ client: fakeClient, directory: "/tmp/project" });
    await run(plugin, stateDirectory);
  } finally {
    delete process.env.AGENTGLANCE_HOME;
    await rm(stateDirectory, { recursive: true, force: true });
  }
}

async function readState(agentGlanceHome, sessionID) {
  const safeID = Buffer.from(sessionID, "utf8").toString("base64url");
  const contents = await readFile(join(agentGlanceHome, "state", `opencode-${safeID}.json`), "utf8");
  return JSON.parse(contents);
}

async function test(name, run) {
  try {
    await run();
    console.log(`PASS: ${name}`);
  } catch (error) {
    console.log(`FAIL: ${name}`);
    console.error(error);
    process.exitCode = 1;
  }
}

await test("root session starts working and turns idle on session.status", async () => {
  await withPlugin(async (plugin, stateDirectory) => {
    const sessionID = "ses_test1";
    await plugin.event({ event: { type: "session.created", properties: { info: { id: sessionID, directory: "/tmp/project" } } } });
    await plugin.event({ event: { type: "session.status", properties: { sessionID, status: { type: "busy" } } } });
    await plugin.event({ event: { type: "session.status", properties: { sessionID, status: { type: "idle" } } } });
    const state = await readState(stateDirectory, sessionID);
    assert.equal(state.status, "idle");
  });
});

await test("a trailing message.updated after session.status idle must not revert to working", async () => {
  // Reproduces the 2026-07-20 bug: OpenCode can emit a final message.updated
  // (usage/cost finalization) after session.status has already gone idle.
  // The old transitions table mapped every message.updated to "working"
  // unconditionally, permanently reverting an idle session with no further
  // event ever arriving to correct it — the notch spinner never stopped.
  await withPlugin(async (plugin, stateDirectory) => {
    const sessionID = "ses_test2";
    await plugin.event({ event: { type: "session.created", properties: { info: { id: sessionID, directory: "/tmp/project" } } } });
    await plugin.event({ event: { type: "session.status", properties: { sessionID, status: { type: "busy" } } } });
    await plugin.event({ event: { type: "message.updated", properties: { sessionID } } });
    await plugin.event({ event: { type: "session.status", properties: { sessionID, status: { type: "idle" } } } });
    await plugin.event({ event: { type: "message.updated", properties: { sessionID } } });
    const state = await readState(stateDirectory, sessionID);
    assert.equal(state.status, "idle");
  });
});

await test("permission.asked still raises needs_attention and survives busy noise", async () => {
  await withPlugin(async (plugin, stateDirectory) => {
    const sessionID = "ses_test3";
    await plugin.event({ event: { type: "session.created", properties: { info: { id: sessionID, directory: "/tmp/project" } } } });
    await plugin.event({ event: { type: "permission.asked", properties: { sessionID, permissionID: "p1" } } });
    await plugin.event({ event: { type: "session.status", properties: { sessionID, status: { type: "busy" } } } });
    const state = await readState(stateDirectory, sessionID);
    assert.equal(state.status, "needs_attention");
  });
});

if (process.exitCode) {
  process.exit(process.exitCode);
}
