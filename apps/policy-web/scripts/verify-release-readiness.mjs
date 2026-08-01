import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const policyDecisionKeys = Object.freeze([
  "legal_operator_name",
  "public_contact_email",
  "effective_date",
  "minimum_age",
  "weather_provider",
  "diagnostic_retention",
  "safety_report_retention",
  "ugc_prefilter_provider_and_scope",
  "moderation_channel",
  "moderation_sla_and_owner",
  "external_deletion_verification",
  "external_deletion_sla_and_confirmation",
]);

const requiredPolicyPages = Object.freeze([
  "app/page.tsx",
  "app/privacy/page.tsx",
  "app/terms/page.tsx",
  "app/safety/page.tsx",
  "app/account-deletion/page.tsx",
  "app/support/page.tsx",
]);

const draftMarkers = Object.freeze([
  "PolicyDraftNotice",
  "공개 전 검토 중입니다",
  "배포용 최종본이 아닙니다",
]);

const publicContactPattern =
  /mailto:[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;

const placeholderContactPattern =
  /(?:support@)?example\.(?:com|net|org)|example\.test/i;

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function readPolicyPageSources(rootDirectory) {
  return Object.fromEntries(
    requiredPolicyPages.map((relativePath) => [
      relativePath,
      readFileSync(path.join(rootDirectory, relativePath), "utf8"),
    ]),
  );
}

export function validatePolicyReleaseState({ state, pageSources }) {
  const errors = [];
  const knownDecisions = new Set(policyDecisionKeys);

  if (state.status !== "draft" && state.status !== "ready") {
    errors.push(`Unknown policy release status: ${String(state.status)}`);
  }

  if (!Array.isArray(state.unresolvedDecisions)) {
    errors.push("unresolvedDecisions must be an array");
    return errors;
  }

  const uniqueDecisions = new Set(state.unresolvedDecisions);
  if (uniqueDecisions.size !== state.unresolvedDecisions.length) {
    errors.push("unresolvedDecisions contains duplicate entries");
  }

  const unknownDecisions = state.unresolvedDecisions.filter(
    (decision) => !knownDecisions.has(decision),
  );
  if (unknownDecisions.length > 0) {
    errors.push(`Unknown policy decisions: ${unknownDecisions.join(", ")}`);
  }

  if (state.status === "draft") {
    errors.push(
      `Policy release remains draft with ${state.unresolvedDecisions.length} unresolved decisions`,
    );
  }

  if (state.status === "ready" && state.unresolvedDecisions.length > 0) {
    errors.push(
      `Policy release cannot be ready with unresolved decisions: ${state.unresolvedDecisions.join(", ")}`,
    );
  }

  if (state.status === "ready") {
    for (const relativePath of requiredPolicyPages) {
      if (!(relativePath in pageSources)) {
        errors.push(`Missing required policy page source: ${relativePath}`);
      }
    }

    for (const [relativePath, source] of Object.entries(pageSources)) {
      const matchedMarker = draftMarkers.find((marker) =>
        source.includes(marker),
      );
      if (matchedMarker !== undefined) {
        errors.push(
          `${relativePath} still contains draft marker: ${matchedMarker}`,
        );
      }
    }

    for (const relativePath of [
      "app/support/page.tsx",
      "app/account-deletion/page.tsx",
    ]) {
      const source = pageSources[relativePath];
      if (source === undefined) {
        continue;
      }
      if (
        !publicContactPattern.test(source) ||
        placeholderContactPattern.test(source)
      ) {
        errors.push(
          `${relativePath} does not include a non-placeholder public mailto contact`,
        );
      }
    }
  }

  return errors;
}

export function verifyPolicyReleaseReadiness(rootDirectory) {
  const state = readJson(
    path.join(rootDirectory, "policy-release-state.json"),
  );
  const pageSources = readPolicyPageSources(rootDirectory);
  return validatePolicyReleaseState({ state, pageSources });
}

function run() {
  const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
  const rootDirectory = path.resolve(scriptDirectory, "..");
  const errors = verifyPolicyReleaseReadiness(rootDirectory);

  if (errors.length > 0) {
    process.stderr.write(
      `Policy release preflight failed:\n${errors
        .map((error) => `- ${error}`)
        .join("\n")}\n`,
    );
    process.exitCode = 1;
    return;
  }

  process.stdout.write("Policy release preflight passed.\n");
}

const invokedFileUrl =
  process.argv[1] === undefined
    ? undefined
    : pathToFileURL(path.resolve(process.argv[1])).href;

if (invokedFileUrl === import.meta.url) {
  run();
}
