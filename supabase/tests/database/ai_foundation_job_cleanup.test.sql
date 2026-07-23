begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

insert into auth.users (
  id,
  aud,
  role,
  email,
  created_at,
  updated_at
)
values
  (
    '14000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-cleanup-user-a@example.test',
    now(),
    now()
  ),
  (
    '14000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-cleanup-user-b@example.test',
    now(),
    now()
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  status,
  connected_at,
  character_setup_status
)
values (
  '24000000-0000-0000-0000-000000000001',
  'AICLEAN1',
  '14000000-0000-0000-0000-000000000001',
  '14000000-0000-0000-0000-000000000002',
  current_date - 30,
  'active',
  now(),
  'default'
);

insert into public.ai_user_consents (
  couple_id,
  user_id,
  status,
  policy_version,
  granted_at,
  revoked_at
)
values
  (
    '24000000-0000-0000-0000-000000000001',
    '14000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '24000000-0000-0000-0000-000000000001',
    '14000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    now(),
    null
  );

insert into public.ai_feature_entitlements (
  couple_id,
  feature_key,
  source
)
values (
  '24000000-0000-0000-0000-000000000001',
  'focused_questions',
  'in_app_unlock'
);

insert into public.ai_focused_questions (
  couple_id,
  question_id,
  status
)
select
  '24000000-0000-0000-0000-000000000001',
  q.id,
  case
    when q.curriculum_position < 24 then 'completed'
    else 'answered_by_one'
  end
from public.questions as q
where q.curriculum_version = 1
  and q.is_active;

insert into public.ai_focused_question_answers (
  focused_question_id,
  user_id,
  answer_text
)
select
  aifq.id,
  answer_users.user_id,
  'Cleanup answer ' || q.curriculum_position::text
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
cross join lateral (
  select '14000000-0000-0000-0000-000000000001'::uuid as user_id

  union all

  select '14000000-0000-0000-0000-000000000002'::uuid
  where q.curriculum_position < 24
) as answer_users
where aifq.couple_id = '24000000-0000-0000-0000-000000000001';

insert into public.ai_processing_jobs (
  id,
  couple_id,
  focused_question_id,
  job_type,
  deduplication_key
)
select
  '34000000-0000-0000-0000-000000000001',
  aifq.couple_id,
  aifq.id,
  'select_curated_question',
  'cleanup:stale-before-completion'
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
where aifq.couple_id = '24000000-0000-0000-0000-000000000001'
  and q.curriculum_position = 23;

insert into public.ai_runs (
  id,
  couple_id,
  focused_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  safety_status,
  completed_at
)
select
  '44000000-0000-0000-0000-000000000001',
  aifq.couple_id,
  aifq.id,
  'select_curated_question',
  'google',
  'gemini-test',
  'question-ranking-v2',
  'succeeded',
  'passed',
  now()
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
where aifq.couple_id = '24000000-0000-0000-0000-000000000001'
  and q.curriculum_position = 23;

insert into public.ai_question_recommendations (
  id,
  couple_id,
  question_id,
  source_run_id,
  reason
)
select
  '54000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000001',
  q.id,
  '44000000-0000-0000-0000-000000000001',
  'Last fixed question candidate'
from public.questions as q
where q.curriculum_version = 1
  and q.curriculum_position = 24;

select set_config(
  'request.jwt.claim.sub',
  '14000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select lives_ok(
  $$
    select public.submit_ai_focused_question_answer(
      (
        public.get_ai_focused_question_flow()
          ->'question'->>'question_id'
      )::uuid,
      'Final cleanup answer'
    )
  $$,
  'the second member can complete the final foundation question'
);

reset role;

select ok(
  private.is_ai_foundation_complete(
    '24000000-0000-0000-0000-000000000001'
  ),
  'the final answer completes the foundation'
);
select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.id = '34000000-0000-0000-0000-000000000001'
  ),
  'cancelled',
  'foundation completion cancels an obsolete fixed-question job'
);
select is(
  (
    select aipj.last_error
    from public.ai_processing_jobs as aipj
    where aipj.id = '34000000-0000-0000-0000-000000000001'
  ),
  'ai_foundation_completed',
  'the cancelled job records its lifecycle reason'
);
select is(
  (
    select aiqr.status
    from public.ai_question_recommendations as aiqr
    where aiqr.id = '54000000-0000-0000-0000-000000000001'
  ),
  'expired',
  'foundation completion expires unused fixed-question recommendations'
);
select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '24000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'select_curated_question'
      and aipj.status = 'pending'
  ),
  0::bigint,
  'no fixed-question job remains pending after completion'
);
select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '24000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'generate_general_question'
      and aipj.status = 'pending'
  ),
  1::bigint,
  'completion queues a general AI question'
);
select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '24000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'extract_memories'
      and aipj.status = 'pending'
  ),
  1::bigint,
  'completion preserves the final memory extraction job'
);

insert into public.ai_processing_jobs (
  id,
  couple_id,
  focused_question_id,
  job_type,
  deduplication_key
)
select
  '34000000-0000-0000-0000-000000000002',
  aifq.couple_id,
  aifq.id,
  'select_curated_question',
  'cleanup:stale-before-claim'
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
where aifq.couple_id = '24000000-0000-0000-0000-000000000001'
  and q.curriculum_position = 24;

create temporary table cleanup_claimed_jobs
on commit drop
as
select *
from public.claim_ai_processing_jobs('cleanup-test-worker', 5);

select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.id = '34000000-0000-0000-0000-000000000002'
  ),
  'cancelled',
  'the claim boundary cancels a stale fixed-question job'
);
select is(
  (
    select count(*)
    from cleanup_claimed_jobs as claimed
    where claimed.job_type = 'select_curated_question'
  ),
  0::bigint,
  'the worker never claims fixed-question work for a complete foundation'
);

select * from finish();
rollback;
