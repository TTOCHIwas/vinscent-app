begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(30);

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
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-user-a@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-user-b@example.test',
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
  '20000000-0000-0000-0000-000000000001',
  'AITEST01',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
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
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  current_date - 1,
  'answered_by_one',
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
  '40000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  q.id,
  current_date - 1,
  'answered_by_one',
  '30000000-0000-0000-0000-000000000001'
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
    '50000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '내가 중요하게 생각하는 첫 번째 답변'
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    '상대가 중요하게 생각하는 두 번째 답변'
  );

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (
    select consent_status
    from public.set_my_ai_consent(true, 'ai-learning-v1')
  ),
  'granted'::text,
  'first member can grant AI consent'
);

reset role;

select is(
  private.have_all_couple_members_granted_ai_consent(
    '20000000-0000-0000-0000-000000000001'
  ),
  false,
  'one member consent is not enough'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (
    select consent_status
    from public.set_my_ai_consent(true, 'ai-learning-v1')
  ),
  'granted'::text,
  'second member can grant AI consent'
);

reset role;

select is(
  private.have_all_couple_members_granted_ai_consent(
    '20000000-0000-0000-0000-000000000001'
  ),
  true,
  'AI processing opens only after both members consent'
);

select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '20000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'rebuild_profile'
  ),
  1::bigint,
  'mutual consent enqueues one idempotent profile rebuild'
);

update public.daily_questions
set status = 'completed'
where id = '40000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.daily_question_id = '40000000-0000-0000-0000-000000000001'
  ),
  3::bigint,
  'completed answers enqueue memory, feedback, and next-question jobs'
);

select is(
  (
    select count(distinct aipj.job_type)
    from public.ai_processing_jobs as aipj
    where aipj.daily_question_id = '40000000-0000-0000-0000-000000000001'
  ),
  3::bigint,
  'completed-answer jobs have distinct purposes'
);

update public.daily_questions
set status = 'completed'
where id = '40000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.daily_question_id = '40000000-0000-0000-0000-000000000001'
  ),
  3::bigint,
  'repeated completed updates do not duplicate jobs'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (public.get_ai_learning_progress()->>'completed_count')::integer,
  1,
  'learning progress counts completed foundation questions'
);

select is(
  public.get_ai_learning_progress()->>'stage',
  'collecting'::text,
  'the first completed question remains in the collecting stage'
);

select is(
  (
    public.get_ai_learning_dashboard()
      ->'progress'
      ->>'completed_count'
  )::integer,
  1,
  'the AI dashboard includes learning progress'
);

reset role;

insert into public.ai_runs (
  id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  input_answer_ids,
  safety_status,
  completed_at
)
values (
  '60000000-0000-0000-0000-000000000003',
  '20000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'generate_personalized_question',
  'test-provider',
  'test-model',
  'personalized-question-v1',
  'succeeded',
  array[
    '50000000-0000-0000-0000-000000000001'::uuid,
    '50000000-0000-0000-0000-000000000002'::uuid
  ],
  'passed',
  now()
);

select throws_ok(
  $$
    select public.create_ai_question_candidate(
      '60000000-0000-0000-0000-000000000003',
      'early_personalized_question',
      '아직 생성되면 안 되는 개인화 질문',
      'personalized',
      null
    )
  $$,
  'P0001',
  'ai_foundation_incomplete',
  'personalized questions cannot be created before 24 foundation answers'
);

insert into public.daily_questions (
  couple_id,
  question_id,
  assigned_date,
  status
)
select
  '20000000-0000-0000-0000-000000000001',
  q.id,
  current_date - q.curriculum_position,
  'answered_by_one'
from public.questions as q
where q.curriculum_version = 1
  and q.curriculum_position between 2 and 24;

insert into public.daily_question_answers (
  daily_question_id,
  user_id,
  answer_text
)
select
  dq.id,
  participant.user_id,
  '기초 질문 ' || q.curriculum_position::text || '의 테스트 답변'
from public.daily_questions as dq
join public.questions as q on q.id = dq.question_id
cross join (
  values
    ('10000000-0000-0000-0000-000000000001'::uuid),
    ('10000000-0000-0000-0000-000000000002'::uuid)
) as participant(user_id)
where dq.couple_id = '20000000-0000-0000-0000-000000000001'
  and q.curriculum_version = 1
  and q.curriculum_position between 2 and 24;

update public.daily_questions as dq
set status = 'completed'
from public.questions as q
where dq.question_id = q.id
  and dq.couple_id = '20000000-0000-0000-0000-000000000001'
  and q.curriculum_version = 1
  and q.curriculum_position between 2 and 24;

update public.ai_processing_jobs as aipj
set
  status = 'succeeded',
  completed_at = now()
where aipj.couple_id = '20000000-0000-0000-0000-000000000001'
  and aipj.job_type = 'extract_memories';

insert into public.ai_runs (
  id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  input_answer_ids,
  safety_status,
  completed_at
)
values (
  '60000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'extract_memories',
  'test-provider',
  'test-model',
  'memory-v1',
  'succeeded',
  array['50000000-0000-0000-0000-000000000001'::uuid],
  'passed',
  now()
);

insert into public.ai_memories (
  id,
  couple_id,
  scope,
  subject_user_id,
  memory_key,
  kind,
  learning_domain,
  evidence_type,
  origin_curriculum_version,
  statement,
  confidence,
  source_run_id,
  observed_at,
  last_observed_at
)
values (
  '70000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'personal',
  '10000000-0000-0000-0000-000000000001',
  'test_personal_memory',
  'personal_value',
  'personal_values',
  'explicit',
  1,
  '첫 번째 사용자가 중요하게 여기는 확인 전 기억',
  0.8,
  '60000000-0000-0000-0000-000000000001',
  now(),
  now()
);

insert into public.ai_memory_evidence (memory_id, answer_id)
values (
  '70000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.list_ai_memories()),
  0::bigint,
  'a partner cannot see an unconfirmed personal memory'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (
    public.get_ai_learning_dashboard()
      ->'memories'
      ->0
      ->>'can_confirm'
  )::boolean,
  true,
  'the subject can confirm a pending personal memory from the dashboard'
);

select is(
  (
    select memory_state
    from public.confirm_ai_memory(
      '70000000-0000-0000-0000-000000000001',
      'confirmed'
    )
  ),
  'active'::text,
  'the subject can confirm a personal memory'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.list_ai_memories()),
  1::bigint,
  'a confirmed personal memory is shared with the partner'
);

select is(
  (
    public.get_ai_learning_dashboard()
      ->'memories'
      ->0
      ->>'can_confirm'
  )::boolean,
  false,
  'the partner cannot confirm another member personal memory'
);

reset role;

insert into public.ai_memories (
  id,
  couple_id,
  scope,
  subject_user_id,
  memory_key,
  kind,
  learning_domain,
  evidence_type,
  origin_curriculum_version,
  statement,
  confidence,
  source_run_id,
  observed_at,
  last_observed_at
)
values (
  '70000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000001',
  'couple',
  null,
  'test_couple_memory',
  'relationship_pattern',
  'relationship_strength',
  'explicit',
  1,
  '두 사람이 함께 확인해야 하는 커플 기억',
  0.85,
  '60000000-0000-0000-0000-000000000001',
  now(),
  now()
);

insert into public.ai_memory_evidence (memory_id, answer_id)
values (
  '70000000-0000-0000-0000-000000000002',
  '50000000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (
    select memory_state
    from public.confirm_ai_memory(
      '70000000-0000-0000-0000-000000000002',
      'confirmed'
    )
  ),
  'pending'::text,
  'one confirmation keeps a couple memory pending'
);

select is(
  (
    select memory->>'my_decision'
    from jsonb_array_elements(
      public.get_ai_learning_dashboard()->'memories'
    ) as memory
    where memory->>'memory_id' =
      '70000000-0000-0000-0000-000000000002'
  ),
  'confirmed'::text,
  'the dashboard exposes the current member confirmation'
);

select is(
  (
    select concat(
      memory->>'can_confirm',
      ':',
      memory->>'confirmed_count',
      ':',
      memory->>'required_confirmation_count'
    )
    from jsonb_array_elements(
      public.get_ai_learning_dashboard()->'memories'
    ) as memory
    where memory->>'memory_id' =
      '70000000-0000-0000-0000-000000000002'
  ),
  'false:1:2'::text,
  'the dashboard represents partner confirmation waiting state'
);

reset role;

insert into public.ai_runs (
  id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  input_answer_ids,
  safety_status,
  completed_at
)
values (
  '60000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'select_curated_question',
  'test-provider',
  'test-model',
  'question-ranking-v1',
  'succeeded',
  array[
    '50000000-0000-0000-0000-000000000001'::uuid,
    '50000000-0000-0000-0000-000000000002'::uuid
  ],
  'passed',
  now()
);

select ok(
  public.record_ai_question_recommendation(
    '60000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    (
      select q.id
      from public.questions as q
      where q.curriculum_version = 1
        and q.curriculum_position = 3
    ),
    '테스트에서 세 번째 질문을 우선 추천'
  ) is not null,
  'a validated model run can record a question recommendation'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '30000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000001',
  current_date,
  'waiting_partner_card'
);

do $$
declare
  target_couple public.couples%rowtype;
  target_story_loop public.daily_story_loops%rowtype;
begin
  select c.*
  into target_couple
  from public.couples as c
  where c.id = '20000000-0000-0000-0000-000000000001';

  select dsl.*
  into target_story_loop
  from public.daily_story_loops as dsl
  where dsl.id = '30000000-0000-0000-0000-000000000002';

  perform private.assign_question_to_story_loop(
    target_couple,
    target_story_loop
  );
end;
$$;

select is(
  (
    select q.question_key
    from public.daily_questions as dq
    join public.questions as q
      on q.id = dq.question_id
    where dq.story_loop_id = '30000000-0000-0000-0000-000000000002'
  ),
  'foundation_v1_personal_values_03'::text,
  'a prepared recommendation takes precedence over sequential fallback'
);

select is(
  (
    select aiqr.status
    from public.ai_question_recommendations as aiqr
    where aiqr.couple_id = '20000000-0000-0000-0000-000000000001'
  ),
  'used'::text,
  'an assigned recommendation is marked as used'
);

select is(
  (
    select count(*)
    from public.claim_ai_processing_jobs('behavior-test-worker', 1)
  ),
  1::bigint,
  'a worker can claim one queued job while both members consent'
);

select is(
  public.complete_ai_processing_job(
    (
      select aipj.id
      from public.ai_processing_jobs as aipj
      where aipj.couple_id = '20000000-0000-0000-0000-000000000001'
        and aipj.status = 'processing'
      limit 1
    ),
    'failed',
    'temporary model failure'
  ),
  true,
  'a worker can report a transient failure'
);

select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '20000000-0000-0000-0000-000000000001'
      and aipj.last_error = 'temporary model failure'
  ),
  'pending'::text,
  'a transient failure returns to the queue before max attempts'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (
    select consent_status
    from public.set_my_ai_consent(false, 'ai-learning-v1')
  ),
  'revoked'::text,
  'a member can revoke AI consent'
);

reset role;

select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = '20000000-0000-0000-0000-000000000001'
      and aipj.status in ('pending', 'processing')
  ),
  0::bigint,
  'revocation cancels pending and processing jobs'
);

select is(
  private.have_all_couple_members_granted_ai_consent(
    '20000000-0000-0000-0000-000000000001'
  ),
  false,
  'AI processing closes immediately after consent revocation'
);

delete from public.couples
where id = '20000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.ai_runs as air
    where air.couple_id = '20000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'AI records do not block the existing couple deletion lifecycle'
);

select * from finish();
rollback;
