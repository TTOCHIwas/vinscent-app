# Story Loop Question Answer Write Boundary Design

## Purpose

Move question-answer submission from the legacy daily-question-first path to
the daily story loop that already owns the current day's question.

This design preserves the existing answer text, answer-state response shape,
and read-only behavior for archived couples. An answer can be overwritten only
until both partners have answered; a completed pair of answers is immutable.

## Verified Current Problem

The answer edit screen reads `storyLoopDetailProvider`, but its submit path
still calls `todayAnswerControllerProvider`. That controller first resolves
`todayQuestionControllerProvider`, and the server-side
`submit_today_question_answer(text)` calls
`private.get_or_assign_today_daily_question()`.

As a result, the read aggregate and write aggregate differ. The legacy RPC
can also assign a question when no question-generating story loop exists.

## Locked Write Contract

### App contract

- `QuestionAnswerSubmitController` owns answer submission and read-model
  invalidation.
- Before submitting, it resolves `storyLoopDetailProvider(targetDate)` and
  requires a loaded detail with `canAnswerQuestion == true` and a linked
  question whose answer state is not complete for both partners.
- It sends the linked `daily_question_id` with the answer text.
- After success it invalidates the requested detail, today's detail, today's
  summary, and the month summary for the detail's server-resolved couple date.
- The screen retains local loading, draft, and generic failure presentation;
  it no longer invalidates read providers directly.

### Server contract

- Add `public.submit_story_loop_question_answer(
  expected_daily_question_id uuid,
  answer_text text
  )`.
- The RPC resolves the authenticated user's active couple and the current
  couple date on the server.
- It locks the `(couple_id, couple_date)` answer scope, then locks the current
  `daily_story_loops` row and its uniquely linked `daily_questions` row.
- Submission is allowed only while the linked question has fewer than two
  answers and when the linked question id equals `expected_daily_question_id`.
- Missing loops, waiting-for-card loops, missing linked questions, and stale
  question ids fail with `question_not_ready`.
- The answer upsert remains keyed by `(daily_question_id, user_id)`, allowing
  edits before the partner answers.
- A database trigger rejects inserts and updates once the linked question is
  `completed`, so legacy clients and stale edit screens cannot change either
  answer after both partners have answered.
- The transaction recalculates the answer count and updates both
  `daily_questions.status` and `daily_story_loops.status` to
  `answered_by_one` or `completed`.

### Legacy compatibility

- `public.submit_today_question_answer(text)` remains callable for existing
  authenticated clients, but delegates to the same locked story-loop helper.
- `public.get_today_question_answer_state()` becomes read-only lookup logic.
  It no longer calls `private.get_or_assign_today_daily_question()` and does
  not create a question as a side effect.
- `public.get_or_assign_today_question()` keeps its legacy name and result
  shape, but becomes a read-only lookup for an already-linked current loop
  question. This prevents older clients from bypassing story-card-gated
  question generation.
- Existing answer-state return columns remain unchanged.

## Why the Expected Question Id Is Required

The edit screen can stay open across the couple timezone's midnight. Without
an expected question id, a request opened for yesterday's question could be
saved to today's newly generated question. The id check makes the server
reject that stale request instead of attaching the answer to a different
daily loop.

## Implementation Stages

1. Add RED coverage for the story-loop submit controller and update answer
   repository test doubles to the new submission contract.
   Commit: `test: 스토리 루프 질문 답변 저장 경계 재현 추가`
2. Add the app mutation controller, move the edit screen to it, and remove
   direct screen invalidation.
   Commit: `feat: 질문 답변 저장 caller를 스토리 루프 기준으로 전환`
3. Add the server RPC/helper migration and map `question_not_ready` in the
   repository.
   Commit: `feat: 질문 답변 RPC를 스토리 루프 write 경계로 전환`
4. Remove no-longer-referenced today-question read/write controllers,
   repository, failure type, and their tests.
   Commit: `chore: 질문 답변 legacy today 의존 정리`

## Verification

- Flutter unit and widget tests cover successful submit, rejected submission
  when no writable loop question exists, retry after repository failure, and
  the expected daily-question id passed to the repository.
- After applying the migration, verify the server with one first answer, an
  overwrite before the second answer, one second answer, a rejected overwrite
  after completion, a waiting-for-card loop, and a stale expected question id.
