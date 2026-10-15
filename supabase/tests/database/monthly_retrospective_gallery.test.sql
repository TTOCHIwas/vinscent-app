begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

select has_function('private', 'monthly_retrospective_gallery', array['uuid','date'], 'monthly gallery exists');
select ok(not has_function_privilege('authenticated', 'private.monthly_retrospective_gallery(uuid,date)', 'EXECUTE'), 'gallery helper is not directly callable by clients');
select ok(not has_function_privilege('anon', 'private.monthly_retrospective_gallery(uuid,date)', 'EXECUTE'), 'gallery helper is not callable anonymously');
select is(private.monthly_retrospective_gallery('61000000-0000-0000-0000-000000000000', current_date), '[]'::jsonb, 'missing cards produce an empty array');

insert into auth.users (id,aud,role,email,created_at,updated_at) values
  ('61000000-0000-0000-0000-000000000001','authenticated','authenticated','monthly-gallery-a@example.test',now(),now()),
  ('61000000-0000-0000-0000-000000000002','authenticated','authenticated','monthly-gallery-b@example.test',now(),now());
insert into public.couples (id,invite_code,user_a_id,user_b_id,relationship_start_date,timezone,status,connected_at,character_setup_status)
values ('62000000-0000-0000-0000-000000000001','MONGAL01',
  '61000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000002',current_date-60,'UTC','active',now(),'default');
insert into public.daily_story_loops (id,couple_id,couple_date,status)
values ('63000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',
  (date_trunc('month',now())-interval '1 month')::date+4,'waiting_partner_card');
insert into public.story_loop_cards (id,story_loop_id,couple_id,couple_date,author_user_id,artifact_revision,preview_path,scene_data_path,has_photo,has_drawing,is_featured)
select v.id::uuid, '63000000-0000-0000-0000-000000000001'::uuid,'62000000-0000-0000-0000-000000000001'::uuid,
  (date_trunc('month',now())-interval '1 month')::date+4, v.author::uuid,v.id::uuid,
  '62000000-0000-0000-0000-000000000001/loops/'||((date_trunc('month',now())-interval '1 month')::date+4)::text||'/'||v.author||'/'||v.id||'/preview.png',
  '62000000-0000-0000-0000-000000000001/loops/'||((date_trunc('month',now())-interval '1 month')::date+4)::text||'/'||v.author||'/'||v.id||'/scene.json',v.photo,not v.photo,v.featured
from (values
  ('64000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001',false,true),
  ('64000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000002',true,true),
  ('64000000-0000-0000-0000-000000000003','61000000-0000-0000-0000-000000000001',true,false)
) as v(id,author,photo,featured);

create temporary table gallery_result as select private.monthly_retrospective_gallery(
  '62000000-0000-0000-0000-000000000001',(date_trunc('month',now())-interval '1 month')::date
) as data;
select is((select jsonb_array_length(data) from gallery_result),2,'each author retains one card');
select is((select data->0->>'id' from gallery_result),'64000000-0000-0000-0000-000000000001','non-photo featured card is included');
select is((select data->1->>'id' from gallery_result),'64000000-0000-0000-0000-000000000002','partner card is included');
select is((select data->0->>'card_type' from gallery_result),'polaroid','original visual format is preserved');
select is(private.monthly_retrospective_gallery('62000000-0000-0000-0000-000000000001',date_trunc('month',now())::date),'[]'::jsonb,'another month is excluded');
select set_config('request.jwt.claim.sub','61000000-0000-0000-0000-000000000001',true);
select is(public.get_current_monthly_retrospective()->'gallery',(select data from gallery_result),'authenticated monthly response includes the gallery');
select * from finish();
rollback;
