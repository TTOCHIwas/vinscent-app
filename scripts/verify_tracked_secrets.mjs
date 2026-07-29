import { spawnSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  inspectTrackedText,
  shouldInspectTrackedText,
  trackedPathIssue,
} from './lib/tracked-secret-guard.mjs';

const repositoryRoot = fileURLToPath(new URL('../', import.meta.url));
const trackedFiles = listTrackedFiles();
const issues = [];
let inspectedTextFileCount = 0;

for (const filePath of trackedFiles) {
  const pathIssue = trackedPathIssue(filePath);
  if (pathIssue != null) {
    issues.push({ filePath, code: pathIssue, line: null });
    continue;
  }
  if (!shouldInspectTrackedText(filePath)) {
    continue;
  }

  const source = await readFile(path.join(repositoryRoot, filePath), 'utf8');
  if (source.includes('\0')) {
    continue;
  }

  inspectedTextFileCount += 1;
  issues.push(...inspectTrackedText(filePath, source));
}

if (issues.length > 0) {
  console.error('Tracked release secrets were detected:');
  for (const issue of issues) {
    const location = issue.line == null
      ? issue.filePath
      : `${issue.filePath}:${issue.line}`;
    console.error(`- ${location} (${issue.code})`);
  }
  process.exitCode = 1;
} else {
  console.log(
    `Tracked secret guard passed `
      + `(${trackedFiles.length} files, ${inspectedTextFileCount} text files)`,
  );
}

function listTrackedFiles() {
  const result = spawnSync('git', ['ls-files', '-z'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error('Unable to enumerate tracked repository files');
  }

  return result.stdout.split('\0').filter(Boolean);
}
