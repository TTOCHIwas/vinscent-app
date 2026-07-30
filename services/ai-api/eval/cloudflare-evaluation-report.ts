import {
  mkdir,
  writeFile,
} from 'node:fs/promises';
import path from 'node:path';

export function serializeEvaluationReport(report: unknown): string {
  return `${JSON.stringify(report, null, 2)}\n`;
}

export async function writeEvaluationReport(
  outputPath: string,
  report: unknown,
): Promise<void> {
  const normalizedPath = outputPath.trim();
  if (normalizedPath.length === 0) {
    throw new TypeError('Cloudflare evaluation output path is required');
  }

  await mkdir(path.dirname(normalizedPath), { recursive: true });
  await writeFile(
    normalizedPath,
    serializeEvaluationReport(report),
    'utf8',
  );
}
