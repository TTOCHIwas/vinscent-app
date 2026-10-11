alter function public.upsert_today_story_loop_card_v2(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer)
rename to upsert_today_story_loop_card_v2_before_monthly;
revoke all on function public.upsert_today_story_loop_card_v2_before_monthly(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer) from public,anon,authenticated;
create function public.upsert_today_story_loop_card_v2(
  requested_artifact_revision uuid,requested_preview_path text,requested_scene_data_path text,
  requested_background_image_path text,requested_has_photo boolean,requested_has_drawing boolean,
  requested_has_text boolean,requested_text_layer_count integer,requested_text_character_count integer,
  requested_card_type text,requested_photo_count integer,requested_has_caption boolean,expected_revision integer default null
) returns table(story_loop_id uuid,story_loop_status text,card_id uuid,card_revision integer,question_generated boolean,daily_question_id uuid)
language plpgsql security definer set search_path='' as $$
declare receipt private.story_card_write_receipts%rowtype; saved record; payload jsonb;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  perform pg_advisory_xact_lock(hashtext('story_card_request'),hashtext(requested_artifact_revision::text));
  payload := jsonb_build_object('type',btrim(requested_card_type),'photos',requested_photo_count,
    'caption',coalesce(requested_has_caption,false),'photo',coalesce(requested_has_photo,false),
    'drawing',coalesce(requested_has_drawing,false));
  select * into receipt from private.story_card_write_receipts where artifact_revision=requested_artifact_revision;
  if found and receipt.format_request is not null and receipt.format_request is distinct from payload
    then perform private.raise_app_error('story_card_locked'); end if;
  select * into saved from public.upsert_today_story_loop_card_v2_before_monthly(
    requested_artifact_revision,requested_preview_path,requested_scene_data_path,requested_background_image_path,
    requested_has_photo,requested_has_drawing,requested_has_text,requested_text_layer_count,requested_text_character_count,
    requested_card_type,requested_photo_count,requested_has_caption,expected_revision);
  update private.story_card_write_receipts set format_request=payload where artifact_revision=requested_artifact_revision and format_request is null;
  return query select saved.story_loop_id,saved.story_loop_status,saved.card_id,
    saved.card_revision,saved.question_generated,saved.daily_question_id;
end;
$$;
revoke all on function public.upsert_today_story_loop_card_v2(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer) from public,anon;
grant execute on function public.upsert_today_story_loop_card_v2(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer) to authenticated;

alter function public.upsert_today_story_loop_card_v3(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer,integer)
rename to upsert_today_story_loop_card_v3_before_monthly;
revoke all on function public.upsert_today_story_loop_card_v3_before_monthly(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer,integer) from public,anon,authenticated;
create function public.upsert_today_story_loop_card_v3(
  requested_artifact_revision uuid,requested_preview_path text,requested_scene_data_path text,
  requested_background_image_path text,requested_has_photo boolean,requested_has_drawing boolean,
  requested_has_text boolean,requested_text_layer_count integer,requested_text_character_count integer,
  requested_card_type text,requested_photo_count integer,requested_has_caption boolean,
  requested_layout_version integer,expected_revision integer default null
) returns table(story_loop_id uuid,story_loop_status text,card_id uuid,card_revision integer,question_generated boolean,daily_question_id uuid)
language plpgsql security definer set search_path='' as $$
declare card public.story_loop_cards%rowtype;
begin
  if auth.uid() is null then perform private.raise_app_error('auth_required'); end if;
  perform pg_advisory_xact_lock(hashtext('story_card_request'),hashtext(requested_artifact_revision::text));
  select saved.* into card from public.story_loop_cards saved
    join private.story_card_write_receipts receipt on receipt.card_id=saved.id
    where receipt.artifact_revision=requested_artifact_revision;
  if found and card.layout_version is distinct from requested_layout_version then perform private.raise_app_error('story_card_locked'); end if;
  return query select * from public.upsert_today_story_loop_card_v3_before_monthly(
    requested_artifact_revision,requested_preview_path,requested_scene_data_path,requested_background_image_path,
    requested_has_photo,requested_has_drawing,requested_has_text,requested_text_layer_count,requested_text_character_count,
    requested_card_type,requested_photo_count,requested_has_caption,requested_layout_version,expected_revision);
end;
$$;
revoke all on function public.upsert_today_story_loop_card_v3(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer,integer) from public,anon;
grant execute on function public.upsert_today_story_loop_card_v3(uuid,text,text,text,boolean,boolean,boolean,integer,integer,text,integer,boolean,integer,integer) to authenticated;

create function private.purge_expired_monthly_retrospective_content()
returns void language sql security definer set search_path='' as $$
  delete from private.monthly_retrospective_content where expires_at<=now();
$$;
revoke all on function private.purge_expired_monthly_retrospective_content() from public,anon,authenticated,service_role;
select cron.schedule('purge-expired-monthly-retrospectives','5 * * * *',
  'select private.purge_expired_monthly_retrospective_content();');

alter function public.get_ai_processing_job_context(uuid) rename to get_ai_processing_job_context_before_monthly;
revoke all on function public.get_ai_processing_job_context_before_monthly(uuid) from public,anon,authenticated,service_role;
create function public.get_ai_processing_job_context(requested_job_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare base jsonb; c public.couples%rowtype; reflections jsonb;
begin
  base := public.get_ai_processing_job_context_before_monthly(requested_job_id);
  select * into c from public.couples where id=(base->>'couple_id')::uuid and status='active' and user_b_id is not null;
  if not found or not private.have_all_couple_members_granted_ai_consent(c.id) then perform private.raise_app_error('ai_consent_required'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('month',to_char(item.month,'YYYY-MM'),
    'question',item.question,'answers',item.answers) order by item.month desc),'[]'::jsonb) into reflections from (
    select r.month,r.question,jsonb_agg(jsonb_build_object('answer_id',a.id,'user_id',a.user_id,
      'text',a.answer_text,'version',a.version) order by a.user_id) as answers
    from public.monthly_retrospectives r join public.monthly_retrospective_answers a on a.retrospective_id=r.id
    where r.couple_id=c.id and a.user_id in(c.user_a_id,c.user_b_id) and r.question is not null
    group by r.id,r.month,r.question having count(*)=2 order by r.month desc limit 3
  ) item;
  return base||jsonb_build_object('monthly_reflections',reflections);
end;
$$;
revoke all on function public.get_ai_processing_job_context(uuid) from public,anon,authenticated;
grant execute on function public.get_ai_processing_job_context(uuid) to service_role;

alter table public.safety_reports drop constraint safety_reports_target_type_check;
alter table public.safety_reports add constraint safety_reports_target_type_check check(target_type in(
  'partner','story_card','question_answer','recording','calendar_event','character','ai_question','ai_feedback',
  'ai_direct_answer','ai_proactive_suggestion','ai_memory','monthly_reflection_answer','ai_monthly_retrospective'));
alter function private.resolve_safety_report_target(uuid,uuid,uuid,text,text,text)
rename to resolve_safety_report_target_before_monthly;
create function private.resolve_safety_report_target(requested_reporter_user_id uuid,requested_couple_id uuid,
  requested_partner_user_id uuid,requested_target_type text,requested_target_id text,requested_content_snapshot text)
returns table(reported_user_id uuid,content_snapshot text)
language plpgsql security definer set search_path='' as $$
declare target_uuid uuid;
begin
  if requested_target_type not in('monthly_reflection_answer','ai_monthly_retrospective') then
    return query select * from private.resolve_safety_report_target_before_monthly(requested_reporter_user_id,
      requested_couple_id,requested_partner_user_id,requested_target_type,requested_target_id,requested_content_snapshot);
    return;
  end if;
  begin target_uuid:=requested_target_id::uuid;
  exception when invalid_text_representation then perform private.raise_app_error('safety_report_target_not_available'); end;
  if requested_target_type='monthly_reflection_answer' then
    return query select a.user_id,a.answer_text from public.monthly_retrospective_answers a
      join public.monthly_retrospectives r on r.id=a.retrospective_id
      where a.id=target_uuid and r.couple_id=requested_couple_id and a.user_id=requested_partner_user_id
        and r.available_until>now() and exists(select 1 from public.monthly_retrospective_answers mine
          where mine.retrospective_id=r.id and mine.user_id=requested_reporter_user_id);
  else
    return query select null::uuid,concat_ws(E'\n',r.question,cache.title,cache.summary)
      from public.monthly_retrospectives r left join private.monthly_retrospective_content cache
        on cache.retrospective_id=r.id and cache.expires_at>now()
      where r.id=target_uuid and r.couple_id=requested_couple_id and r.available_until>now()
        and (r.question_source='ai' or cache.status='ready');
  end if;
  if not found then perform private.raise_app_error('safety_report_target_not_available'); end if;
end;
$$;
revoke all on function private.resolve_safety_report_target(uuid,uuid,uuid,text,text,text),
  private.resolve_safety_report_target_before_monthly(uuid,uuid,uuid,text,text,text) from public,anon,authenticated;
create or replace function public.submit_safety_report(
  requested_target_type text,
  requested_target_id text,
  requested_reason text,
  requested_details text default null,
  requested_content_snapshot text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  partner_user_id uuid;
  normalized_target_type text := lower(btrim(requested_target_type));
  normalized_target_id text := btrim(requested_target_id);
  normalized_reason text := lower(btrim(requested_reason));
  normalized_details text := nullif(btrim(requested_details), '');
  target_context record;
  saved_report_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if normalized_target_type is null
    or normalized_target_type not in (
      'partner',
      'story_card',
      'question_answer',
      'recording',
      'calendar_event',
      'character',
      'ai_question',
      'ai_feedback',
      'ai_direct_answer',
      'ai_proactive_suggestion',
      'ai_memory',
      'monthly_reflection_answer',
      'ai_monthly_retrospective'
    )
  then
    perform private.raise_app_error('invalid_safety_report_target_type');
  end if;

  if normalized_target_id is null
    or char_length(normalized_target_id) not between 1 and 160
  then
    perform private.raise_app_error('invalid_safety_report_target');
  end if;

  if normalized_reason is null
    or normalized_reason not in (
      'inappropriate',
      'harassment',
      'privacy',
      'spam',
      'unsafe_ai',
      'other'
    )
  then
    perform private.raise_app_error('invalid_safety_report_reason');
  end if;

  if normalized_details is not null
    and char_length(normalized_details) > 1000
  then
    perform private.raise_app_error('safety_report_details_too_long');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  select resolved.reported_user_id, resolved.content_snapshot
  into target_context
  from private.resolve_safety_report_target(
    current_user_id,
    active_couple.id,
    partner_user_id,
    normalized_target_type,
    normalized_target_id,
    requested_content_snapshot
  ) as resolved;

  if not found then
    perform private.raise_app_error('safety_report_target_not_available');
  end if;

  insert into public.safety_reports (
    reporter_user_id,
    reported_user_id,
    couple_id,
    target_type,
    target_id,
    reason,
    details,
    content_snapshot
  )
  values (
    current_user_id,
    target_context.reported_user_id,
    active_couple.id,
    normalized_target_type,
    normalized_target_id,
    normalized_reason,
    normalized_details,
    target_context.content_snapshot
  )
  on conflict (reporter_user_id, target_type, target_id)
  do update
  set reported_user_id = excluded.reported_user_id,
      couple_id = excluded.couple_id,
      reason = excluded.reason,
      details = excluded.details,
      content_snapshot = excluded.content_snapshot
  returning id into saved_report_id;

  return saved_report_id;
end;
$$;

revoke execute on function public.submit_safety_report(
  text,
  text,
  text,
  text,
  text
) from public, anon;
grant execute on function public.submit_safety_report(
  text,
  text,
  text,
  text,
  text
) to authenticated;

