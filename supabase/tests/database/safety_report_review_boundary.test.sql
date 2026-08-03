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
    '2c000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'review-reporter@example.test',
    now(),
    now()
  ),
  (
    '2c000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'review-reported@example.test',
    now(),
    now()
  );

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
values
  (
    '2c000000-0000-0000-0000-000000000001',
    'ugc_safety_policy',
    'ugc-safety-v1'
  ),
  (
    '2c000000-0000-0000-0000-000000000002',
    'ugc_safety_policy',
    'ugc-safety-v1'
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
  '2d000000-0000-0000-0000-000000000001',
  'SAFR01',
  '2c000000-0000-0000-0000-000000000001',
  '2c000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
);

create temporary table captured_safety_review_report (
  report_id uuid primary key
);

grant select, insert on table captured_safety_review_report
  to authenticated;

select set_config(
  'request.jwt.claim.sub',
  '2c000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

insert into captured_safety_review_report (report_id)
select public.submit_safety_report(
  'partner',
  '2c000000-0000-0000-0000-000000000002',
  'harassment',
  '처음 신고한 내용',
  null
);

reset role;

select ok(
  to_regclass('public.safety_report_reviews') is not null,
  'moderation decisions have immutable audit storage'
);
select has_column(
  'public',
  'safety_reports',
  'reviewed_by',
  'the current report records its reviewer'
);
select ok(
  to_regprocedure(
    'public.review_safety_report(uuid,text,text,text)'
  ) is not null,
  'moderators have one report review boundary'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.safety_report_reviews',
    'SELECT'
  ),
  'clients cannot read moderation review history'
);
select ok(
  not has_table_privilege(
    'service_role',
    'public.safety_report_reviews',
    'INSERT'
  ),
  'the moderation service cannot rewrite review audit history'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.review_safety_report(uuid,text,text,text)',
    'EXECUTE'
  ),
  'clients cannot decide moderation reports'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.review_safety_report(uuid,text,text,text)',
    'EXECUTE'
  ),
  'the moderation service can decide reports'
);
select ok(
  not has_table_privilege(
    'service_role',
    'public.safety_reports',
    'UPDATE'
  ),
  'the moderation service cannot bypass the review boundary'
);
select throws_ok(
  format(
    $sql$
      select *
      from public.review_safety_report(
        %L::uuid,
        'pending',
        'moderator-test',
        null
      )
    $sql$,
    (
      select report_id
      from captured_safety_review_report
    )
  ),
  'P0001',
  'invalid_safety_report_decision',
  'pending is not a moderation decision'
);
select throws_ok(
  format(
    $sql$
      select *
      from public.review_safety_report(
        %L::uuid,
        'actioned',
        ' ',
        null
      )
    $sql$,
    (
      select report_id
      from captured_safety_review_report
    )
  ),
  'P0001',
  'invalid_safety_report_reviewer',
  'a moderation decision requires a reviewer'
);
select is(
  (
    select review_status
    from public.review_safety_report(
      (
        select report_id
        from captured_safety_review_report
      ),
      'actioned',
      '  moderator-test  ',
      '  이용 제한 처리  '
    )
  ),
  'actioned',
  'a pending report can be actioned'
);
select is(
  (
    select status
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'actioned',
  'the report stores the decision'
);
select is(
  (
    select reviewed_by
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'moderator-test',
  'the report stores a normalized reviewer'
);
select is(
  (
    select moderation_note
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  '이용 제한 처리',
  'the report stores a normalized moderation note'
);
select ok(
  (
    select reviewed_at is not null
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'the report stores its review time'
);
select is(
  (
    select count(*)
    from public.safety_report_reviews
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  1::bigint,
  'the decision creates one audit record'
);
select is(
  (
    select decision_status
    from public.safety_report_reviews
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'actioned',
  'the audit record stores the decision'
);
select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'cancelled',
  'reviewing cancels an undelivered moderation alert'
);
select is(
  (
    select review_status
    from public.review_safety_report(
      (
        select report_id
        from captured_safety_review_report
      ),
      'actioned',
      'moderator-test',
      '이용 제한 처리'
    )
  ),
  'actioned',
  'repeating the same decision is idempotent'
);
select is(
  (
    select count(*)
    from public.safety_report_reviews
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  1::bigint,
  'an idempotent decision does not duplicate audit history'
);
select throws_ok(
  format(
    $sql$
      select *
      from public.review_safety_report(
        %L::uuid,
        'dismissed',
        'another-moderator',
        '다른 결정'
      )
    $sql$,
    (
      select report_id
      from captured_safety_review_report
    )
  ),
  'P0001',
  'safety_report_already_reviewed',
  'a resolved report cannot receive a conflicting decision'
);

set local role authenticated;

select is(
  public.submit_safety_report(
    'partner',
    '2c000000-0000-0000-0000-000000000002',
    'privacy',
    '새로운 신고 내용',
    null
  ),
  (
    select report_id
    from captured_safety_review_report
  ),
  'changed content reuses the report identity'
);

reset role;

select is(
  (
    select status
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'pending',
  'changed content returns the report to review'
);
select is(
  (
    select reviewed_by
    from public.safety_reports
    where id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  null::text,
  'requeueing clears the current reviewer'
);
select is(
  (
    select count(*)
    from public.safety_report_reviews
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  1::bigint,
  'requeueing preserves the earlier audit record'
);
select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  'pending',
  'changed content queues a fresh moderation alert'
);
select is(
  (
    select review_status
    from public.review_safety_report(
      (
        select report_id
        from captured_safety_review_report
      ),
      'dismissed',
      'moderator-test',
      '위반 없음'
    )
  ),
  'dismissed',
  'the changed report can receive a new decision'
);
select is(
  (
    select count(*)
    from public.safety_report_reviews
    where report_id = (
      select report_id
      from captured_safety_review_report
    )
  ),
  2::bigint,
  'each report revision keeps its own review audit'
);

select * from finish();
rollback;
