import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
  policyDecisionKeys,
  validatePolicyReleaseState,
  verifyPolicyReleaseReadiness,
} from "../scripts/verify-release-readiness.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const policyWebDirectory = path.resolve(testDirectory, "..");

test("blocks the current policy draft from release builds", () => {
  const errors = verifyPolicyReleaseReadiness(policyWebDirectory);

  assert.equal(policyDecisionKeys.length, 13);
  assert.ok(policyDecisionKeys.includes("ugc_prefilter_provider_and_scope"));
  assert.deepEqual(errors, [
    "Policy release remains draft with 13 unresolved decisions",
  ]);
});

test("accepts a ready release without unresolved decisions or draft markers", () => {
  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: [],
    },
    pageSources: {
      "app/privacy/page.tsx": "final privacy policy",
      "app/terms/page.tsx": "final terms",
    },
  });

  assert.deepEqual(errors, []);
});

test("rejects ready releases that retain unresolved decisions", () => {
  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: ["public_contact_email"],
    },
    pageSources: {},
  });

  assert.deepEqual(errors, [
    "Policy release cannot be ready with unresolved decisions: public_contact_email",
  ]);
});

test("rejects ready pages that still contain draft markers", () => {
  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: [],
    },
    pageSources: {
      "app/privacy/page.tsx": "<PolicyDraftNotice />",
    },
  });

  assert.deepEqual(errors, [
    "app/privacy/page.tsx still contains draft marker: PolicyDraftNotice",
  ]);
});
