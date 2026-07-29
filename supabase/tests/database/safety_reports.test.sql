begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

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
    '17000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'safety-user-a@example.test',
    now(),
    now()
  ),
  (
    '17000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'safety-user-b@example.test',
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
  '27000000-0000-0000-0000-000000000001',
  'SAFE01',
  '17000000-0000-0000-0000-000000000001',
  '17000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
);

insert into public.ai_user_questions (
  id,
  couple_id,
  requester_user_id,
  question_text,
  status,
  result_kind,
  answer_text,
  answered_at
)
values
  (
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    '우리 둘은 어디에서 쉬면 좋을까?',
    'completed',
    'answered',
    '조용한 공원을 함께 걸어도 좋겠어',
    now()
  ),
  (
    '37000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000002',
    '상대방의 비공개 질문',
    'completed',
    'answered',
    '상대방만 볼 수 있는 답변',
    now()
  );

create temporary table captured_safety_reports (
  name text primary key,
  report_id uuid not null
);

select ok(
  to_regclass('public.safety_reports') is not null,
  'safety reports have private storage'
);
select ok(
  to_regprocedure(
    'public.submit_safety_report(text,text,text,text,text)'
  ) is not null,
  'authenticated clients have one safety report RPC'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.safety_reports',
    'SELECT'
  ),
  'authenticated clients cannot read moderation records'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'partner',
      '17000000-0000-0000-0000-000000000002',
      'harassment',
      null,
      null
    )
  $$,
  'P0001',
  'auth_required',
  'an unauthenticated caller cannot submit a report'
);

select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

insert into captured_safety_reports (name, report_id)
values (
  'partner',
  public.submit_safety_report(
    'partner',
    '17000000-0000-0000-0000-000000000002',
    'harassment',
    '불편한 상호작용이 있었어요',
    '클라이언트가 보낸 내용은 저장하지 않음'
  )
);

reset role;

select isnt(
  (select report_id from captured_safety_reports where name = 'partner'),
  null::uuid,
  'a member can report the current partner'
);
select is(
  (
    select reporter_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'partner'
    )
  ),
  '17000000-0000-0000-0000-000000000001'::uuid,
  'the server records the authenticated reporter'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'partner'
    )
  ),
  '17000000-0000-0000-0000-000000000002'::uuid,
  'the server derives the current partner'
);
select is(
  (
    select target_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'partner'
    )
  ),
  '17000000-0000-0000-0000-000000000002',
  'the partner report target cannot be substituted'
);
select is(
  (
    select couple_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'partner'
    )
  ),
  '27000000-0000-0000-0000-000000000001'::uuid,
  'the server records the active couple context'
);

set local role authenticated;

insert into captured_safety_reports (name, report_id)
values (
  'direct-answer',
  public.submit_safety_report(
    'ai_direct_answer',
    '37000000-0000-0000-0000-000000000001',
    'unsafe_ai',
    null,
    '위조한 답변'
  )
);

reset role;

select isnt(
  (
    select report_id
    from captured_safety_reports
    where name = 'direct-answer'
  ),
  null::uuid,
  'a requester can report their generated direct answer'
);
select is(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'direct-answer'
    )
  ),
  '조용한 공원을 함께 걸어도 좋겠어',
  'persisted AI output is read from the server instead of the client'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'direct-answer'
    )
  ),
  null::uuid,
  'AI output reports do not accuse the partner'
);

set local role authenticated;

select throws_ok(
  $$
    select public.submit_safety_report(
      'ai_direct_answer',
      '37000000-0000-0000-0000-000000000002',
      'unsafe_ai',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report the partner private AI answer'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'ai_proactive_suggestion',
      'suggestion-without-snapshot',
      'unsafe_ai',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_snapshot_required',
  'an ephemeral AI suggestion requires a bounded snapshot'
);

insert into captured_safety_reports (name, report_id)
values (
  'proactive',
  public.submit_safety_report(
    'ai_proactive_suggestion',
    'suggestion-opaque-id',
    'unsafe_ai',
    null,
    '  오늘은 가까운 공원에서 쉬어도 좋겠어  '
  )
);

reset role;

select isnt(
  (select report_id from captured_safety_reports where name = 'proactive'),
  null::uuid,
  'an ephemeral proactive suggestion can be reported'
);
select is(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'proactive'
    )
  ),
  '오늘은 가까운 공원에서 쉬어도 좋겠어',
  'ephemeral content is normalized before storage'
);

update public.safety_reports
set status = 'dismissed',
    moderation_note = 'reviewed once',
    reviewed_at = now()
where id = (
  select report_id
  from captured_safety_reports
  where name = 'proactive'
);

set local role authenticated;

select is(
  public.submit_safety_report(
    'ai_proactive_suggestion',
    'suggestion-opaque-id',
    'other',
    '추가 설명',
    '오늘은 가까운 공원에서 쉬어도 좋겠어'
  ),
  (
    select report_id
    from captured_safety_reports
    where name = 'proactive'
  ),
  'submitting the same target updates one moderation record'
);

reset role;

select is(
  (
    select count(*)
    from public.safety_reports
    where reporter_user_id =
      '17000000-0000-0000-0000-000000000001'
      and target_type = 'ai_proactive_suggestion'
      and target_id = 'suggestion-opaque-id'
  ),
  1::bigint,
  'duplicate reports do not create duplicate moderation work'
);
select is(
  (
    select status
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'proactive'
    )
  ),
  'pending',
  'a changed report returns a resolved moderation record to the queue'
);
select is(
  (
    select moderation_note
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'proactive'
    )
  ),
  null::text,
  'a changed report clears the previous moderation note'
);
select is(
  (
    select reviewed_at
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'proactive'
    )
  ),
  null::timestamptz,
  'a changed report clears the previous review time'
);

update public.safety_reports
set status = 'dismissed',
    moderation_note = 'same content reviewed',
    reviewed_at = now()
where id = (
  select report_id
  from captured_safety_reports
  where name = 'proactive'
);

set local role authenticated;

select is(
  public.submit_safety_report(
    'ai_proactive_suggestion',
    'suggestion-opaque-id',
    'other',
    '추가 설명',
    '오늘은 가까운 공원에서 쉬어도 좋겠어'
  ),
  (
    select report_id
    from captured_safety_reports
    where name = 'proactive'
  ),
  'resubmitting identical content keeps one moderation record'
);

reset role;

select is(
  (
    select status
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_reports
      where name = 'proactive'
    )
  ),
  'dismissed',
  'an identical report does not reopen resolved moderation work'
);

set local role authenticated;

select throws_ok(
  $$
    select public.submit_safety_report(
      'partner',
      '17000000-0000-0000-0000-000000000002',
      'unsupported_reason',
      null,
      null
    )
  $$,
  'P0001',
  'invalid_safety_report_reason',
  'unsupported report reasons are rejected'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'unsupported_target',
      'target',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'invalid_safety_report_target_type',
  'unsupported report targets are rejected'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'partner',
      '17000000-0000-0000-0000-000000000002',
      'other',
      repeat('x', 1001),
      null
    )
  $$,
  'P0001',
  'safety_report_details_too_long',
  'oversized report details are rejected'
);

reset role;

select * from finish();
rollback;
