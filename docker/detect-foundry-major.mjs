/**
 * Purpose: Detect the installed Foundry major version from the extracted application files.
 * Input/Output: Accepts the Foundry app directory as argv[2] and prints the detected major version to stdout.
 * Invariants: Only local package metadata is read. No network access or file writes happen here.
 * Debug: Run `node docker/detect-foundry-major.mjs /path/to/foundry/app` and inspect stderr if detection fails.
 */

import fs from "node:fs";
import path from "node:path";

// Why this exists: The Node runtime must match the installed Foundry major version for reliable startup.
function readVersionFromPackageJson(filePath) {
  if (!fs.existsSync(filePath)) return undefined;

  const raw = fs.readFileSync(filePath, "utf8");
  const parsed = JSON.parse(raw);
  if (typeof parsed.version !== "string" || parsed.version.trim() === "") {
    return undefined;
  }

  return parsed.version.trim();
}

function extractMajor(version) {
  const match = /^(\d+)\./.exec(version);
  if (!match) return undefined;
  return Number.parseInt(match[1], 10);
}

const appPath = process.argv[2];
if (!appPath) {
  throw new Error("Usage: node detect-foundry-major.mjs <foundry-app-path>");
}

const candidates = [
  path.join(appPath, "package.json"),
  path.join(appPath, "resources", "app", "package.json"),
];

for (const candidate of candidates) {
  const version = readVersionFromPackageJson(candidate);
  if (!version) continue;

  const major = extractMajor(version);
  if (!major) {
    throw new Error(`Could not extract a major version from '${version}' in ${candidate}.`);
  }

  process.stdout.write(String(major));
  process.exit(0);
}

throw new Error(`Could not find a readable Foundry package.json under ${appPath}.`);
