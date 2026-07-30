import assert from 'node:assert/strict';
import {
  mkdtemp,
  readFile,
  rm,
} from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

import {
  writeEvaluationReport,
} from '../eval/cloudflare-evaluation-report.ts';

test('evaluation report writer preserves Korean in valid UTF-8 JSON', async () => {
  const directory = await mkdtemp(
    path.join(process.cwd(), '.tmp-cloudflare-eval-'),
  );
  const outputPath = path.join(directory, 'report.json');
  const report = {
    generatedAt: '2026-07-30T00:00:00.000Z',
    syntheticDataOnly: true,
    report: [
      {
        model: '@cf/meta/llama-3.1-8b-instruct-fast',
        output: '아직 확인된 내용이 없어서 잘 모르겠어',
      },
    ],
  };

  try {
    await writeEvaluationReport(outputPath, report);

    const bytes = await readFile(outputPath);
    assert.equal(bytes[0], '{'.charCodeAt(0));
    assert.deepEqual(
      JSON.parse(bytes.toString('utf8')),
      report,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
