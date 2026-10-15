create function private.monthly_retrospective_gallery(target_couple_id uuid, target_month date)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', card.id, 'date', card.couple_date,
    'preview_path', card.preview_path, 'author_user_id', card.author_user_id,
    'card_type', card.card_type, 'layout_version', card.layout_version,
    'aspect_ratio', case
      when card.card_type = 'four_cut_grid' and card.layout_version = 2 then 20.0/27
      when card.card_type = 'four_cut_strip' and card.layout_version = 2 then 8.0/21
      when card.card_type = 'four_cut_strip' then 0.4 else 0.8 end
  ) order by card.couple_date, card.author_user_id), '[]'::jsonb)
  from (
    select card.*, row_number() over (
      partition by card.couple_date, card.author_user_id
      order by card.is_featured desc, card.submitted_at desc, card.id desc
    ) as position
    from public.story_loop_cards card
    where card.couple_id = target_couple_id
      and card.couple_date >= target_month
      and card.couple_date < (target_month + interval '1 month')::date
  ) card where card.position = 1;
$$;

revoke all on function private.monthly_retrospective_gallery(uuid,date) from public, anon, authenticated;

create or replace function private.monthly_retrospective_data(target_couple_id uuid, target_user_id uuid)
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
      'author_user_id',card.author_user_id,'card_type',card.card_type,'layout_version',card.layout_version,'aspect_ratio',case
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
    'gallery',private.monthly_retrospective_gallery(c.id,m),'moments',moments,'conversation',conversation,
    'reflection',case when r.id is null then null else jsonb_build_object('id',r.id,'question',r.question,
      'source',r.question_source,'my_answer',mine.answer_text,'my_answer_id',mine.id,
      'partner_answer',case when mine.id is not null then partner.answer_text else null end,
      'partner_answer_id',case when mine.id is not null then partner.id else null end,
      'partner_answer_exists',partner.id is not null,'version',coalesce(mine.version,0)) end);
end;
$$;

