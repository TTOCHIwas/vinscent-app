import assert from 'node:assert/strict';
import test from 'node:test';

import {
  formatFcmErrorSummary,
  isInvalidFcmTokenError,
  parseFcmErrorSummary,
} from '../../functions/_shared/fcm.ts';

test('classifies an unregistered FCM token as invalid', () => {
  const summary = parseFcmErrorSummary(JSON.stringify({
    error: {
      status: 'NOT_FOUND',
      message: 'Requested entity was not found.',
      details: [{ errorCode: 'UNREGISTERED' }],
    },
  }));

  assert.equal(summary.status, 'NOT_FOUND');
  assert.equal(summary.errorCode, 'UNREGISTERED');
  assert.equal(summary.message, 'Requested entity was not found.');
  assert.equal(isInvalidFcmTokenError(summary), true);
  assert.equal(
    formatFcmErrorSummary(summary),
    'status=NOT_FOUND; errorCode=UNREGISTERED; message=Requested entity was not found.',
  );
});

test('keeps a bounded raw fallback for malformed FCM errors', () => {
  const raw = 'not-json';
  const summary = parseFcmErrorSummary(raw);

  assert.equal(summary.status, null);
  assert.equal(summary.errorCode, null);
  assert.equal(summary.message, null);
  assert.equal(summary.raw, raw);
  assert.equal(isInvalidFcmTokenError(summary), false);
  assert.equal(formatFcmErrorSummary(summary), raw);
});
