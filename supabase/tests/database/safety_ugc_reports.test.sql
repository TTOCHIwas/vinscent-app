begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(25);

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
    '18000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'safety-ugc-user-a@example.test',
    now(),
    now()
  ),
  (
    '18000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'safety-ugc-user-b@example.test',
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
  '28000000-0000-0000-0000-000000000001',
  'UGCR01',
  '18000000-0000-0000-0000-000000000001',
  '18000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'custom'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '38000000-0000-0000-0000-000000000001',
  '28000000-0000-0000-0000-000000000001',
  current_date - 2,
  'question_generated'
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
    '48000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001',
    current_date - 2,
    '18000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 2)::text
      || '/18000000-0000-0000-0000-000000000001/preview.png',
    '28000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 2)::text
      || '/18000000-0000-0000-0000-000000000001/scene.json',
    true
  ),
  (
    '48000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001',
    current_date - 2,
    '18000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 2)::text
      || '/18000000-0000-0000-0000-000000000002/preview.png',
    '28000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 2)::text
      || '/18000000-0000-0000-0000-000000000002/scene.json',
    true
  );

insert into public.questions (
  id,
  source,
  question_text
)
values (
  '58000000-0000-0000-0000-000000000001',
  'curated',
  '오늘 가장 기억에 남은 순간은 뭐야?'
);

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status,
  story_loop_id
)
values (
  '68000000-0000-0000-0000-000000000001',
  '28000000-0000-0000-0000-000000000001',
  '58000000-0000-0000-0000-000000000001',
  current_date - 2,
  'completed',
  '38000000-0000-0000-0000-000000000001'
);

insert into public.daily_question_answers (
  id,
  daily_question_id,
  user_id,
  answer_text
)
values
  (
    '78000000-0000-0000-0000-000000000001',
    '68000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000001',
    '내가 작성한 답변'
  ),
  (
    '78000000-0000-0000-0000-000000000002',
    '68000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000002',
    '상대방이 작성한 답변'
  );

insert into public.couple_recordings (
  id,
  couple_id,
  sender_user_id,
  storage_path,
  duration_ms
)
values
  (
    '88000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001/recordings/'
      || '88000000-0000-0000-0000-000000000001.m4a',
    5000
  ),
  (
    '88000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000001/recordings/'
      || '88000000-0000-0000-0000-000000000002.m4a',
    7000
  );

insert into public.couple_recording_slots (
  id,
  couple_id,
  slot_index,
  title,
  recording_id,
  created_by_user_id,
  updated_by_user_id
)
values
  (
    '98000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001',
    1,
    '상대방이 만든 슬롯',
    '88000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000002'
  ),
  (
    '98000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000001',
    2,
    '내가 마지막으로 수정한 슬롯',
    '88000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000001'
  );

insert into public.couple_calendar_events (
  id,
  couple_id,
  title,
  event_date,
  memo,
  created_by_user_id,
  updated_by_user_id
)
values
  (
    'a8000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001',
    '상대방이 수정한 일정',
    current_date + 1,
    '상대방이 작성한 메모',
    '18000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000002'
  ),
  (
    'a8000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000001',
    '내가 수정한 일정',
    current_date + 2,
    null,
    '18000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000001'
  );

insert into public.couple_characters (
  couple_id,
  image_path,
  drawing_data_path,
  updated_by
)
values (
  '28000000-0000-0000-0000-000000000001',
  '28000000-0000-0000-0000-000000000001/current.png',
  '28000000-0000-0000-0000-000000000001/current.json',
  '18000000-0000-0000-0000-000000000002'
);

create temporary table captured_ugc_safety_reports (
  name text primary key,
  report_id uuid not null
);

select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

insert into captured_ugc_safety_reports (name, report_id)
values
  (
    'story-card',
    public.submit_safety_report(
      'story_card',
      '48000000-0000-0000-0000-000000000002',
      'inappropriate',
      null,
      'client supplied card snapshot'
    )
  ),
  (
    'question-answer',
    public.submit_safety_report(
      'question_answer',
      '78000000-0000-0000-0000-000000000002',
      'harassment',
      null,
      'client supplied answer snapshot'
    )
  ),
  (
    'recording',
    public.submit_safety_report(
      'recording',
      '88000000-0000-0000-0000-000000000002',
      'inappropriate',
      null,
      'client supplied recording snapshot'
    )
  ),
  (
    'recording-slot',
    public.submit_safety_report(
      'recording',
      '98000000-0000-0000-0000-000000000001',
      'privacy',
      null,
      'client supplied slot snapshot'
    )
  ),
  (
    'calendar-event',
    public.submit_safety_report(
      'calendar_event',
      'a8000000-0000-0000-0000-000000000001',
      'harassment',
      null,
      'client supplied calendar snapshot'
    )
  ),
  (
    'character',
    public.submit_safety_report(
      'character',
      '28000000-0000-0000-0000-000000000001',
      'inappropriate',
      null,
      'client supplied character snapshot'
    )
  );

reset role;

select isnt(
  (select report_id from captured_ugc_safety_reports where name = 'story-card'),
  null::uuid,
  'a member can report the partner story card'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'story-card'
    )
  ),
  '18000000-0000-0000-0000-000000000002'::uuid,
  'a story card report is attributed to its author'
);
select like(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'story-card'
    )
  ),
  'date=%; preview_path=%',
  'the story card snapshot is resolved by the server'
);

select isnt(
  (
    select report_id
    from captured_ugc_safety_reports
    where name = 'question-answer'
  ),
  null::uuid,
  'a member can report the partner question answer'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'question-answer'
    )
  ),
  '18000000-0000-0000-0000-000000000002'::uuid,
  'a question answer report is attributed to its author'
);
select is(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'question-answer'
    )
  ),
  '상대방이 작성한 답변',
  'the answer snapshot is read from the server'
);

select isnt(
  (select report_id from captured_ugc_safety_reports where name = 'recording'),
  null::uuid,
  'a member can report the partner recording'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'recording'
    )
  ),
  '18000000-0000-0000-0000-000000000002'::uuid,
  'a recording report is attributed to its sender'
);
select like(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'recording'
    )
  ),
  'duration_ms=7000; storage_path=%',
  'the recording snapshot contains server metadata'
);

select isnt(
  (
    select report_id
    from captured_ugc_safety_reports
    where name = 'recording-slot'
  ),
  null::uuid,
  'a member can report a slot last edited by the partner'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'recording-slot'
    )
  ),
  '18000000-0000-0000-0000-000000000002'::uuid,
  'a slot report is attributed to its latest editor'
);
select like(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'recording-slot'
    )
  ),
  'slot_title=상대방이 만든 슬롯; duration_ms=7000;%',
  'the slot snapshot contains its title and recording metadata'
);

select isnt(
  (
    select report_id
    from captured_ugc_safety_reports
    where name = 'calendar-event'
  ),
  null::uuid,
  'a member can report a calendar event last edited by the partner'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'calendar-event'
    )
  ),
  '18000000-0000-0000-0000-000000000002'::uuid,
  'a calendar event report is attributed to its latest editor'
);
select is(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'calendar-event'
    )
  ),
  E'상대방이 수정한 일정\n상대방이 작성한 메모',
  'the calendar event snapshot contains server title and memo'
);

select isnt(
  (select report_id from captured_ugc_safety_reports where name = 'character'),
  null::uuid,
  'a member can report a character last edited by the partner'
);
select is(
  (
    select reported_user_id
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'character'
    )
  ),
  '18000000-0000-0000-0000-000000000002'::uuid,
  'a character report is attributed to its latest editor'
);
select like(
  (
    select content_snapshot
    from public.safety_reports
    where id = (
      select report_id
      from captured_ugc_safety_reports
      where name = 'character'
    )
  ),
  'image_path=%; drawing_data_path=%',
  'the character snapshot contains server artifact metadata'
);

set local role authenticated;

select throws_ok(
  $$
    select public.submit_safety_report(
      'story_card',
      '48000000-0000-0000-0000-000000000001',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report their own story card'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'question_answer',
      '78000000-0000-0000-0000-000000000001',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report their own question answer'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'recording',
      '88000000-0000-0000-0000-000000000001',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report their own recording'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'recording',
      '98000000-0000-0000-0000-000000000002',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report a slot they last edited'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'calendar_event',
      'a8000000-0000-0000-0000-000000000002',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report a calendar event they last edited'
);

reset role;

update public.couple_characters
set updated_by = '18000000-0000-0000-0000-000000000001'
where couple_id = '28000000-0000-0000-0000-000000000001';

set local role authenticated;

select throws_ok(
  $$
    select public.submit_safety_report(
      'character',
      '28000000-0000-0000-0000-000000000001',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report a character they last edited'
);
select throws_ok(
  $$
    select public.submit_safety_report(
      'story_card',
      '48000000-0000-0000-0000-000000000099',
      'other',
      null,
      null
    )
  $$,
  'P0001',
  'safety_report_target_not_available',
  'a member cannot report an unavailable UGC target'
);

reset role;

select * from finish();
rollback;
