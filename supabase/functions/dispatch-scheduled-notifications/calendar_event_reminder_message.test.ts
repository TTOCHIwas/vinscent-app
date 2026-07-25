import assert from 'node:assert/strict';
import test from 'node:test';

import { buildCalendarEventReminderBody } from './calendar_event_reminder_message.ts';

test('formats same-day calendar reminders', () => {
  assert.equal(
    buildCalendarEventReminderBody('첫 여행', 0),
    '오늘은 첫 여행 일정이 있어',
  );
});

test('formats future calendar reminders by offset', () => {
  assert.equal(
    buildCalendarEventReminderBody('첫 여행', 1),
    '내일은 첫 여행 일정이 있어',
  );
  assert.equal(
    buildCalendarEventReminderBody('첫 여행', 3),
    '3일 뒤에는 첫 여행 일정이 있어',
  );
  assert.equal(
    buildCalendarEventReminderBody('첫 여행', 7),
    '7일 뒤에는 첫 여행 일정이 있어',
  );
});
