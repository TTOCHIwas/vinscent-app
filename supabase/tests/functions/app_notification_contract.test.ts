import assert from 'node:assert/strict';
import test from 'node:test';

import {
  notificationBodyFor,
  notificationTypeFor,
  preferenceColumnFor,
  routeFor,
} from '../../functions/send-app-notification/notification_contract.ts';

const asynchronousAiEvents = [
  'ai_direct_answer_ready',
  'ai_direct_answer_failed',
  'ai_focused_partner_waiting',
] as const;

test('routes asynchronous AI updates through the shared AI notification path', () => {
  for (const eventType of asynchronousAiEvents) {
    assert.equal(notificationTypeFor(eventType), 'ai_update');
    assert.equal(preferenceColumnFor(eventType), 'ai_updates_enabled');
    assert.equal(routeFor(eventType, null), '/ai');
    assert.notEqual(notificationBodyFor(eventType).trim(), '');
  }
});

test('keeps direct question notification bodies private', () => {
  assert.equal(
    notificationBodyFor('ai_direct_answer_ready'),
    '물어본 질문에 답을 준비했어',
  );
  assert.equal(
    notificationBodyFor('ai_direct_answer_failed'),
    '이번에는 답을 준비하지 못했어... 다시 물어봐 줘',
  );
});

test('keeps dated feedback navigation unchanged', () => {
  assert.equal(
    routeFor('ai_feedback_ready', '2026-07-25'),
    '/home/question?date=2026-07-25',
  );
});

test('routes memory review notifications to the memory screen', () => {
  assert.equal(routeFor('ai_memory_review_ready', null), '/ai/memories');
});
