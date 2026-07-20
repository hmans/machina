#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../../..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function fail(message) {
  console.error(`architecture inventory error: ${message}`);
  process.exitCode = 1;
}

function markedSection(document, marker) {
  const start = `<!-- inventory:${marker}:start -->`;
  const end = `<!-- inventory:${marker}:end -->`;
  const startIndex = document.indexOf(start);
  const endIndex = document.indexOf(end);
  if (startIndex < 0 || endIndex < 0 || endIndex <= startIndex) {
    fail(`missing or invalid ${marker} markers`);
    return "";
  }
  return document.slice(startIndex + start.length, endIndex);
}

function tableRows(section) {
  const rows = [];
  for (const line of section.split("\n")) {
    if (!line.startsWith("| `")) continue;
    const columns = line
      .split("|")
      .slice(1, -1)
      .map((column) => column.trim());
    rows.push(columns);
  }
  return rows;
}

function unquoteCode(value) {
  const match = value.match(/^`([^`]+)`$/);
  return match ? match[1] : value;
}

function compareExact(label, sourceValues, documentValues) {
  if (sourceValues.length !== documentValues.length) {
    fail(`${label} count differs: source=${sourceValues.length}, docs=${documentValues.length}`);
  }
  const count = Math.max(sourceValues.length, documentValues.length);
  for (let index = 0; index < count; index += 1) {
    if (sourceValues[index] !== documentValues[index]) {
      fail(
        `${label} differs at index ${index}: source=${JSON.stringify(sourceValues[index])}, docs=${JSON.stringify(documentValues[index])}`,
      );
    }
  }
}

function compareSet(label, sourceValues, documentValues) {
  compareExact(label, [...sourceValues].sort(), [...documentValues].sort());
}

const requiredPages = [
  "systems.md",
  "components.md",
  "state-ownership.md",
  "data-flows.md",
  "source-map.md",
];
const index = read("docs/architecture/INDEX.md");
for (const page of requiredPages) {
  const pagePath = path.join(root, "docs/architecture", page);
  if (!fs.existsSync(pagePath)) {
    fail(`missing docs/architecture/${page}`);
    continue;
  }
  if (!index.includes(`(${page})`)) {
    fail(`docs/architecture/INDEX.md does not link ${page}`);
  }
  if (!/^\*\*Last verified:\*\* \d{4}-\d{2}-\d{2}/m.test(fs.readFileSync(pagePath, "utf8"))) {
    fail(`docs/architecture/${page} is missing a YYYY-MM-DD Last verified date`);
  }
}

function detailEntries(document, marker, requiredLabels) {
  const section = markedSection(document, marker);
  const headings = [...section.matchAll(/^### `([^`]+)`\s*$/gm)];
  for (const [index, match] of headings.entries()) {
    const bodyStart = match.index + match[0].length;
    const bodyEnd = index + 1 < headings.length ? headings[index + 1].index : section.length;
    const body = section.slice(bodyStart, bodyEnd);
    for (const label of requiredLabels) {
      if (!body.includes(`- **${label}:**`)) {
        fail(`${match[1]} ${marker} entry is missing ${label}`);
      }
    }
  }
  return headings.map((match) => match[1]);
}

const runtimeSource = read("src/scrapbot/scrapbot.odin");
const systemFunctionStart = runtimeSource.indexOf("engine_system_profile_name :: proc");
const systemFunctionEnd = runtimeSource.indexOf("Native_Work_Context :: struct", systemFunctionStart);
if (systemFunctionStart < 0 || systemFunctionEnd < 0) {
  fail("could not locate engine_system_profile_name source boundary");
}
const systemSource = runtimeSource.slice(systemFunctionStart, systemFunctionEnd);
const sourceSystems = [...systemSource.matchAll(/return "([^"]+)"/g)].map((match) => match[1]);
const systemRows = tableRows(markedSection(read("docs/architecture/systems.md"), "engine-systems"));
const documentedSystems = systemRows.map((row) => unquoteCode(row[0]));
compareExact("engine systems", sourceSystems, documentedSystems);
const detailedSystems = detailEntries(read("docs/architecture/systems.md"), "engine-system-details", [
  "Phase/order",
  "Inputs",
  "Outputs",
  "Stable-frame behavior",
  "Boundary",
  "Source/tests",
]);
compareSet("engine system details", sourceSystems, detailedSystems);

const registrySource = read("src/scrapbot/component/registry.odin");
const registryFunctionStart = registrySource.indexOf("init_registry :: proc");
const registryFunctionEnd = registrySource.indexOf("register_engine_component :: proc", registryFunctionStart);
if (registryFunctionStart < 0 || registryFunctionEnd < 0) {
  fail("could not locate init_registry source boundary");
}
const registryBootstrap = registrySource.slice(registryFunctionStart, registryFunctionEnd);
const sourceComponents = [
  ...registryBootstrap.matchAll(/register_engine_component\(\s*registry,\s*"([^"]+)"/g),
].map((match) => match[1]);
const componentRows = tableRows(
  markedSection(read("docs/architecture/components.md"), "engine-components"),
);
const documentedComponents = componentRows.map((row) => unquoteCode(row[0]));
compareExact("engine components", sourceComponents, documentedComponents);
const detailedComponents = detailEntries(
  read("docs/architecture/components.md"),
  "engine-component-details",
  ["Contract", "Storage/lifecycle", "Producers", "Consumers", "Invalidation", "Surfaces", "Source/tests"],
);
compareSet("engine component details", sourceComponents, detailedComponents);

const publicComponentRows = tableRows(
  markedSection(
    read("docs-website/src/content/docs/reference/components.md"),
    "public-engine-components",
  ),
);
const sourcePublicComponents = sourceComponents.filter(
  (name) => !name.startsWith("scrapbot.internal."),
);
const documentedPublicComponents = publicComponentRows.map((row) => unquoteCode(row[0]));
compareSet("public engine components", sourcePublicComponents, documentedPublicComponents);

const storageFunctionStart = registrySource.indexOf("engine_component_storage :: proc");
const storageFunctionEnd = registrySource.indexOf("register_definition :: proc", storageFunctionStart);
if (storageFunctionStart < 0 || storageFunctionEnd < 0) {
  fail("could not locate engine_component_storage source boundary");
}
const storageSource = registrySource.slice(storageFunctionStart, storageFunctionEnd);
for (const row of componentRows) {
  const name = unquoteCode(row[0]);
  const documentedLifecycle = row[2];
  const documentedAvailability = row[3];
  const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const lifecycleMatch = storageSource.match(
    new RegExp(`case "${escapedName}":[\\s\\S]*?return \\.[A-Za-z_]+, \\.([A-Za-z_]+)`),
  );
  const sourceLifecycle = lifecycleMatch?.[1] ?? "Derived";
  if (documentedLifecycle !== sourceLifecycle) {
    fail(`${name} lifecycle differs: source=${sourceLifecycle}, docs=${documentedLifecycle}`);
  }
  const expectedAvailability = name.startsWith("scrapbot.internal.")
    ? "No"
    : sourceLifecycle === "Derived"
      ? "Read-only"
      : "Yes";
  if (documentedAvailability !== expectedAvailability) {
    fail(
      `${name} user availability differs: expected=${expectedAvailability}, docs=${documentedAvailability}`,
    );
  }
}

if (process.exitCode) process.exit(process.exitCode);
console.log(
  `architecture inventory is current: ${sourceSystems.length} engine systems, ${sourceComponents.length} engine components, ${requiredPages.length} supporting maps`,
);
