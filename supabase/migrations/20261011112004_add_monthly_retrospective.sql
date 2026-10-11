create table private.story_card_count_coverage (
  id boolean primary key default true check (id),
  started_at timestamptz not null default now()
);
insert into private.story_card_count_coverage default values;

create table private.story_card_write_receipts (
  artifact_revision uuid primary key,
  card_id uuid not null,
  couple_id uuid not null references public.couples(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  couple_date date not null,
  request_body jsonb not null,
  format_request jsonb,
  directly_deleted boolean not null default false
);
create table private.story_card_daily_counts (
  couple_id uuid not null references public.couples(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  couple_date date not null,
  card_count integer not null check (card_count >= 0),
  primary key (couple_id, author_user_id, couple_date)
);

create function private.count_saved_story_card()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into private.story_card_write_receipts
    (artifact_revision, card_id, couple_id, author_user_id, couple_date,request_body)
  values (new.artifact_revision, new.id, new.couple_id, new.author_user_id, new.couple_date,
    jsonb_build_object('preview',new.preview_path,'scene',new.scene_data_path,'background',new.background_image_path,
      'photo',new.has_photo,'drawing',new.has_drawing,'text',new.has_text,
      'layers',new.text_layer_count,'characters',new.text_character_count));
  insert into private.story_card_daily_counts (couple_id, author_user_id, couple_date, card_count)
  values (new.couple_id, new.author_user_id, new.couple_date, 1)
  on conflict (couple_id, author_user_id, couple_date)
  do update set card_count = private.story_card_daily_counts.card_count + 1;
  return new;
end;
$$;
create trigger story_card_count_saved after insert on public.story_loop_cards
for each row execute function private.count_saved_story_card();

alter function public.upsert_today_story_loop_card(uuid,text,text,text,boolean,boolean,boolean,integer,integer,integer)
rename to upsert_today_story_loop_card_before_monthly;
revoke all on function public.upsert_today_story_loop_card_before_monthly(uuid,text,text,text,boolean,boolean,boolean,integer,integer,integer)
from public, anon, authenticated;

create function public.upsert_today_story_loop_card(
  requested_artifact_revision uuid, requested_preview_path text,
  requested_scene_data_path text, requested_background_image_path text,
  requested_has_photo boolean, requested_has_drawing boolean, requested_has_text boolean,
  requested_text_layer_count integer, requested_text_character_count integer,
  expected_revision integer default null
) returns table (story_loop_id uuid, story_loop_status text, card_id uuid,
  card_revision integer, question_generated boolean, daily_question_id uuid)
language plpgsql security definer set search_path = '' as $$
declare c public.couples%rowtype; receipt private.story_card_write_receipts%rowtype;
  card public.story_loop_cards%rowtype;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  c := private.get_active_couple_for_current_user();
  if requested_artifact_revision is null then perform private.raise_app_error('invalid_story_card_artifact_revision'); end if;
  perform pg_advisory_xact_lock(hashtext('story_card_request'), hashtext(requested_artifact_revision::text));
  select * into receipt from private.story_card_write_receipts where artifact_revision = requested_artifact_revision;
  if found then
    if receipt.couple_id <> c.id or receipt.author_user_id <> auth.uid()
      or receipt.couple_date <> private.current_date_in_timezone(c.timezone)
      or receipt.directly_deleted then perform private.raise_app_error('story_card_locked'); end if;
    select * into card from public.story_loop_cards where id = receipt.card_id;
    if not found or receipt.request_body is distinct from jsonb_build_object(
      'preview',btrim(requested_preview_path),'scene',btrim(requested_scene_data_path),
      'background',nullif(btrim(requested_background_image_path),''),'photo',requested_has_photo,
      'drawing',requested_has_drawing,'text',requested_has_text,'layers',requested_text_layer_count,
      'characters',requested_text_character_count)
      or expected_revision is not null
    then perform private.raise_app_error('story_card_locked'); end if;
    return query select card.story_loop_id, dsl.status, card.id, card.revision, false, dq.id
      from public.daily_story_loops dsl left join public.daily_questions dq
      on dq.couple_id = c.id and dq.assigned_date = card.couple_date
      where dsl.id = card.story_loop_id;
    return;
  end if;
  return query select * from public.upsert_today_story_loop_card_before_monthly(
    requested_artifact_revision, requested_preview_path, requested_scene_data_path,
    requested_background_image_path, requested_has_photo, requested_has_drawing,
    requested_has_text, requested_text_layer_count, requested_text_character_count, expected_revision);
end;
$$;
revoke all on function public.upsert_today_story_loop_card(uuid,text,text,text,boolean,boolean,boolean,integer,integer,integer)
from public, anon;
grant execute on function public.upsert_today_story_loop_card(uuid,text,text,text,boolean,boolean,boolean,integer,integer,integer) to authenticated;

alter function public.delete_story_card(uuid) rename to delete_story_card_before_monthly;
revoke all on function public.delete_story_card_before_monthly(uuid) from public, anon, authenticated;
create function public.delete_story_card(target_card_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare card public.story_loop_cards%rowtype;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  select * into card from public.story_loop_cards where id = target_card_id for update;
  if not found then perform private.raise_app_error('story_card_not_found'); end if;
  perform public.delete_story_card_before_monthly(target_card_id);
  update private.story_card_write_receipts set directly_deleted = true
  where artifact_revision = card.artifact_revision and not directly_deleted;
  if found then
    update private.story_card_daily_counts set card_count = card_count - 1
    where couple_id = card.couple_id and author_user_id = card.author_user_id
      and couple_date = card.couple_date and card_count > 0;
    if not found then raise exception 'story_card_count_inconsistent'; end if;
  end if;
end;
$$;
revoke all on function public.delete_story_card(uuid) from public, anon;
grant execute on function public.delete_story_card(uuid) to authenticated;

create table public.monthly_retrospectives (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  question text check (char_length(question) between 1 and 300),
  question_source text check (question_source in ('basic','ai')),
  available_until timestamptz not null,
  created_at timestamptz not null default now(),
  unique (couple_id, month)
);
create table public.monthly_retrospective_answers (
  id uuid primary key default gen_random_uuid(),
  retrospective_id uuid not null references public.monthly_retrospectives(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer_text text not null check (char_length(btrim(answer_text)) between 1 and 500),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (retrospective_id, user_id)
);
alter table public.monthly_retrospectives enable row level security;
alter table public.monthly_retrospective_answers enable row level security;
revoke all on public.monthly_retrospectives, public.monthly_retrospective_answers from public, anon, authenticated;
grant all on public.monthly_retrospectives, public.monthly_retrospective_answers to service_role;

create table private.monthly_retrospective_content (
  retrospective_id uuid primary key references public.monthly_retrospectives(id) on delete cascade,
  title text,
  summary text,
  status text not null default 'pending' check (status in ('pending','generating','ready','failed','basic')),
  token uuid,
  lease_until timestamptz,
  consent_versions jsonb,
  expires_at timestamptz not null
);

create function private.monthly_question_records(target_couple_id uuid, target_month date)
returns table (id uuid, assigned_date date, question_text text, my_user_id uuid,
  first_answer text, second_answer text, answer_count integer, answer_length integer)
language sql stable security definer set search_path = '' as $$
  select dq.id, dq.assigned_date, q.question_text, c.user_a_id,
    a.answer_text, b.answer_text,
    ((a.id is not null)::integer + (b.id is not null)::integer),
    char_length(regexp_replace(coalesce(a.answer_text,'') || coalesce(b.answer_text,''), '[[:space:]]', '', 'g'))
  from public.daily_questions dq join public.questions q on q.id = dq.question_id
  join public.couples c on c.id = dq.couple_id
  left join public.daily_question_answers a on a.daily_question_id = dq.id and a.user_id = c.user_a_id
  left join public.daily_question_answers b on b.daily_question_id = dq.id and b.user_id = c.user_b_id
  where dq.couple_id = target_couple_id and dq.assigned_date >= target_month
    and dq.assigned_date < (target_month + interval '1 month')::date;
$$;

create function private.monthly_retained_photo_cards(target_couple_id uuid, target_month date)
returns setof public.story_loop_cards language sql stable security definer set search_path = '' as $$
  select card.* from public.story_loop_cards card join (
    select id, row_number() over(partition by couple_date,author_user_id
      order by is_featured desc,submitted_at desc,id desc) as position
    from public.story_loop_cards where couple_id=target_couple_id
      and couple_date>=target_month and couple_date<(target_month+interval '1 month')::date
  ) retained on retained.id=card.id where retained.position=1 and card.has_photo;
$$;

create function private.monthly_retrospective_data(target_couple_id uuid, target_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.couples%rowtype; m date; until_at timestamptz; r public.monthly_retrospectives%rowtype;
  content private.monthly_retrospective_content%rowtype; mine public.monthly_retrospective_answers%rowtype;
  partner public.monthly_retrospective_answers%rowtype; days integer; completed integer; total integer;
  complete boolean; moments jsonb; conversation jsonb; ai boolean; has_records boolean;
begin
  select * into c from public.couples where id = target_couple_id and status = 'active'
    and target_user_id in (user_a_id, user_b_id) and user_b_id is not null;
  if not found then perform private.raise_app_error('active_couple_required'); end if;
  m := (date_trunc('month', private.current_date_in_timezone(c.timezone)::timestamp) - interval '1 month')::date;
  until_at := ((m + interval '2 months')::timestamp at time zone c.timezone);
  ai := private.have_all_couple_members_granted_ai_consent(c.id);
  select count(*)::integer into completed from private.monthly_question_records(c.id,m) where answer_count = 2;
  select count(*)::integer into days from (
    select couple_date as d from public.story_loop_cards where couple_id=c.id and couple_date>=m and couple_date<(m+interval '1 month')::date
    union select assigned_date from private.monthly_question_records(c.id,m) where answer_count > 0
  ) recorded;
  has_records := days > 0;
  select started_at <= (m::timestamp at time zone c.timezone) into complete from private.story_card_count_coverage where id;
  select coalesce(sum(card_count),0)::integer into total from private.story_card_daily_counts
    where couple_id=c.id and couple_date>=m and couple_date<(m+interval '1 month')::date;

  with candidates as (
    select distinct card.couple_date, coalesce(q.answer_count,0)>0 as answered,
      coalesce(q.answer_length,0) as length,
      least(3, ((extract(day from card.couple_date)::integer-1)/10)+1) as segment
    from private.monthly_retained_photo_cards(c.id,m) card left join private.monthly_question_records(c.id,m) q on q.assigned_date=card.couple_date
    where card.couple_id=c.id and card.has_photo and card.couple_date>=m and card.couple_date<(m+interval '1 month')::date
  ), ranked as (
    select *, row_number() over(partition by segment order by answered desc,length desc,couple_date) as position from candidates
  ), initial as (select * from ranked where position=1), extra as (
    select * from ranked where position<>1 order by answered desc,length desc,couple_date
    limit greatest(0,3-(select count(*)::integer from initial))
  ), selected as (select * from initial union all select * from extra)
  select coalesce(jsonb_agg(jsonb_build_object('date',s.couple_date,'question',q.question_text,
    'cards',(select jsonb_agg(jsonb_build_object('id',card.id,'preview_path',card.preview_path,
      'author_user_id',card.author_user_id,'aspect_ratio',case
        when card.card_type='four_cut_grid' and card.layout_version=2 then 20.0/27
        when card.card_type='four_cut_strip' and card.layout_version=2 then 8.0/21
        when card.card_type='four_cut_strip' then 0.4 else 0.8 end)
      order by card.author_user_id) from private.monthly_retained_photo_cards(c.id,m) card
      where card.couple_id=c.id and card.couple_date=s.couple_date and card.has_photo)) order by s.couple_date),'[]'::jsonb)
  into moments from selected s left join private.monthly_question_records(c.id,m) q on q.assigned_date=s.couple_date;

  select jsonb_build_object('date',q.assigned_date,'question',q.question_text,
    'my_answer',case when target_user_id=c.user_a_id then q.first_answer else q.second_answer end,
    'partner_answer',case when target_user_id=c.user_a_id then q.second_answer else q.first_answer end,
    'partner_answer_id',(select id from public.daily_question_answers where daily_question_id=q.id and user_id<>target_user_id limit 1))
  into conversation from private.monthly_question_records(c.id,m) q where answer_count=2
    order by answer_length desc,assigned_date,id limit 1;

  if has_records then
    insert into public.monthly_retrospectives (couple_id,month,available_until)
    values(c.id,m,until_at) on conflict (couple_id,month) do nothing;
    select * into r from public.monthly_retrospectives where couple_id=c.id and month=m for update;
    insert into private.monthly_retrospective_content(retrospective_id,expires_at)
      values(r.id,until_at) on conflict do nothing;
    select * into content from private.monthly_retrospective_content where retrospective_id=r.id;
    if r.question is null and (not ai or completed=0) then
      update public.monthly_retrospectives set question='지난달을 돌아보며 다음 달 함께하고 싶은 일은 뭐야?', question_source='basic' where id=r.id;
      r.question := '지난달을 돌아보며 다음 달 함께하고 싶은 일은 뭐야?'; r.question_source := 'basic';
    end if;
    select * into mine from public.monthly_retrospective_answers where retrospective_id=r.id and user_id=target_user_id;
    select * into partner from public.monthly_retrospective_answers where retrospective_id=r.id and user_id<>target_user_id;
  end if;
  return jsonb_build_object('couple_id',c.id,'month',m,'available_until',until_at,
    'recorded_days',days,'card_count',case when complete then total else null end,'card_count_complete',complete,
    'completed_questions',completed,'has_records',has_records,'ai_enabled',ai,
    'title',case when ai and content.expires_at>now() then coalesce(content.title,'우리의 '||extract(month from m)::integer||'월') else '우리의 '||extract(month from m)::integer||'월' end,
    'summary',case when ai and content.expires_at>now() then content.summary else null end,
    'content_status',case when not ai or completed=0 then 'basic' else coalesce(content.status,'pending') end,
    'moments',moments,'conversation',conversation,
    'reflection',case when r.id is null then null else jsonb_build_object('id',r.id,'question',r.question,
      'source',r.question_source,'my_answer',mine.answer_text,'my_answer_id',mine.id,
      'partner_answer',case when mine.id is not null then partner.answer_text else null end,
      'partner_answer_id',case when mine.id is not null then partner.id else null end,
      'partner_answer_exists',partner.id is not null,'version',coalesce(mine.version,0)) end);
end;
$$;

create function public.get_current_monthly_retrospective()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.couples%rowtype;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  c := private.get_active_couple_for_current_user();
  delete from private.monthly_retrospective_content cache using public.monthly_retrospectives r
    where cache.retrospective_id=r.id and r.couple_id=c.id and cache.expires_at<=now();
  return private.monthly_retrospective_data(c.id,auth.uid());
end;
$$;
create function public.submit_current_monthly_retrospective_answer(requested_retrospective_id uuid,
  requested_answer_text text, expected_version integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.couples%rowtype; r public.monthly_retrospectives%rowtype; current_version integer;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  c := private.get_active_couple_for_current_user();
  if not private.has_current_user_ugc_safety_policy_acceptance() then perform private.raise_app_error('ugc_safety_policy_required'); end if;
  select * into r from public.monthly_retrospectives where id=requested_retrospective_id and couple_id=c.id for update;
  if not found or r.available_until<=now() or r.month<>(date_trunc('month',private.current_date_in_timezone(c.timezone)::timestamp)-interval '1 month')::date
    or r.question is null then perform private.raise_app_error('monthly_retrospective_unavailable'); end if;
  if requested_answer_text is null or btrim(requested_answer_text)='' then perform private.raise_app_error('answer_required'); end if;
  if char_length(requested_answer_text)>500 then perform private.raise_app_error('answer_too_long'); end if;
  select version into current_version from public.monthly_retrospective_answers where retrospective_id=r.id and user_id=auth.uid();
  if expected_version is null or coalesce(current_version,0)<>expected_version then perform private.raise_app_error('monthly_answer_conflict'); end if;
  insert into public.monthly_retrospective_answers(retrospective_id,user_id,answer_text)
  values(r.id,auth.uid(),requested_answer_text)
  on conflict (retrospective_id,user_id) do update set answer_text=excluded.answer_text,
    version=public.monthly_retrospective_answers.version+1,updated_at=now();
  return private.monthly_retrospective_data(c.id,auth.uid());
end;
$$;

create function public.prepare_monthly_retrospective_generation(requested_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.couples%rowtype; data jsonb; r public.monthly_retrospectives%rowtype;
  content private.monthly_retrospective_content%rowtype; generation_token uuid; questions jsonb; versions jsonb;
begin
  select * into c from public.couples where status='active' and user_b_id is not null
    and requested_user_id in(user_a_id,user_b_id) for update;
  if not found then perform private.raise_app_error('active_couple_required'); end if;
  perform pg_advisory_xact_lock(hashtext('ai_consent'),hashtext(c.id::text));
  data := private.monthly_retrospective_data(c.id,requested_user_id);
  if not (data->>'ai_enabled')::boolean or not (data->>'has_records')::boolean
    or (data->>'completed_questions')::integer=0 then return jsonb_build_object('claimed',false); end if;
  select * into r from public.monthly_retrospectives where id=(data->'reflection'->>'id')::uuid for update;
  select * into content from private.monthly_retrospective_content where retrospective_id=r.id for update;
  if content.status='ready' or content.lease_until>now() then return jsonb_build_object('claimed',false); end if;
  generation_token := gen_random_uuid();
  select jsonb_object_agg(user_id::text,revision) into versions from public.ai_user_consents where couple_id=c.id;
  update private.monthly_retrospective_content set status='generating',token=generation_token,
    lease_until=now()+interval '90 seconds',consent_versions=versions where retrospective_id=r.id;
  select jsonb_agg(jsonb_build_object('id',id,'text',question_text,'answers',jsonb_build_array(first_answer,second_answer)) order by assigned_date,id)
    into questions from private.monthly_question_records(c.id,r.month) where answer_count=2;
  return jsonb_build_object('claimed',true,'retrospective_id',r.id,'token',generation_token,'month',r.month,'questions',questions);
end;
$$;

create function public.finish_monthly_retrospective_generation(requested_retrospective_id uuid,
  requested_token uuid, requested_content jsonb)
returns boolean language plpgsql security definer set search_path = '' as $$
declare r public.monthly_retrospectives%rowtype; c public.couples%rowtype;
  content private.monthly_retrospective_content%rowtype; versions jsonb;
begin
  select * into r from public.monthly_retrospectives where id=requested_retrospective_id;
  if not found then return false; end if;
  select * into c from public.couples where id=r.couple_id and status='active' and user_b_id is not null for update;
  if not found or not private.have_all_couple_members_granted_ai_consent(c.id) or r.available_until<=now() then return false; end if;
  perform pg_advisory_xact_lock(hashtext('ai_consent'),hashtext(c.id::text));
  if not private.have_all_couple_members_granted_ai_consent(c.id) then return false; end if;
  select * into r from public.monthly_retrospectives where id=requested_retrospective_id for update;
  select * into content from private.monthly_retrospective_content where retrospective_id=r.id for update;
  select jsonb_object_agg(user_id::text,revision) into versions from public.ai_user_consents where couple_id=c.id;
  if content.retrospective_id is null or content.token is null or content.token is distinct from requested_token or content.lease_until is null or content.lease_until<=now()
    or content.consent_versions is distinct from versions then return false; end if;
  if requested_content is null then
    update private.monthly_retrospective_content set status='failed',lease_until=null,token=null where retrospective_id=r.id;
    return false;
  end if;
  if jsonb_typeof(requested_content) is distinct from 'object'
    or jsonb_typeof(requested_content->'title') is distinct from 'string'
    or jsonb_typeof(requested_content->'question') is distinct from 'string'
    or jsonb_typeof(requested_content->'summary_sentences') is distinct from 'array' then raise exception 'invalid_monthly_content'; end if;
  if char_length(btrim(requested_content->>'title')) not between 1 and 80
    or char_length(btrim(requested_content->>'question')) not between 1 and 300
    or jsonb_array_length(requested_content->'summary_sentences') not between 2 and 3
    or exists(select 1 from jsonb_array_elements(requested_content->'summary_sentences') s
      where jsonb_typeof(s) <> 'string' or char_length(btrim(s #>> '{}')) not between 1 and 250)
    then raise exception 'invalid_monthly_content'; end if;
  update private.monthly_retrospective_content set title=requested_content->>'title',
    summary=(select string_agg(value,' ' order by ordinality) from jsonb_array_elements_text(requested_content->'summary_sentences') with ordinality),
    status='ready',lease_until=null,token=null where retrospective_id=r.id;
  update public.monthly_retrospectives set question=requested_content->>'question',question_source='ai' where id=r.id and question is null;
  return true;
end;
$$;

create function public.use_basic_monthly_retrospective_question(requested_retrospective_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.couples%rowtype;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  c := private.get_active_couple_for_current_user();
  update public.monthly_retrospectives set question='지난달을 돌아보며 다음 달 함께하고 싶은 일은 뭐야?',question_source='basic'
    where id=requested_retrospective_id and couple_id=c.id and available_until>now() and question is null;
  return private.monthly_retrospective_data(c.id,auth.uid());
end;
$$;

alter function private.get_ai_user_personalization_context(uuid,uuid,integer)
rename to get_ai_user_personalization_context_before_monthly;
create function private.get_ai_user_personalization_context(target_couple_id uuid,target_user_id uuid,maximum_memories_per_subject integer)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare base jsonb; reflections jsonb;
begin
  base := private.get_ai_user_personalization_context_before_monthly(target_couple_id,target_user_id,maximum_memories_per_subject);
  if private.have_all_couple_members_granted_ai_consent(target_couple_id) then
    select coalesce(jsonb_agg(jsonb_build_object('question_text',item.question,
      'answers',item.answers) order by item.month desc),'[]'::jsonb) into reflections from (
      select r.month,r.question,jsonb_agg(jsonb_build_object('subject',case when a.user_id=target_user_id then 'me' else 'partner' end,
        'text','['||to_char(r.month,'YYYY-MM')||' 회고] '||a.answer_text) order by a.user_id) as answers
      from public.monthly_retrospectives r join public.monthly_retrospective_answers a on a.retrospective_id=r.id
      where r.couple_id=target_couple_id and r.question is not null
        and (a.user_id=target_user_id or exists(select 1 from public.monthly_retrospective_answers mine where mine.retrospective_id=r.id and mine.user_id=target_user_id))
      group by r.id,r.month,r.question order by r.month desc limit 3
    ) item;
    base := jsonb_set(base,'{recent_completed_questions}',coalesce(base->'recent_completed_questions','[]'::jsonb)||reflections);
  end if;
  return base;
end;
$$;

revoke all on private.story_card_count_coverage, private.story_card_write_receipts,
  private.story_card_daily_counts, private.monthly_retrospective_content from public, anon, authenticated;
revoke all on function private.count_saved_story_card(), private.monthly_question_records(uuid,date),
  private.monthly_retained_photo_cards(uuid,date),
  private.monthly_retrospective_data(uuid,uuid),private.get_ai_user_personalization_context(uuid,uuid,integer) from public,anon,authenticated;
revoke all on function public.get_current_monthly_retrospective(), public.submit_current_monthly_retrospective_answer(uuid,text,integer),
  public.use_basic_monthly_retrospective_question(uuid) from public,anon;
grant execute on function public.get_current_monthly_retrospective(), public.submit_current_monthly_retrospective_answer(uuid,text,integer),
  public.use_basic_monthly_retrospective_question(uuid) to authenticated;
revoke all on function public.prepare_monthly_retrospective_generation(uuid),public.finish_monthly_retrospective_generation(uuid,uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.prepare_monthly_retrospective_generation(uuid),public.finish_monthly_retrospective_generation(uuid,uuid,jsonb) to service_role;
