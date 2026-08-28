begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(28);

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
    '13000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-generated-user-a@example.test',
    now(),
    now()
  ),
  (
    '13000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-generated-user-b@example.test',
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
  '23000000-0000-0000-0000-000000000001',
  'AIGEN001',
  '13000000-0000-0000-0000-000000000001',
  '13000000-0000-0000-0000-000000000002',
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
    '23000000-0000-0000-0000-000000000001',
    '13000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '23000000-0000-0000-0000-000000000001',
    '13000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    now(),
    null
  );

insert into public.ai_focused_questions (
  couple_id,
  question_id,
  status
)
select
  '23000000-0000-0000-0000-000000000001',
  q.id,
  'completed'
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
  users.user_id,
  'Foundation answer ' || q.curriculum_position::text
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
cross join (
  values
    ('13000000-0000-0000-0000-000000000001'::uuid),
    ('13000000-0000-0000-0000-000000000002'::uuid)
) as users(user_id)
where aifq.couple_id = '23000000-0000-0000-0000-000000000001';

select ok(
  private.is_ai_foundation_complete(
    '23000000-0000-0000-0000-000000000001'
  ),
  'all 24 completed focused questions complete the foundation'
);
select ok(
  to_regprocedure(
    'public.get_ai_general_question_job_context(uuid)'
  ) is not null,
  'the privacy-safe general question context RPC exists'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '33000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001',
  current_date,
  'waiting_partner_card'
);

insert into public.story_loop_cards (
  id,
  story_loop_id,
  couple_id,
  couple_date,
  author_user_id,
  preview_path,
  scene_data_path,
  has_drawing
)
values
  (
    '43000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000001',
    '23000000-0000-0000-0000-000000000001',
    current_date,
    '13000000-0000-0000-0000-000000000001',
    '23000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/13000000-0000-0000-0000-000000000001/preview.png',
    '23000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/13000000-0000-0000-0000-000000000001/scene.json',
    true
  ),
  (
    '43000000-0000-0000-0000-000000000002',
    '33000000-0000-0000-0000-000000000001',
    '23000000-0000-0000-0000-000000000001',
    current_date,
    '13000000-0000-0000-0000-000000000002',
    '23000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/13000000-0000-0000-0000-000000000002/preview.png',
    '23000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/13000000-0000-0000-0000-000000000002/scene.json',
    true
  );

create temporary table generated_pair_result
on commit drop
as
select *
from private.finalize_story_loop_after_card_pair(
  (
    select c
    from public.couples as c
    where c.id = '23000000-0000-0000-0000-000000000001'
  ),
  (
    select dsl
    from public.daily_story_loops as dsl
    where dsl.id = '33000000-0000-0000-0000-000000000001'
  ),
  '13000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000002'
);

select is(
  (select story_loop_status from generated_pair_result),
  'question_preparing',
  'a complete foundation waits for an AI question when the pool is empty'
);
select is(
  (select question_generated from generated_pair_result),
  false,
  'question preparation does not report a generated question'
);
select is(
  (
    select count(*)
    from public.daily_questions as dq
    where dq.story_loop_id = '33000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'no curated fallback question is assigned while AI generation is pending'
);
select ok(
  (
    select dsl.story_edit_locked_at is not null
    from public.daily_story_loops as dsl
    where dsl.id = '33000000-0000-0000-0000-000000000001'
  ),
  'question preparation locks both cards'
);
select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '23000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'generate_general_question'
      and aipj.status = 'pending'
  ),
  1::bigint,
  'an empty pool queues a general question job'
);

update public.ai_processing_jobs
set
  status = 'processing',
  attempts = 1,
  claimed_at = now(),
  claimed_by = 'generated-question-test-worker',
  lease_expires_at = now() + interval '5 minutes'
where couple_id = '23000000-0000-0000-0000-000000000001'
  and job_type = 'generate_general_question'
  and status = 'pending';

create temporary table generated_context
on commit drop
as
select public.get_ai_general_question_job_context(
  (
    select aipj.id
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '23000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'generate_general_question'
      and aipj.status = 'processing'
  )
) as payload;

select ok(
  not ((select payload from generated_context) ? 'answers'),
  'general question context contains no answers key'
);
select ok(
  not ((select payload from generated_context) ? 'confirmed_memories'),
  'general question context contains no memory key'
);
select ok(
  jsonb_array_length(
    (select payload from generated_context)->'recent_questions'
  ) > 0,
  'general question context contains safe question history metadata'
);
select ok(
  (
    select aipj.context_captured_at is not null
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '23000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'generate_general_question'
      and aipj.status = 'processing'
  ),
  'loading general question context records its freshness boundary'
);

create temporary table generated_run
on commit drop
as
select public.start_ai_processing_run(
  (
    select aipj.id
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '23000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'generate_general_question'
      and aipj.status = 'processing'
  ),
  'google',
  'gemini-test',
  'general-question-v1'
) as run_id;

select ok(
  (select run_id from generated_run) is not null,
  'the worker can start a general question run'
);
select is(
  public.succeed_ai_processing_run(
    (select run_id from generated_run),
    jsonb_build_object(
      'question_key', 'general_shared_ritual_ab12cd34',
      'question_text', '요즘 둘만의 작은 습관으로 만들고 싶은 건 뭐야?',
      'category', 'daily_life',
      'mood', 'warm',
      'rationale', 'The recent questions have not covered shared rituals.'
    ),
    40,
    20,
    150
  ),
  true,
  'a valid general question result completes successfully'
);
select is(
  (
    select dsl.status
    from public.daily_story_loops as dsl
    where dsl.id = '33000000-0000-0000-0000-000000000001'
  ),
  'question_generated',
  'the generated question is attached to the waiting card pair'
);
select is(
  (
    select q.source
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.story_loop_id = '33000000-0000-0000-0000-000000000001'
  ),
  'ai',
  'the attached question is AI-generated'
);
select is(
  (
    select q.question_key
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.story_loop_id = '33000000-0000-0000-0000-000000000001'
  ),
  'general_shared_ritual_ab12cd34',
  'the attached question is the generated candidate'
);
select is(
  (
    select count(*)
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.story_loop_id = '33000000-0000-0000-0000-000000000001'
      and q.source = 'curated'
  ),
  0::bigint,
  'the pipeline never falls back to a fixed foundation question'
);
select is(
  (
    select aiqr.status
    from public.ai_question_recommendations as aiqr
    join public.questions as q on q.id = aiqr.question_id
    where q.question_key = 'general_shared_ritual_ab12cd34'
  ),
  'used',
  'the attached recommendation is consumed exactly once'
);
select is(
  (
    select count(*)
    from public.story_loop_notification_events as slne
    where slne.story_loop_id =
      '33000000-0000-0000-0000-000000000001'
      and slne.event_type = 'question_generated'
  ),
  2::bigint,
  'both members receive one question-generated event'
);
select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '23000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'generate_general_question'
    order by aipj.created_at
    limit 1
  ),
  'succeeded',
  'the general question job closes after persistence'
);

insert into public.ai_processing_jobs (
  id,
  couple_id,
  focused_question_id,
  job_type,
  status,
  deduplication_key,
  attempts,
  context_captured_at,
  completed_at
)
select
  '83000000-0000-0000-0000-000000000010',
  '23000000-0000-0000-0000-000000000001',
  aifq.id,
  'generate_general_question',
  'succeeded',
  'stale-assignment:general-question',
  1,
  now(),
  now()
from public.ai_focused_questions as aifq
where aifq.couple_id = '23000000-0000-0000-0000-000000000001'
order by aifq.created_at, aifq.id
limit 1;

insert into public.ai_runs (
  id,
  job_id,
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
  '63000000-0000-0000-0000-000000000010',
  aipj.id,
  aipj.couple_id,
  aipj.focused_question_id,
  'generate_general_question',
  'test',
  'test-model',
  'general-question-v2',
  'succeeded',
  'passed',
  now()
from public.ai_processing_jobs as aipj
where aipj.id = '83000000-0000-0000-0000-000000000010';

insert into public.questions (
  id,
  source,
  question_key,
  question_text,
  category,
  is_active,
  personalized_for_couple_id,
  generated_by_run_id
)
values (
  '68000000-0000-0000-0000-000000000010',
  'ai',
  'general_stale_candidate_ab12cd34',
  '둘이 함께 쉬고 싶은 장소는 어디야?',
  'daily_life',
  true,
  '23000000-0000-0000-0000-000000000001',
  '63000000-0000-0000-0000-000000000010'
);

insert into public.ai_question_recommendations (
  couple_id,
  question_id,
  source_run_id,
  reason
)
values (
  '23000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000010',
  '63000000-0000-0000-0000-000000000010',
  'stale assignment regression test'
);

insert into public.questions (
  id,
  source,
  question_text,
  category,
  is_active
)
values (
  '68000000-0000-0000-0000-000000000011',
  'curated',
  '후보가 만들어진 뒤 새로 노출된 질문은 뭐야?',
  'daily_life',
  true
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values
  (
    '33000000-0000-0000-0000-000000000010',
    '23000000-0000-0000-0000-000000000001',
    current_date - 1,
    'answered_by_one'
  ),
  (
    '33000000-0000-0000-0000-000000000011',
    '23000000-0000-0000-0000-000000000001',
    current_date + 1,
    'question_preparing'
  );

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status,
  story_loop_id,
  created_at,
  updated_at
)
values (
  '39000000-0000-0000-0000-000000000010',
  '23000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000011',
  current_date - 1,
  'answered_by_one',
  '33000000-0000-0000-0000-000000000010',
  now() + interval '1 second',
  now() + interval '1 second'
);

create temporary table stale_assignment
on commit drop
as
select (
  private.assign_pending_ai_question_to_story_loop(
    (
      select c
      from public.couples as c
      where c.id = '23000000-0000-0000-0000-000000000001'
    ),
    (
      select dsl
      from public.daily_story_loops as dsl
      where dsl.id = '33000000-0000-0000-0000-000000000011'
    )
  )
).id as daily_question_id;

select is(
  (select daily_question_id from stale_assignment),
  null::uuid,
  'an automatic candidate is not assigned after newer question exposure'
);
select is(
  (
    select aiqr.status
    from public.ai_question_recommendations as aiqr
    where aiqr.source_run_id = '63000000-0000-0000-0000-000000000010'
  ),
  'expired',
  'the stale automatic candidate is expired during assignment'
);
select is(
  (
    select q.is_active
    from public.questions as q
    where q.id = '68000000-0000-0000-0000-000000000010'
  ),
  false,
  'the stale automatic question is deactivated'
);

insert into public.ai_personalization_states (
  couple_id,
  curriculum_version,
  activated_at
)
select
  '23000000-0000-0000-0000-000000000001',
  aiqc.version,
  now()
from public.ai_question_curricula as aiqc
where aiqc.status = 'active'
order by aiqc.version desc
limit 1
on conflict (couple_id, curriculum_version) do update
set activated_at = excluded.activated_at;

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status,
  story_edit_locked_at
)
values (
  '33000000-0000-0000-0000-000000000020',
  '23000000-0000-0000-0000-000000000001',
  current_date - 2,
  'question_preparing',
  now()
);

insert into public.story_loop_cards (
  id,
  story_loop_id,
  couple_id,
  couple_date,
  author_user_id,
  preview_path,
  scene_data_path,
  has_drawing
)
values
  (
    '43000000-0000-0000-0000-000000000020',
    '33000000-0000-0000-0000-000000000020',
    '23000000-0000-0000-0000-000000000001',
    current_date - 2,
    '13000000-0000-0000-0000-000000000001',
    '23000000-0000-0000-0000-000000000001/loops/recovery/a/preview.png',
    '23000000-0000-0000-0000-000000000001/loops/recovery/a/scene.json',
    true
  ),
  (
    '43000000-0000-0000-0000-000000000021',
    '33000000-0000-0000-0000-000000000020',
    '23000000-0000-0000-0000-000000000001',
    current_date - 2,
    '13000000-0000-0000-0000-000000000002',
    '23000000-0000-0000-0000-000000000001/loops/recovery/b/preview.png',
    '23000000-0000-0000-0000-000000000001/loops/recovery/b/scene.json',
    true
  );

insert into public.ai_processing_jobs (
  id,
  couple_id,
  focused_question_id,
  job_type,
  status,
  deduplication_key,
  attempts,
  max_attempts,
  completed_at,
  last_error
)
select
  '83000000-0000-0000-0000-000000000020',
  '23000000-0000-0000-0000-000000000001',
  aifq.id,
  'generate_personalized_question',
  'failed',
  'story-loop:33000000-0000-0000-0000-000000000020:'
    || 'generate_personalized_question:1',
  1,
  5,
  now(),
  'personalized_question_fallback_invalid'
from public.ai_focused_questions as aifq
where aifq.couple_id = '23000000-0000-0000-0000-000000000001'
order by aifq.created_at desc, aifq.id
limit 1;

select ok(
  private.ensure_ai_question_job_for_story_loop(
    '23000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000020'
  ) is not null,
  'one terminal generation failure receives one bounded recovery job'
);
select is(
  (
    select dsl.status
    from public.daily_story_loops as dsl
    where dsl.id = '33000000-0000-0000-0000-000000000020'
  ),
  'question_preparing',
  'the story loop keeps waiting while its recovery job is active'
);

update public.ai_processing_jobs
set
  status = 'failed',
  attempts = 1,
  completed_at = now(),
  last_error = 'personalized_question_fallback_invalid'
where deduplication_key =
  'story-loop:33000000-0000-0000-0000-000000000020:'
    || 'generate_personalized_question:2';

select is(
  private.ensure_ai_question_job_for_story_loop(
    '23000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000020'
  ),
  null::uuid,
  'two terminal generation failures do not enqueue a third job'
);
select is(
  (
    select dsl.status
    from public.daily_story_loops as dsl
    where dsl.id = '33000000-0000-0000-0000-000000000020'
  ),
  'question_generated',
  'the bounded failure path publishes a reviewed fallback question'
);
select is(
  (
    select q.source
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.story_loop_id =
      '33000000-0000-0000-0000-000000000020'
  ),
  'curated',
  'the bounded failure path uses the reviewed curated question pool'
);

select * from finish();
rollback;
