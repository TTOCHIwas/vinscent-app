begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(17);

select has_function('public', 'get_current_monthly_retrospective_availability', array[]::text[], 'availability RPC exists');
select ok(not has_function_privilege('anon', 'public.get_current_monthly_retrospective_availability()', 'EXECUTE'), 'anonymous access denied');
select ok(has_function_privilege('authenticated', 'public.get_current_monthly_retrospective_availability()', 'EXECUTE'), 'authenticated access allowed');
select is((select provolatile::text from pg_proc where oid='public.get_current_monthly_retrospective_availability()'::regprocedure), 's', 'RPC is stable and cannot mutate rows');
select throws_ok('select public.get_current_monthly_retrospective_availability()', 'P0001', 'auth_required', 'missing identity denied');

insert into auth.users (id,aud,role,email,created_at,updated_at)
select id::uuid,'authenticated','authenticated',email,now(),now() from (values
  ('71000000-0000-0000-0000-000000000001','availability-a@example.test'),
  ('71000000-0000-0000-0000-000000000002','availability-b@example.test'),
  ('71000000-0000-0000-0000-000000000003','availability-c@example.test'),
  ('71000000-0000-0000-0000-000000000004','availability-d@example.test')
) as users(id,email);
insert into public.user_policy_acceptances(user_id,policy_type,policy_version)
select id,'ugc_safety_policy','ugc-safety-v1' from auth.users
where id between '71000000-0000-0000-0000-000000000001'::uuid and '71000000-0000-0000-0000-000000000004'::uuid;
insert into public.couples(id,invite_code,user_a_id,user_b_id,relationship_start_date,timezone,status,connected_at,character_setup_status)
values
 ('72000000-0000-0000-0000-000000000001','MONAV001','71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002',current_date-90,'UTC','active',now(),'default'),
 ('72000000-0000-0000-0000-000000000002','MONAV002','71000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000004',current_date-90,'UTC','active',now(),'default');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select is((public.get_current_monthly_retrospective_availability()->>'has_records')::boolean, false, 'empty month hidden');
select is(public.get_current_monthly_retrospective_availability()->>'month', (date_trunc('month',now())-interval '1 month')::date::text, 'only last month provided');
select is((public.get_current_monthly_retrospective_availability()->>'available_until')::timestamptz, date_trunc('month',now())+interval '1 month', 'expires at end of current month');
select is((select count(*) from public.monthly_retrospectives where couple_id='72000000-0000-0000-0000-000000000001'), 0::bigint, 'lookup creates no retrospective');
select is((select count(*) from private.monthly_retrospective_content cache join public.monthly_retrospectives r on r.id=cache.retrospective_id where r.couple_id='72000000-0000-0000-0000-000000000001'), 0::bigint, 'lookup creates no content cache');

insert into public.questions(id,question_text) values ('73000000-0000-0000-0000-000000000001','Availability fixture question');
insert into public.daily_questions(id,couple_id,question_id,assigned_date,status)
values ('74000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001',(date_trunc('month',now())-interval '1 month')::date+4,'pending');
select is((public.get_current_monthly_retrospective_availability()->>'has_records')::boolean, false, 'unanswered assigned question excluded');
insert into public.daily_question_answers(daily_question_id,user_id,answer_text)
values ('74000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','Partner-only private original');
select is((public.get_current_monthly_retrospective_availability()->>'has_records')::boolean, true, 'partner-only answer without any card included');
select is((select count(*) from public.monthly_retrospectives where couple_id='72000000-0000-0000-0000-000000000001'), 0::bigint, 'positive availability also creates no retrospective');
select is((select count(*) from jsonb_object_keys(public.get_current_monthly_retrospective_availability())), 4::bigint, 'only metadata returned, no question or answers');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
select is((public.get_current_monthly_retrospective_availability()->>'has_records')::boolean, false, 'other couple records excluded');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
delete from public.daily_question_answers where daily_question_id='74000000-0000-0000-0000-000000000001';
insert into public.daily_story_loops(id,couple_id,couple_date,status)
values ('75000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001',(date_trunc('month',now())-interval '1 month')::date+4,'waiting_partner_card');
insert into public.story_loop_cards(id,story_loop_id,couple_id,couple_date,author_user_id,artifact_revision,preview_path,scene_data_path,has_photo,has_drawing)
select '76000000-0000-0000-0000-000000000001'::uuid,loop.id,loop.couple_id,loop.couple_date,
  '71000000-0000-0000-0000-000000000001'::uuid,'76000000-0000-0000-0000-000000000001'::uuid,
  loop.couple_id||'/loops/'||loop.couple_date||'/71000000-0000-0000-0000-000000000001/76000000-0000-0000-0000-000000000001/preview.png',
  loop.couple_id||'/loops/'||loop.couple_date||'/71000000-0000-0000-0000-000000000001/76000000-0000-0000-0000-000000000001/scene.json',false,true
from public.daily_story_loops loop where loop.id='75000000-0000-0000-0000-000000000001';
select is((public.get_current_monthly_retrospective_availability()->>'has_records')::boolean, true, 'drawing card without any answer included');
insert into public.monthly_retrospectives(couple_id,month,available_until)
values ('72000000-0000-0000-0000-000000000001',(date_trunc('month',now())-interval '1 month')::date,date_trunc('month',now())+interval '1 month');
select public.get_current_monthly_retrospective_availability();
select is((select question from public.monthly_retrospectives where couple_id='72000000-0000-0000-0000-000000000001'), null::text, 'lookup never fixes the reflection question');
select * from finish();
rollback;
