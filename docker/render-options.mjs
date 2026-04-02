/**
 * Purpose: Create or update Foundry's options.json with the container-managed settings.
 * Input/Output: Reads env vars plus an output path argument, preserves unrelated settings, and writes pretty JSON.
 * Invariants: Only a small, explicit subset of keys is managed here so user-maintained settings survive restarts.
 * Debug: Run `node docker/render-options.mjs /tmp/options.json` with env vars set and inspect the resulting file.
 */

import fs from "node:fs";
import path from "node:path";

// Why this exists: Clear parsing rules make invalid env values fail fast instead of creating broken JSON.
function parseBoolean(name, value) {
  if (value === undefined || value === "") return undefined;

  const normalized = value.toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;

  throw new Error(`${name} must be a boolean-like value. Received '${value}'.`);
}

function parseInteger(name, value) {
  if (value === undefined || value === "") return undefined;
  if (!/^\d+$/.test(value)) {
    throw new Error(`${name} must be an integer. Received '${value}'.`);
  }

  return Number.parseInt(value, 10);
}

function parseString(value) {
  if (value === undefined) return undefined;
  return value;
}

function loadExistingOptions(filePath) {
  if (!fs.existsSync(filePath)) return {};

  const raw = fs.readFileSync(filePath, "utf8").trim();
  if (raw === "") return {};

  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error(`Existing options.json at ${filePath} is invalid JSON. Fix or delete the file and retry. Original error: ${error.message}`);
  }
}

function normalizeRoutePrefix(value) {
  if (value === undefined || value === "") return undefined;
  return value.replace(/^\/+/, "").replace(/\/+$/, "");
}

const outputPath = process.argv[2];
if (!outputPath) {
  throw new Error("Usage: node render-options.mjs <absolute-output-path>");
}

const outputDirectory = path.dirname(outputPath);
fs.mkdirSync(outputDirectory, { recursive: true });

const existingOptions = loadExistingOptions(outputPath);
const managedValues = {
  dataPath: parseString(process.env.FOUNDRY_DATA_PATH),
  port: parseInteger("FOUNDRY_PORT", process.env.FOUNDRY_PORT),
  upnp: parseBoolean("FOUNDRY_UPNP", process.env.FOUNDRY_UPNP),
  proxySSL: parseBoolean("FOUNDRY_PROXY_SSL", process.env.FOUNDRY_PROXY_SSL),
  proxyPort: parseInteger("FOUNDRY_PROXY_PORT", process.env.FOUNDRY_PROXY_PORT),
  hostname: parseString(process.env.FOUNDRY_HOSTNAME),
  localHostname: parseString(process.env.FOUNDRY_LOCAL_HOSTNAME),
  routePrefix: normalizeRoutePrefix(process.env.FOUNDRY_ROUTE_PREFIX),
  sslKey: parseString(process.env.FOUNDRY_SSL_KEY),
  sslCert: parseString(process.env.FOUNDRY_SSL_CERT),
  compressStatic: parseBoolean("FOUNDRY_COMPRESS_STATIC", process.env.FOUNDRY_COMPRESS_STATIC),
};

// Why this exists: Undefined env vars should not erase a user's existing unmanaged settings.
const nextOptions = { ...existingOptions };
for (const [key, value] of Object.entries(managedValues)) {
  if (value !== undefined) {
    nextOptions[key] = value;
  }
}

fs.writeFileSync(outputPath, `${JSON.stringify(nextOptions, null, 2)}\n`, "utf8");
