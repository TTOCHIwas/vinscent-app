begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

insert into auth.users (id, aud, role, email)
values
  ('f0270000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'focused-recovery-a@example.test'),
  ('f0270000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'focused-recovery-b@example.test');

insert into public.user_policy_acceptances (user_id, policy_type, policy_version)
values
  ('f0270000-0000-0000-0000-000000000001', 'ugc_safety_policy', 'ugc-safety-v1'),
  ('f0270000-0000-0000-0000-000000000002', 'ugc_safety_policy', 'ugc-safety-v1');

insert into public.couples (
  id, invite_code, user_a_id, user_b_id, relationship_start_date,
  status, connected_at, character_setup_status
)
values (
  'f0270000-0000-0000-0000-000000000003', 'AIFIX027',
  'f0270000-0000-0000-0000-000000000001', 'f0270000-0000-0000-0000-000000000002',
  current_date - 10, 'active', now(), 'default'
);

insert into public.ai_user_consents (couple_id, user_id, status, policy_version, granted_at, revoked_at)
values
  ('f0270000-0000-0000-0000-000000000003', 'f0270000-0000-0000-0000-000000000001', 'granted', 'ai-learning-v1', now(), null),
  ('f0270000-0000-0000-0000-000000000003', 'f0270000-0000-0000-0000-000000000002', 'granted', 'ai-learning-v1', now(), null);

insert into public.ai_feature_entitlements (couple_id, feature_key, source)
values ('f0270000-0000-0000-0000-000000000003', 'focused_questions', 'in_app_unlock');

insert into public.ai_focused_questions (id, couple_id, question_id, status)
select 'f0270000-0000-0000-0000-000000000008', 'f0270000-0000-0000-0000-000000000003',
  q.id, 'answered_by_one'
from public.questions as q
where q.curriculum_version = 1 and q.curriculum_position = 1;

insert into public.ai_runs (
  id, couple_id, focused_question_id, task, provider, model, prompt_version, status, safety_status
)
values
  ('f0270000-0000-0000-0000-000000000004', 'f0270000-0000-0000-0000-000000000003',
    'f0270000-0000-0000-0000-000000000008', 'select_curated_question', 'test', 'test', 'test-v1', 'succeeded', 'passed'),
  ('f0270000-0000-0000-0000-000000000005', 'f0270000-0000-0000-0000-000000000003',
    'f0270000-0000-0000-0000-000000000008', 'generate_general_question', 'test', 'test', 'test-v1', 'succeeded', 'passed');

insert into public.questions (
  id, source, question_key, question_text, personalized_for_couple_id, generated_by_run_id
)
values
  ('f0270000-0000-0000-0000-000000000006', 'ai', 'general_recovery_test_00000006',
    'What made you smile today?', 'f0270000-0000-0000-0000-000000000003',
    'f0270000-0000-0000-0000-000000000005'),
  ('f0270000-0000-0000-0000-000000000007', 'ai', 'general_recovery_test_00000007',
    'What did you enjoy today?', 'f0270000-0000-0000-0000-000000000003',
    'f0270000-0000-0000-0000-000000000005');

select is(
  (select count(*) from public.questions where curriculum_version = 1 and is_active),
  24::bigint,
  'all 24 foundation questions are active'
);

insert into public.ai_question_recommendations (couple_id, question_id, source_run_id, reason, status)
select 'f0270000-0000-0000-0000-000000000003', q.id,
  'f0270000-0000-0000-0000-000000000004', 'Previous fixed recommendation', 'expired'
from public.questions as q
where q.curriculum_version = 1 and q.curriculum_position = 6;

insert into public.ai_question_recommendations (couple_id, question_id, source_run_id, reason, status)
values (
  'f0270000-0000-0000-0000-000000000003', 'f0270000-0000-0000-0000-000000000006',
  'f0270000-0000-0000-0000-000000000005', 'Previous generated recommendation', 'expired'
);

insert into public.ai_question_recommendations (couple_id, question_id, source_run_id, reason)
select 'f0270000-0000-0000-0000-000000000003', q.id,
  'f0270000-0000-0000-0000-000000000004', 'New recommendation'
from public.questions as q
where q.curriculum_version = 1 and q.curriculum_position = 7;

select ok(
  (select is_active from public.questions where curriculum_version = 1 and curriculum_position = 6),
  'recommendation queue cleanup leaves the shared fixed question active'
);
select is(
  (select is_active from public.questions where id = 'f0270000-0000-0000-0000-000000000006'),
  false,
  'recommendation queue cleanup still deactivates the unused generated question'
);

insert into public.ai_question_recommendations (
  couple_id, question_id, source_run_id, reason, status
)
values (
  'f0270000-0000-0000-0000-000000000003', 'f0270000-0000-0000-0000-000000000007',
  'f0270000-0000-0000-0000-000000000005', 'Another expired generated recommendation', 'expired'
);

do $$
begin
  perform private.assign_pending_ai_question_to_story_loop(c, null::public.daily_story_loops)
  from public.couples as c
  where c.id = 'f0270000-0000-0000-0000-000000000003';
end;
$$;

select ok(
  (select is_active from public.questions where curriculum_version = 1 and curriculum_position = 7),
  'daily assignment cleanup leaves the shared fixed question active'
);
select is(
  (select is_active from public.questions where id = 'f0270000-0000-0000-0000-000000000007'),
  false,
  'daily assignment cleanup still deactivates the unused generated question'
);

insert into public.ai_focused_questions (couple_id, question_id, status)
select 'f0270000-0000-0000-0000-000000000003', q.id, 'answered_by_one'
from public.questions as q
where q.curriculum_version = 1 and q.curriculum_position not in (1, 6, 7, 9, 14, 21, 22, 23);

insert into public.ai_focused_question_answers (focused_question_id, user_id, answer_text)
select f.id, 'f0270000-0000-0000-0000-000000000001', 'Existing answer'
from public.ai_focused_questions as f
where f.couple_id = 'f0270000-0000-0000-0000-000000000003';

select set_config('request.jwt.claim.sub', 'f0270000-0000-0000-0000-000000000001', true);
set local role authenticated;

select is(
  public.get_ai_focused_question_flow()->'progress'->>'my_answered_count',
  '17',
  'the existing 17 focused answers remain counted'
);
select is(
  public.get_ai_focused_question_flow()->'question'->>'curriculum_position',
  '6',
  'an account with 17 answers can resume at its first unanswered question'
);
select is(
  public.submit_ai_focused_question_answer(
    (public.get_ai_focused_question_flow()->'question'->>'question_id')::uuid,
    'A new answer'
  )->'progress'->>'my_answered_count',
  '18',
  'submitting a restored question continues normal progress'
);

reset role;
select * from finish();
rollback;
