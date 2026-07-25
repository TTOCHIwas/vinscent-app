export function buildCalendarEventReminderBody(
  title: string,
  offsetDays: number,
) {
  if (offsetDays === 0) {
    return `오늘은 ${title} 일정이 있어`;
  }

  if (offsetDays === 1) {
    return `내일은 ${title} 일정이 있어`;
  }

  return `${offsetDays}일 뒤에는 ${title} 일정이 있어`;
}
