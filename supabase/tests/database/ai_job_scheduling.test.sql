begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

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
    '12000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-scheduling-user-a@example.test',
    now(),
    now()
  ),
  (
    '12000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-scheduling-user-b@example.test',
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
  '22000000-0000-0000-0000-000000000001',
  'AIQUEUE1',
  '12000000-0000-0000-0000-000000000001',
  '12000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status,
  question_generated_at,
  story_edit_locked_at
)
values (
  '32000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
  current_date - 1,
  'completed',
  now(),
  now()
);

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status,
  story_loop_id
)
select
  '42000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
  q.id,
  current_date - 1,
  'completed',
  '32000000-0000-0000-0000-000000000001'
from public.questions as q
where q.curriculum_version = 1
  and q.curriculum_position = 1;

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
    '22000000-0000-0000-0000-000000000001',
    '12000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '22000000-0000-0000-0000-000000000001',
    '12000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    now(),
    null
  );

delete from public.ai_processing_jobs
where couple_id = '22000000-0000-0000-0000-000000000001';

insert into public.ai_processing_jobs (
  couple_id,
  daily_question_id,
  job_type,
  deduplication_key,
  available_at,
  created_at
)
values
  (
    '22000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000001',
    'extract_memories',
    'queue-test:extract',
    now() - interval '5 minutes',
    now() - interval '3 minutes'
  ),
  (
    '22000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000001',
    'select_curated_question',
    'queue-test:question',
    now() - interval '5 minutes',
    now() - interval '2 minutes'
  ),
  (
    '22000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000001',
    'generate_feedback',
    'queue-test:feedback',
    now() - interval '5 minutes',
    now() - interval '1 minute'
  );

select results_eq(
  $$
    select claimed.job_type
    from public.claim_ai_processing_jobs('queue-test-worker', 3) as claimed
  $$,
  $$
    values
      ('generate_feedback'::text),
      ('select_curated_question'::text),
      ('extract_memories'::text)
  $$,
  'claim returns user-visible work before background memory extraction'
);

select is(
  (
    select count(*)
    from public.ai_processing_jobs
    where couple_id = '22000000-0000-0000-0000-000000000001'
      and status = 'processing'
  ),
  3::bigint,
  'one worker batch claims all three jobs for a completed question'
);

select * from finish();
rollback;
