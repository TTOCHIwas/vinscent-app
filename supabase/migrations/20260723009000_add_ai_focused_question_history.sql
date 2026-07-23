create or replace function public.get_ai_focused_question_history()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum_version integer;
  partner_user_id uuid;
  history_json jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  if not private.has_ai_feature_entitlement(
    active_couple.id,
    'focused_questions'
  ) then
    perform private.raise_app_error('ai_focused_questions_locked');
  end if;

  select aiqc.version
  into active_curriculum_version
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if active_curriculum_version is null then
    perform private.raise_app_error('ai_curriculum_unavailable');
  end if;

  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  with completed_answer_rows as (
    select
      q.id as question_id,
      q.question_key,
      q.question_text,
      q.learning_domain,
      q.question_depth,
      q.curriculum_position,
      dqa.user_id,
      dqa.answer_text,
      dqa.answered_at
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    join public.daily_question_answers as dqa
      on dqa.daily_question_id = dq.id
    where dq.couple_id = active_couple.id
      and dq.status = 'completed'
      and q.curriculum_version = active_curriculum_version
      and dqa.user_id in (current_user_id, partner_user_id)

    union all

    select
      q.id,
      q.question_key,
      q.question_text,
      q.learning_domain,
      q.question_depth,
      q.curriculum_position,
      aifqa.user_id,
      aifqa.answer_text,
      aifqa.answered_at
    from public.ai_focused_questions as aifq
    join public.questions as q on q.id = aifq.question_id
    join public.ai_focused_question_answers as aifqa
      on aifqa.focused_question_id = aifq.id
    where aifq.couple_id = active_couple.id
      and aifq.status = 'completed'
      and q.curriculum_version = active_curriculum_version
      and aifqa.user_id in (current_user_id, partner_user_id)
  ),
  latest_answers as (
    select distinct on (
      answer.question_id,
      answer.user_id
    )
      answer.*
    from completed_answer_rows as answer
    order by
      answer.question_id,
      answer.user_id,
      answer.answered_at desc
  ),
  completed_pairs as (
    select
      answer.question_id,
      answer.question_key,
      answer.question_text,
      answer.learning_domain,
      answer.question_depth,
      answer.curriculum_position,
      max(answer.answer_text) filter (
        where answer.user_id = current_user_id
      ) as my_answer_text,
      max(answer.answer_text) filter (
        where answer.user_id = partner_user_id
      ) as partner_answer_text
    from latest_answers as answer
    group by
      answer.question_id,
      answer.question_key,
      answer.question_text,
      answer.learning_domain,
      answer.question_depth,
      answer.curriculum_position
    having count(distinct answer.user_id) = 2
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_id', pair.question_id,
        'question_key', pair.question_key,
        'question_text', pair.question_text,
        'learning_domain', pair.learning_domain,
        'question_depth', pair.question_depth,
        'curriculum_position', pair.curriculum_position,
        'my_answer_text', pair.my_answer_text,
        'partner_answer_text', pair.partner_answer_text
      )
      order by pair.curriculum_position, pair.question_id
    ),
    '[]'::jsonb
  )
  into history_json
  from completed_pairs as pair;

  return history_json;
end;
$$;

revoke execute on function public.get_ai_focused_question_history()
  from public, anon;
grant execute on function public.get_ai_focused_question_history()
  to authenticated;
