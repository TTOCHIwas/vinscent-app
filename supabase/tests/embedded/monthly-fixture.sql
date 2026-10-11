create schema private;
create schema auth;
create schema cron;
create role anon;
create role authenticated;
create role service_role;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.user',true),'')::uuid $$;
create function cron.schedule(text,text,text) returns bigint language sql as $$ select 1::bigint $$;
create table public.couples(id uuid primary key,user_a_id uuid,user_b_id uuid,timezone text,status text);
create table public.daily_story_loops(id uuid primary key,couple_id uuid,couple_date date,status text);
create table public.story_loop_cards(
  id uuid primary key default gen_random_uuid(),story_loop_id uuid,couple_id uuid,couple_date date,author_user_id uuid,
  artifact_revision uuid,preview_path text,scene_data_path text,background_image_path text,
  has_photo boolean,has_drawing boolean default false,has_text boolean default false,text_layer_count integer default 0,
  text_character_count integer default 0,revision integer default 1,submitted_at timestamptz default now(),
  card_type text default 'full_bleed',layout_version integer default 1,is_featured boolean default false
);
create table public.questions(id uuid primary key,question_text text);
create table public.daily_questions(id uuid primary key,couple_id uuid,assigned_date date,question_id uuid);
create table public.daily_question_answers(id uuid primary key default gen_random_uuid(),daily_question_id uuid,user_id uuid,answer_text text);
create table public.ai_user_consents(couple_id uuid,user_id uuid,revision integer,granted boolean);
create function private.raise_app_error(code text) returns void language plpgsql as $$begin raise exception '%',code; end$$;
create function private.current_date_in_timezone(tz text) returns date language sql stable as $$select (now() at time zone tz)::date$$;
create function private.get_active_couple_for_current_user() returns public.couples language plpgsql as $$
declare c public.couples%rowtype; begin
select * into c from public.couples where status='active' and auth.uid() in(user_a_id,user_b_id);
if not found then perform private.raise_app_error('active_couple_required'); end if; return c; end$$;
create function private.has_current_user_ugc_safety_policy_acceptance() returns boolean language sql as $$select true$$;
create function private.have_all_couple_members_granted_ai_consent(cid uuid) returns boolean language sql stable as $$
select count(*)=2 and bool_and(granted) from public.ai_user_consents where couple_id=cid$$;
create function public.upsert_today_story_loop_card(
requested_artifact_revision uuid,requested_preview_path text,requested_scene_data_path text,requested_background_image_path text,
requested_has_photo boolean,requested_has_drawing boolean,requested_has_text boolean,requested_text_layer_count integer,
requested_text_character_count integer,expected_revision integer default null
) returns table(story_loop_id uuid,story_loop_status text,card_id uuid,card_revision integer,question_generated boolean,daily_question_id uuid)
language plpgsql as $$declare c public.couples%rowtype; loop_id uuid; saved_id uuid; begin
c:=private.get_active_couple_for_current_user();
select id into loop_id from public.daily_story_loops where couple_id=c.id and couple_date=private.current_date_in_timezone(c.timezone);
if loop_id is null then loop_id:=gen_random_uuid();insert into public.daily_story_loops values(loop_id,c.id,private.current_date_in_timezone(c.timezone),'waiting_partner_card');end if;
insert into public.story_loop_cards(story_loop_id,couple_id,couple_date,author_user_id,artifact_revision,preview_path,scene_data_path,background_image_path,has_photo,has_drawing,has_text,text_layer_count,text_character_count)
values(loop_id,c.id,private.current_date_in_timezone(c.timezone),auth.uid(),requested_artifact_revision,requested_preview_path,requested_scene_data_path,requested_background_image_path,requested_has_photo,requested_has_drawing,requested_has_text,requested_text_layer_count,requested_text_character_count) returning id into saved_id;
return query select loop_id,'waiting_partner_card',saved_id,1,false,null::uuid;end$$;
create function public.delete_story_card(target_card_id uuid) returns void language plpgsql as $$begin
if not exists(select 1 from public.story_loop_cards where id=target_card_id and author_user_id=auth.uid() and couple_date=private.current_date_in_timezone('UTC')) then raise exception 'story_card_locked'; end if;
delete from public.story_loop_cards where id=target_card_id;end$$;
create function private.get_ai_user_personalization_context(uuid,uuid,integer) returns jsonb language sql stable as $$select '{"recent_completed_questions":[]}'::jsonb$$;
