begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '12000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'review-user-a@example.test',
    now(),
    now()
  ),
  (
    '12000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'review-user-b@example.test',
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
  'AIREVIEW',
  '12000000-0000-0000-0000-000000000001',
  '12000000-0000-0000-0000-000000000002',
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
  revision,
  granted_at,
  revoked_at
)
values
  (
    '22000000-0000-0000-0000-000000000001',
    '12000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    1,
    now(),
    null
  ),
  (
    '22000000-0000-0000-0000-000000000001',
    '12000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    1,
    now(),
    null
  );

insert into public.daily_questions (
  couple_id,
  question_id,
  assigned_date,
  status
)
select
  '22000000-0000-0000-0000-000000000001',
  q.id,
  current_date - (25 - q.curriculum_position),
  'answered_by_one'
from public.questions as q
where q.curriculum_version = 1;

insert into public.daily_question_answers (
  daily_question_id,
  user_id,
  answer_text
)
select
  dq.id,
  participant.user_id,
  '질문 ' || q.curriculum_position::text || '의 명시적인 테스트 답변'
from public.daily_questions as dq
join public.questions as q on q.id = dq.question_id
cross join (
  values
    ('12000000-0000-0000-0000-000000000001'::uuid),
    ('12000000-0000-0000-0000-000000000002'::uuid)
) as participant(user_id)
where dq.couple_id = '22000000-0000-0000-0000-000000000001';

update public.daily_questions
set status = 'completed'
where couple_id = '22000000-0000-0000-0000-000000000001';

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
select
  '62000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
  dq.id,
  'extract_memories',
  'fixture',
  'fixture',
  'memory-v2',
  'succeeded',
  array_agg(dqa.id order by dqa.user_id),
  'passed',
  now()
from public.daily_questions as dq
join public.questions as q on q.id = dq.question_id
join public.daily_question_answers as dqa on dqa.daily_question_id = dq.id
where dq.couple_id = '22000000-0000-0000-0000-000000000001'
  and q.curriculum_position = 1
group by dq.id;

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
values
  (
    '72000000-0000-0000-0000-000000000001',
    '22000000-0000-0000-0000-000000000001',
    'personal',
    '12000000-0000-0000-0000-000000000001',
    'review_personal_a',
    'preference',
    'personal_values',
    'explicit',
    1,
    '첫 번째 사용자는 조용한 휴식을 좋아한다.',
    0.88,
    '62000000-0000-0000-0000-000000000001',
    now(),
    now()
  ),
  (
    '72000000-0000-0000-0000-000000000002',
    '22000000-0000-0000-0000-000000000001',
    'personal',
    '12000000-0000-0000-0000-000000000002',
    'review_personal_b',
    'preference',
    'personal_values',
    'explicit',
    1,
    '두 번째 사용자는 새로운 장소를 좋아한다.',
    0.86,
    '62000000-0000-0000-0000-000000000001',
    now(),
    now()
  ),
  (
    '72000000-0000-0000-0000-000000000003',
    '22000000-0000-0000-0000-000000000001',
    'couple',
    null,
    'review_repeated_couple',
    'shared_pattern',
    'daily_life',
    'repeated_pattern',
    1,
    '두 사람은 함께 걷는 시간을 반복해서 좋아한다고 답했다.',
    0.72,
    '62000000-0000-0000-0000-000000000001',
    now(),
    now()
  ),
  (
    '72000000-0000-0000-0000-000000000004',
    '22000000-0000-0000-0000-000000000001',
    'couple',
    null,
    'review_rejected_couple',
    'shared_preference',
    'relationship_strength',
    'explicit',
    1,
    '두 사람은 항상 같은 선택을 한다.',
    0.6,
    '62000000-0000-0000-0000-000000000001',
    now(),
    now()
  ),
  (
    '72000000-0000-0000-0000-000000000005',
    '22000000-0000-0000-0000-000000000001',
    'couple',
    null,
    'review_single_observation',
    'shared_pattern',
    'daily_life',
    'repeated_pattern',
    1,
    '한 질문에서만 나타난 반복 후보다.',
    0.45,
    '62000000-0000-0000-0000-000000000001',
    now(),
    now()
  );

insert into public.ai_memory_evidence (memory_id, answer_id)
select
  evidence.memory_id,
  dqa.id
from (
  values
    ('72000000-0000-0000-0000-000000000001'::uuid, 1, '12000000-0000-0000-0000-000000000001'::uuid),
    ('72000000-0000-0000-0000-000000000002'::uuid, 2, '12000000-0000-0000-0000-000000000002'::uuid),
    ('72000000-0000-0000-0000-000000000003'::uuid, 3, '12000000-0000-0000-0000-000000000001'::uuid),
    ('72000000-0000-0000-0000-000000000003'::uuid, 4, '12000000-0000-0000-0000-000000000002'::uuid),
    ('72000000-0000-0000-0000-000000000004'::uuid, 5, '12000000-0000-0000-0000-000000000001'::uuid),
    ('72000000-0000-0000-0000-000000000005'::uuid, 6, '12000000-0000-0000-0000-000000000001'::uuid)
) as evidence(memory_id, curriculum_position, user_id)
join public.daily_questions as dq
  on dq.couple_id = '22000000-0000-0000-0000-000000000001'
join public.questions as q
  on q.id = dq.question_id
  and q.curriculum_position = evidence.curriculum_position
join public.daily_question_answers as dqa
  on dqa.daily_question_id = dq.id
  and dqa.user_id = evidence.user_id;

update public.ai_processing_jobs
set
  status = 'succeeded',
  completed_at = now()
where couple_id = '22000000-0000-0000-0000-000000000001'
  and job_type <> 'generate_personalized_question';

update public.ai_processing_jobs
set
  status = 'pending',
  completed_at = null,
  claimed_at = null,
  claimed_by = null,
  lease_expires_at = null
where couple_id = '22000000-0000-0000-0000-000000000001'
  and job_type = 'extract_memories';

select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_ai_learning_dashboard()->'progress'->>'personalization_status',
  'processing'::text,
  'review waits until every foundation extraction succeeds'
);

select is(
  jsonb_array_length(public.get_ai_learning_dashboard()->'memories'),
  0,
  'memory statements stay hidden while extraction is incomplete'
);

reset role;

update public.ai_processing_jobs
set
  status = 'succeeded',
  completed_at = now()
where couple_id = '22000000-0000-0000-0000-000000000001'
  and job_type = 'extract_memories';

select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_ai_learning_dashboard()->'progress'->>'personalization_status',
  'reviewing'::text,
  'the current member reviews eligible memories after question 24'
);

select is(
  jsonb_array_length(public.get_ai_learning_dashboard()->'memories'),
  3,
  'the current member sees own and couple memories but not partner personal memory'
);

select is(
  (
    select count(*)
    from jsonb_array_elements(
      public.get_ai_learning_dashboard()->'memories'
    ) as memory
    where memory->>'memory_id' =
      '72000000-0000-0000-0000-000000000005'
  ),
  0::bigint,
  'a repeated pattern from one question is not reviewable'
);

select is(
  (public.get_ai_learning_dashboard()->'progress'->>'my_pending_review_count')::integer,
  3,
  'the dashboard counts only decisions assigned to the current member'
);

select is(
  (
    select count(*)
    from public.claim_ai_processing_jobs('review-worker-before-ready', 1)
  ),
  0::bigint,
  'personalized question work cannot start before review completion'
);

select is(
  (
    select memory_state
    from public.confirm_ai_memory(
      '72000000-0000-0000-0000-000000000001',
      'confirmed'
    )
  ),
  'active'::text,
  'a member can confirm their own personal memory'
);

reset role;

insert into public.ai_processing_jobs (
  id,
  couple_id,
  daily_question_id,
  job_type,
  status,
  deduplication_key,
  attempts,
  claimed_at,
  claimed_by,
  lease_expires_at
)
select
  '82000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
  dq.id,
  'generate_feedback',
  'processing',
  'review-context:feedback-before-ready',
  1,
  now(),
  'review-context-worker',
  now() + interval '5 minutes'
from public.daily_questions as dq
join public.questions as q on q.id = dq.question_id
where dq.couple_id = '22000000-0000-0000-0000-000000000001'
  and q.curriculum_position = 24;

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      '82000000-0000-0000-0000-000000000001'
    )->'confirmed_memories'
  ),
  0,
  'generic feedback cannot use confirmed memories before shared review completes'
);

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      '82000000-0000-0000-0000-000000000001'
    )->'recent_completed_questions'
  ),
  0,
  'generic feedback cannot use recent answer history before personalization'
);

update public.ai_processing_jobs
set status = 'succeeded', completed_at = now()
where id = '82000000-0000-0000-0000-000000000001';

select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

do $$
begin
  perform *
  from public.confirm_ai_memory(
    '72000000-0000-0000-0000-000000000003',
    'confirmed'
  );

  perform *
  from public.confirm_ai_memory(
    '72000000-0000-0000-0000-000000000004',
    'rejected'
  );
end;
$$;

select is(
  public.get_ai_learning_dashboard()->'progress'->>'personalization_status',
  'waiting_partner'::text,
  'shared AI remains generic while the partner still has review work'
);

select is(
  (public.get_ai_learning_dashboard()->'progress'->>'partner_pending_review_count')::integer,
  2,
  'partner wait includes their personal memory and shared confirmation'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '12000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

do $$
begin
  perform *
  from public.confirm_ai_memory(
    '72000000-0000-0000-0000-000000000002',
    'confirmed'
  );

  perform *
  from public.confirm_ai_memory(
    '72000000-0000-0000-0000-000000000003',
    'confirmed'
  );
end;
$$;

select is(
  (public.get_ai_learning_dashboard()->'progress'->>'personalization_enabled')::boolean,
  true,
  'personalization opens after both members resolve all required memories'
);

select is(
  public.get_ai_learning_dashboard()->'progress'->>'personalization_status',
  'ready'::text,
  'the dashboard reports ready after shared review completion'
);

reset role;

select is(
  (
    select count(*)
    from public.ai_personalization_states as aips
    where aips.couple_id = '22000000-0000-0000-0000-000000000001'
      and aips.curriculum_version = 1
      and aips.activated_at is not null
  ),
  1::bigint,
  'personalization activation is persisted once per curriculum'
);

select is(
  (
    select count(*)
    from public.claim_ai_processing_jobs('review-worker-after-ready', 1)
  ),
  1::bigint,
  'personalized question work becomes claimable after activation'
);

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      (
        select aipj.id
        from public.ai_processing_jobs as aipj
        where aipj.couple_id = '22000000-0000-0000-0000-000000000001'
          and aipj.job_type = 'generate_personalized_question'
          and aipj.status = 'processing'
        limit 1
      )
    )->'confirmed_memories'
  ),
  3,
  'personalized context contains only confirmed profile memories'
);

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      (
        select aipj.id
        from public.ai_processing_jobs as aipj
        where aipj.couple_id = '22000000-0000-0000-0000-000000000001'
          and aipj.job_type = 'generate_personalized_question'
          and aipj.status = 'processing'
        limit 1
      )
    )->'recent_completed_questions'
  ),
  6,
  'personalized context includes the previous six completed questions'
);

select * from finish();
rollback;
