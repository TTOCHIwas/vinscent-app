begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(27);

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
      '첫 번째 사용자의 집중 질문 답변'
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
      '두 번째 사용자의 집중 질문 답변'
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
    'memory-v5'
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
          'statement', '파트너 A는 첫 번째 답변의 선택을 중요하게 생각한다',
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

select private.assign_question_to_story_loop(
  (
    select c
    from public.couples as c
    where c.id = '22000000-0000-0000-0000-000000000001'
  ),
  (
    select dsl
    from public.daily_story_loops as dsl
    where dsl.id = '32000000-0000-0000-0000-000000000001'
  )
);

select is(
  (
    select dq.status
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.story_loop_id = '32000000-0000-0000-0000-000000000001'
      and q.curriculum_position = 2
  ),
  'answered_by_one',
  'a card question adopts an existing focused answer instead of being blocked'
);

select * from finish();
rollback;
