import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildFcmMessage,
  formatFcmErrorSummary,
  isInvalidFcmTokenError,
  parseFcmErrorSummary,
} from '../../functions/_shared/fcm.ts';

test('builds Android recording sync as a data-only high-priority message', () => {
  const payload = buildFcmMessage('android-token', {
    title: '단짠',
    body: '새 녹음이 도착했어요',
    type: 'recording_activity',
    data: {
      event_type: 'current_recording_updated',
      recording_id: 'recording-id',
    },
    platform: 'android',
    backgroundSync: true,
  });

  assert.equal(payload.message.notification, undefined);
  assert.equal(payload.message.android?.priority, 'HIGH');
  assert.equal(payload.message.data.notification_title, '단짠');
  assert.equal(payload.message.data.notification_body, '새 녹음이 도착했어요');
  assert.equal(payload.message.data.recording_id, 'recording-id');
});

test('keeps an iOS alert while requesting recording background sync', () => {
  const payload = buildFcmMessage('ios-token', {
    title: '단짠',
    body: '새 녹음이 도착했어요',
    type: 'recording_activity',
    data: { event_type: 'current_recording_updated' },
    platform: 'ios',
    backgroundSync: true,
  });

  assert.deepEqual(payload.message.notification, {
    title: '단짠',
    body: '새 녹음이 도착했어요',
  });
  assert.equal(payload.message.apns?.payload.aps['content-available'], 1);
  assert.equal(payload.message.apns?.payload.aps.sound, 'default');
});

test('keeps the existing visible Android notification for ordinary pushes', () => {
  const payload = buildFcmMessage('android-token', {
    title: '단짠',
    body: '새 카드가 도착했어요',
    type: 'partner_story_card_uploaded',
    data: {},
    platform: 'android',
  });

  assert.deepEqual(payload.message.notification, {
    title: '단짠',
    body: '새 카드가 도착했어요',
  });
  assert.equal(
    payload.message.android?.notification?.channel_id,
    'vinscent_notifications',
  );
});

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
