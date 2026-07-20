"use strict";

const assert = require("assert");

const snapshot = require("./diagnostic_snapshot.js");
const rules = require("./diagnostic_rules.js");
const validator = require("./diagnosis_validator.js");
const provider = require("./ai_provider.js");
const model = require("./ai_debug_model.js");

const aliases = [
  ["YiFPGADiagnosticSnapshot", "OpenFPGADiagnosticSnapshot", snapshot],
  ["YiFPGADiagnosticRules", "OpenFPGADiagnosticRules", rules],
  ["YiFPGADiagnosisValidator", "OpenFPGADiagnosisValidator", validator],
  ["YiFPGAAIProvider", "OpenFPGAAIProvider", provider],
  ["YiFPGAAIDebugModel", "OpenFPGAAIDebugModel", model],
];

for (const [canonical, legacy, exported] of aliases) {
  assert.strictEqual(globalThis[canonical], exported, `${canonical} is not canonical`);
  assert.strictEqual(globalThis[legacy], exported, `${legacy} is not the same object`);
}

console.log("Host naming compatibility: PASS");
