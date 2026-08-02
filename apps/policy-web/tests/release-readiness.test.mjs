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

function readyPolicyPages() {
  return {
    "app/page.tsx": "final entry point",
    "app/privacy/page.tsx": "final privacy policy",
    "app/terms/page.tsx": "final terms",
    "app/safety/page.tsx": "final safety policy",
    "app/account-deletion/page.tsx":
      '<a href="mailto:help@danjjan.kr">계정 삭제 문의</a>',
    "app/support/page.tsx":
      '<a href="mailto:help@danjjan.kr">고객지원 문의</a>',
  };
}

test("blocks the current policy draft from release builds", () => {
  const errors = verifyPolicyReleaseReadiness(policyWebDirectory);

  assert.equal(policyDecisionKeys.length, 11);
  assert.ok(!policyDecisionKeys.includes("ugc_prefilter_provider_and_scope"));
  assert.deepEqual(errors, [
    "Policy release remains draft with 9 unresolved decisions",
  ]);
});

test("accepts a ready release without unresolved decisions or draft markers", () => {
  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: [],
    },
    pageSources: readyPolicyPages(),
  });

  assert.deepEqual(errors, []);
});

test("rejects ready releases that retain unresolved decisions", () => {
  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: ["public_contact_email"],
    },
    pageSources: readyPolicyPages(),
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
      ...readyPolicyPages(),
      "app/privacy/page.tsx": "<PolicyDraftNotice />",
    },
  });

  assert.deepEqual(errors, [
    "app/privacy/page.tsx still contains draft marker: PolicyDraftNotice",
  ]);
});

test("rejects ready releases without the support page", () => {
  const pageSources = readyPolicyPages();
  delete pageSources["app/support/page.tsx"];

  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: [],
    },
    pageSources,
  });

  assert.deepEqual(errors, [
    "Missing required policy page source: app/support/page.tsx",
  ]);
});

test("rejects ready releases without public support contacts", () => {
  const errors = validatePolicyReleaseState({
    state: {
      status: "ready",
      unresolvedDecisions: [],
    },
    pageSources: {
      ...readyPolicyPages(),
      "app/support/page.tsx": "final support page",
    },
  });

  assert.deepEqual(errors, [
    "app/support/page.tsx does not include a non-placeholder public mailto contact",
  ]);
});
