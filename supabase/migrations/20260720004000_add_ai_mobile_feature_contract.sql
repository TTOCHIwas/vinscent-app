create or replace function public.get_ai_learning_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  learning_progress jsonb;
  visible_memories jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  learning_progress := public.get_ai_learning_progress();

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_id', memories.memory_id,
        'scope', memories.memory_scope,
        'subject_user_id', memories.subject_user_id,
        'kind', memories.memory_kind,
        'statement', memories.memory_statement,
        'confidence', memories.memory_confidence,
        'state', memories.memory_state,
        'my_decision', my_confirmation.decision,
        'confirmed_count', coalesce(confirmations.confirmed_count, 0),
        'required_confirmation_count', case
          when memories.memory_scope = 'personal' then 1
          else 2
        end,
        'can_confirm',
          (learning_progress->>'ai_enabled')::boolean
          and memories.memory_state = 'pending'
          and (
            memories.memory_scope = 'couple'
            or memories.subject_user_id = current_user_id
          )
          and my_confirmation.decision is distinct from 'confirmed',
        'evidence_count', cardinality(memories.evidence_answer_ids),
        'created_at', memories.memory_created_at,
        'updated_at', memories.memory_updated_at
      )
      order by memories.memory_updated_at desc, memories.memory_id
    ),
    '[]'::jsonb
  )
  into visible_memories
  from public.list_ai_memories() as memories
  left join lateral (
    select aimc.decision
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = memories.memory_id
      and aimc.user_id = current_user_id
  ) as my_confirmation on true
  left join lateral (
    select
      (
        count(*) filter (
          where aimc.decision = 'confirmed'
        )
      )::integer as confirmed_count
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = memories.memory_id
  ) as confirmations on true;

  return jsonb_build_object(
    'progress', learning_progress,
    'memories', visible_memories
  );
end;
$$;

create or replace function public.get_ai_question_feedback(
  requested_daily_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  feedback jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_daily_question_id is null then
    perform private.raise_app_error('invalid_daily_question');
  end if;

  select jsonb_build_object(
    'daily_question_id', aiqf.daily_question_id,
    'feedback_text', aiqf.feedback_text,
    'published_at', aiqf.published_at
  )
  into feedback
  from public.ai_question_feedbacks as aiqf
  join public.daily_questions as dq
    on dq.id = aiqf.daily_question_id
  where aiqf.daily_question_id = requested_daily_question_id
    and aiqf.state = 'published'
    and aiqf.safety_status = 'passed'
    and dq.status = 'completed'
    and private.is_readable_couple_member(
      aiqf.couple_id,
      current_user_id
    );

  return feedback;
end;
$$;

revoke execute on function public.get_ai_learning_dashboard()
  from public, anon;
revoke execute on function public.get_ai_question_feedback(uuid)
  from public, anon;

grant execute on function public.get_ai_learning_dashboard()
  to authenticated;
grant execute on function public.get_ai_question_feedback(uuid)
  to authenticated;
