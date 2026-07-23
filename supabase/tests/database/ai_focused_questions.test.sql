begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(39);

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
    'ai-focused-user-a@example.test',
    now(),
    now()
  ),
  (
    '12000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-focused-user-b@example.test',
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
  'AIFOCUS1',
  '12000000-0000-0000-0000-000000000001',
  '12000000-0000-0000-0000-000000000002',
  current_date - 10,
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

select ok(
  to_regclass('public.ai_focused_questions') is not null,
  'focused question assignments exist'
);
select ok(
  to_regclass('public.ai_focused_question_answers') is not null,
  'focused question answers have dedicated storage'
);
select ok(
  to_regprocedure('public.unlock_ai_focused_questions()') is not null,
  'focused question unlock RPC exists'
);
select ok(
  to_regprocedure('public.get_ai_focused_question_flow()') is not null,
  'focused question read RPC exists'
);
select ok(
  to_regprocedure(
    'public.submit_ai_focused_question_answer(uuid,text)'
  ) is not null,
  'focused question submit RPC exists'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.ai_focused_questions',
    'INSERT'
  ),
  'clients cannot write focused assignments directly'
);

select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.unlock_ai_focused_questions()->>'status',
  'answering',
  'one member can unlock the focused flow'
);
select is(
  public.get_ai_focused_question_flow()->'progress'->>'my_answered_count',
  '0',
  'newly unlocked flow starts without answers'
);
select is(
  public.get_ai_focused_question_flow()
    ->'question'->>'curriculum_position',
  '1',
  'the first fallback question follows the curated progression'
);

select lives_ok(
  $$
    select public.submit_ai_focused_question_answer(
      (public.get_ai_focused_question_flow()->'question'->>'question_id')::uuid,
      'first member focused answer'
    )
  $$,
  'the first member can answer without waiting for the partner'
);
select is(
  public.get_ai_focused_question_flow()->'progress'->>'my_answered_count',
  '1',
  'the first member advances independently'
);
select is(
  public.get_ai_focused_question_flow()
    ->'question'->>'curriculum_position',
  '2',
  'the first member immediately receives the next unanswered question'
);
select is(
  jsonb_array_length(public.get_ai_focused_question_history()),
  0,
  'focused history hides a question until both members answer'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  public.get_ai_focused_question_flow()
    ->'question'->>'curriculum_position',
  '1',
  'the partner receives their own first unanswered question'
);
select lives_ok(
  $$
    select public.submit_ai_focused_question_answer(
      (public.get_ai_focused_question_flow()->'question'->>'question_id')::uuid,
      'second member focused answer'
    )
  $$,
  'the partner can complete the same focused question'
);
select is(
  public.get_ai_focused_question_flow()
    ->'progress'->>'couple_completed_count',
  '1',
  'a question counts as complete after both answers'
);
select is(
  jsonb_array_length(public.get_ai_focused_question_history()),
  1,
  'focused history reveals a question after both members answer'
);
select is(
  public.get_ai_focused_question_history()
    ->0->>'my_answer_text',
  'second member focused answer',
  'focused history orients the current member answer as mine'
);
select is(
  public.get_ai_focused_question_history()
    ->0->>'partner_answer_text',
  'first member focused answer',
  'focused history orients the other member answer as partner'
);

reset role;

select is(
  (
    select status
    from public.ai_focused_questions
    where couple_id = '22000000-0000-0000-0000-000000000001'
      and question_id = (
        select id
        from public.questions
        where curriculum_version = 1
          and curriculum_position = 1
      )
  ),
  'completed',
  'focused assignment persists the couple completion state'
);
select ok(
  exists (
    select 1
    from public.ai_processing_jobs
    where couple_id = '22000000-0000-0000-0000-000000000001'
      and focused_question_id = (
        select id
        from public.ai_focused_questions
        where couple_id = '22000000-0000-0000-0000-000000000001'
          and question_id = (
            select id
            from public.questions
            where curriculum_version = 1
              and curriculum_position = 1
          )
      )
      and job_type = 'extract_memories'
  ),
  'completed focused questions enter the memory extraction queue'
);

update public.ai_processing_jobs
set
  status = 'processing',
  attempts = 1,
  claimed_at = now(),
  claimed_by = 'focused-test-worker',
  lease_expires_at = now() + interval '5 minutes'
where couple_id = '22000000-0000-0000-0000-000000000001'
  and job_type = 'extract_memories'
  and focused_question_id is not null;

create temporary table ai_focused_worker_values (
  value_key text primary key,
  value_uuid uuid not null
) on commit drop;

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      (
        select id
        from public.ai_processing_jobs
        where couple_id = '22000000-0000-0000-0000-000000000001'
          and job_type = 'extract_memories'
          and focused_question_id is not null
      )
    )->'answers'
  ),
  2,
  'focused worker context contains both answers'
);
select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      (
        select id
        from public.ai_processing_jobs
        where couple_id = '22000000-0000-0000-0000-000000000001'
          and job_type = 'extract_memories'
          and focused_question_id is not null
      )
    )->'remaining_foundation_questions'
  ),
  23,
  'focused worker context excludes the completed question'
);

insert into ai_focused_worker_values (value_key, value_uuid)
select
  'extract_run',
  public.start_ai_processing_run(
    (
      select id
      from public.ai_processing_jobs
      where couple_id = '22000000-0000-0000-0000-000000000001'
        and job_type = 'extract_memories'
        and focused_question_id is not null
    ),
    'google',
    'gemini-test',
    'memory-v6'
  );

select ok(
  (
    select value_uuid
    from ai_focused_worker_values
    where value_key = 'extract_run'
  ) is not null,
  'worker can start a focused extraction run'
);
select ok(
  (
    select air.focused_question_id is not null
      and air.daily_question_id is null
    from public.ai_runs as air
    where air.id = (
      select value_uuid
      from ai_focused_worker_values
      where value_key = 'extract_run'
    )
  ),
  'focused runs preserve their answer source'
);
select is(
  public.succeed_ai_processing_run(
    (
      select value_uuid
      from ai_focused_worker_values
      where value_key = 'extract_run'
    ),
    jsonb_build_object(
      'memories',
      jsonb_build_array(
        jsonb_build_object(
          'memory_key', 'focused_partner_a_preference',
          'scope', 'personal',
          'subject_user_id', '12000000-0000-0000-0000-000000000001',
          'kind', 'personal_value',
          'learning_domain', 'personal_values',
          'evidence_type', 'explicit',
          'sensitive_category', 'none',
          'statement', '첫 번째 답변에서 고른 선택을 중요하게 여겨',
          'confidence', 0.9,
          'evidence_answer_ids', jsonb_build_array(
            (
              select aifqa.id
              from public.ai_focused_question_answers as aifqa
              where aifqa.user_id =
                '12000000-0000-0000-0000-000000000001'
            )
          )
        )
      )
    ),
    100,
    30,
    200
  ),
  true,
  'worker can persist focused memory candidates'
);
select is(
  (
    select count(*)
    from public.ai_focused_memory_evidence as aifme
    join public.ai_memories as aim on aim.id = aifme.memory_id
    where aim.memory_key = 'focused_partner_a_preference'
  ),
  1::bigint,
  'focused memory evidence remains in the focused source table'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '31000000-0000-0000-0000-000000000099',
  '22000000-0000-0000-0000-000000000001',
  current_date - 1,
  'question_generated'
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
  '32000000-0000-0000-0000-000000000099',
  '22000000-0000-0000-0000-000000000001',
  q.id,
  current_date - 1,
  'pending',
  '31000000-0000-0000-0000-000000000099'
from public.questions as q
where q.curriculum_version = 1
  and q.curriculum_position = 1;

insert into public.daily_question_answers (
  id,
  daily_question_id,
  user_id,
  answer_text
)
values
  (
    '42000000-0000-0000-0000-000000000098',
    '32000000-0000-0000-0000-000000000099',
    '12000000-0000-0000-0000-000000000001',
    '이 선택을 다른 질문에서도 중요하게 생각해'
  ),
  (
    '42000000-0000-0000-0000-000000000099',
    '32000000-0000-0000-0000-000000000099',
    '12000000-0000-0000-0000-000000000002',
    '나는 다른 선택을 중요하게 생각해'
  );

insert into public.ai_memory_evidence (memory_id, answer_id)
select
  aim.id,
  '42000000-0000-0000-0000-000000000098'
from public.ai_memories as aim
where aim.memory_key = 'focused_partner_a_preference';

update public.ai_processing_jobs
set
  status = 'succeeded',
  completed_at = now()
where daily_question_id = '32000000-0000-0000-0000-000000000099';

update public.ai_processing_jobs
set
  status = 'processing',
  attempts = attempts + 1,
  claimed_at = now(),
  claimed_by = 'focused-repeat-test-worker',
  lease_expires_at = now() + interval '5 minutes',
  completed_at = null,
  last_error = null
where couple_id = '22000000-0000-0000-0000-000000000001'
  and job_type = 'extract_memories'
  and focused_question_id is not null;

insert into ai_focused_worker_values (value_key, value_uuid)
select
  'repeat_extract_run',
  public.start_ai_processing_run(
    (
      select id
      from public.ai_processing_jobs
      where couple_id = '22000000-0000-0000-0000-000000000001'
        and job_type = 'extract_memories'
        and focused_question_id is not null
    ),
    'google',
    'gemini-test',
    'memory-v6'
  );

select is(
  public.succeed_ai_processing_run(
    (
      select value_uuid
      from ai_focused_worker_values
      where value_key = 'repeat_extract_run'
    ),
    jsonb_build_object(
      'memories',
      jsonb_build_array(
        jsonb_build_object(
          'memory_key', 'focused_partner_a_preference',
          'scope', 'personal',
          'subject_user_id', '12000000-0000-0000-0000-000000000001',
          'kind', 'personal_value',
          'learning_domain', 'personal_values',
          'evidence_type', 'repeated_pattern',
          'sensitive_category', 'none',
          'statement', '같은 선택을 여러 질문에서 중요하게 여겨',
          'confidence', 0.88,
          'evidence_answer_ids', jsonb_build_array(
            (
              select aifqa.id
              from public.ai_focused_question_answers as aifqa
              where aifqa.user_id =
                '12000000-0000-0000-0000-000000000001'
            )
          )
        )
      )
    ),
    110,
    32,
    210
  ),
  true,
  'a repeated focused observation updates the same memory'
);
select is(
  (
    select count(*)
    from public.ai_memory_evidence as aime
    join public.ai_memories as aim on aim.id = aime.memory_id
    where aim.memory_key = 'focused_partner_a_preference'
  ),
  1::bigint,
  'updating a memory keeps evidence from a different daily question'
);
select is(
  (
    select count(distinct evidence.question_instance_id)
    from (
      select dqa.daily_question_id as question_instance_id
      from public.ai_memory_evidence as aime
      join public.daily_question_answers as dqa on dqa.id = aime.answer_id
      join public.ai_memories as aim on aim.id = aime.memory_id
      where aim.memory_key = 'focused_partner_a_preference'

      union

      select aifqa.focused_question_id
      from public.ai_focused_memory_evidence as aifme
      join public.ai_focused_question_answers as aifqa
        on aifqa.id = aifme.answer_id
      join public.ai_memories as aim on aim.id = aifme.memory_id
      where aim.memory_key = 'focused_partner_a_preference'
    ) as evidence
  ),
  2::bigint,
  'a repeated pattern retains evidence from two distinct questions'
);

select is(
  (
    select status
    from public.ai_processing_jobs
    where couple_id = '22000000-0000-0000-0000-000000000001'
      and job_type = 'extract_memories'
      and focused_question_id is not null
  ),
  'succeeded',
  'focused extraction completion closes the job'
);

select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_ai_learning_progress()->>'completed_count',
  '1',
  'learning progress includes focused completions'
);

select lives_ok(
  $$
    select public.submit_ai_focused_question_answer(
      (public.get_ai_focused_question_flow()->'question'->>'question_id')::uuid,
      '카드 질문과 합쳐질 집중 질문 답변'
    )
  $$,
  'a member can begin another focused answer'
);

reset role;

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '32000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
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
    '42000000-0000-0000-0000-000000000001',
    '32000000-0000-0000-0000-000000000001',
    '22000000-0000-0000-0000-000000000001',
    current_date,
    '12000000-0000-0000-0000-000000000001',
    '22000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/12000000-0000-0000-0000-000000000001/preview.png',
    '22000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/12000000-0000-0000-0000-000000000001/scene.json',
    true
  ),
  (
    '42000000-0000-0000-0000-000000000002',
    '32000000-0000-0000-0000-000000000001',
    '22000000-0000-0000-0000-000000000001',
    current_date,
    '12000000-0000-0000-0000-000000000002',
    '22000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/12000000-0000-0000-0000-000000000002/preview.png',
    '22000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/12000000-0000-0000-0000-000000000002/scene.json',
    true
  );

create temporary table focused_card_pair_result
on commit drop
as
select *
from private.finalize_story_loop_after_card_pair(
  (
    select c
    from public.couples as c
    where c.id = '22000000-0000-0000-0000-000000000001'
  ),
  (
    select dsl
    from public.daily_story_loops as dsl
    where dsl.id = '32000000-0000-0000-0000-000000000001'
  ),
  '12000000-0000-0000-0000-000000000002',
  '42000000-0000-0000-0000-000000000002'
);

select is(
  (
    select result.story_loop_status
    from focused_card_pair_result as result
  ),
  'card_only_completed',
  'focused foundation progress finalizes a card pair without a question'
);
select is(
  (
    select result.question_generated
    from focused_card_pair_result as result
  ),
  false,
  'card-only completion does not report a generated question'
);
select is(
  (
    select count(*)
    from public.daily_questions as dq
    where dq.story_loop_id = '32000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'focused foundation progress does not assign a daily question'
);
select ok(
  (
    select dsl.story_edit_locked_at is not null
    from public.daily_story_loops as dsl
    where dsl.id = '32000000-0000-0000-0000-000000000001'
  ),
  'card-only completion locks both cards'
);
select is(
  (
    select count(*)
    from public.story_loop_notification_events as slne
    where slne.story_loop_id =
      '32000000-0000-0000-0000-000000000001'
      and slne.event_type = 'question_generated'
  ),
  0::bigint,
  'card-only completion emits no question notification'
);
select is(
  (
    select aifq.status
    from public.ai_focused_questions as aifq
    join public.questions as q on q.id = aifq.question_id
    where aifq.couple_id = '22000000-0000-0000-0000-000000000001'
      and q.curriculum_position = 2
  ),
  'answered_by_one',
  'an in-progress focused answer remains in the focused flow'
);

select * from finish();
rollback;
