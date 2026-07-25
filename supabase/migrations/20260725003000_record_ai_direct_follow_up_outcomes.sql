alter table public.ai_user_questions
  add column follow_up_outcome text;

update public.ai_user_questions as aiuq
set follow_up_outcome = case
  when aiuq.result_kind = 'answered' then 'not_applicable'
  when exists (
    select 1
    from public.ai_user_question_follow_ups as aiuqfu
    where aiuqfu.user_question_id = aiuq.id
  ) then 'created'
  else 'legacy_unknown'
end
where aiuq.status = 'completed';

alter table public.ai_user_questions
  add constraint ai_user_questions_follow_up_outcome_check
    check (
      follow_up_outcome is null
      or follow_up_outcome in (
        'not_applicable',
        'created',
        'generation_failed',
        'candidate_invalid',
        'duplicate',
        'storage_rejected',
        'legacy_unknown'
      )
    );

alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_processing_run_before_direct_follow_up_outcomes_v15;

revoke execute on function
  public.succeed_ai_processing_run_before_direct_follow_up_outcomes_v15(
    uuid,
    jsonb,
    integer,
    integer,
    integer
  )
from public, anon, authenticated, service_role;

create or replace function public.succeed_ai_processing_run(
  requested_run_id uuid,
  requested_output jsonb,
  requested_input_token_count integer,
  requested_output_token_count integer,
  requested_latency_ms integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_run public.ai_runs%rowtype;
  completion_result boolean;
  normalized_answer_status text;
  normalized_generation_status text;
  follow_up_output jsonb;
  normalized_question_key text;
  normalized_question_text text;
  normalized_category text;
  normalized_mood text;
  normalized_rationale text;
  candidate_is_valid boolean := false;
  resolved_follow_up_outcome text;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found or target_run.task <> 'answer_user_question' then
    return
      public.succeed_ai_processing_run_before_direct_follow_up_outcomes_v15(
        requested_run_id,
        requested_output,
        requested_input_token_count,
        requested_output_token_count,
        requested_latency_ms
      );
  end if;

  normalized_answer_status := coalesce(
    nullif(btrim(requested_output->>'answer_status'), ''),
    'answered'
  );
  follow_up_output := requested_output->'follow_up_question';
  normalized_generation_status := nullif(
    btrim(requested_output->>'follow_up_generation_status'),
    ''
  );
  if normalized_generation_status is null then
    normalized_generation_status := case
      when normalized_answer_status = 'answered' then 'not_applicable'
      when jsonb_typeof(follow_up_output) = 'object' then 'generated'
      else 'generation_failed'
    end;
  end if;

  completion_result :=
    public.succeed_ai_processing_run_before_direct_follow_up_outcomes_v15(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );

  if completion_result is not true then
    return false;
  end if;

  if normalized_answer_status = 'answered' then
    resolved_follow_up_outcome := 'not_applicable';
  elsif normalized_generation_status = 'generation_failed' then
    resolved_follow_up_outcome := 'generation_failed';
  elsif normalized_generation_status = 'candidate_invalid' then
    resolved_follow_up_outcome := 'candidate_invalid';
  elsif normalized_generation_status <> 'generated'
    or jsonb_typeof(follow_up_output) <> 'object'
  then
    resolved_follow_up_outcome := 'candidate_invalid';
  else
    normalized_question_key := btrim(
      follow_up_output->>'question_key'
    );
    normalized_question_text := btrim(
      follow_up_output->>'question_text'
    );
    normalized_category := btrim(follow_up_output->>'category');
    normalized_mood := nullif(btrim(follow_up_output->>'mood'), '');
    normalized_rationale := btrim(follow_up_output->>'rationale');

    candidate_is_valid :=
      normalized_question_key is not null
      and normalized_question_key
        ~ '^direct_follow_up_[a-z0-9_]+_[a-z0-9]{8}$'
      and char_length(normalized_question_key) between 1 and 120
      and private.is_safe_ai_direct_follow_up_question(
        normalized_question_text
      )
      and normalized_category is not null
      and char_length(normalized_category) between 1 and 100
      and (
        normalized_mood is null
        or char_length(normalized_mood) between 1 and 100
      )
      and normalized_rationale is not null
      and char_length(normalized_rationale) between 1 and 500;

    if not candidate_is_valid then
      resolved_follow_up_outcome := 'candidate_invalid';
    elsif exists (
      select 1
      from public.ai_user_question_follow_ups as aiuqfu
      where aiuqfu.user_question_id = target_run.user_question_id
    ) then
      resolved_follow_up_outcome := 'created';
    elsif exists (
      select 1
      from public.ai_user_question_follow_ups as aiuqfu
      where aiuqfu.couple_id = target_run.couple_id
        and aiuqfu.status in ('pending', 'approved')
        and private.normalize_ai_question_text(aiuqfu.question_text) =
          private.normalize_ai_question_text(normalized_question_text)
    )
    or exists (
      select 1
      from public.questions as q
      where private.normalize_ai_question_text(q.question_text) =
          private.normalize_ai_question_text(normalized_question_text)
        and (
          q.personalized_for_couple_id = target_run.couple_id
          or exists (
            select 1
            from public.daily_questions as dq
            where dq.couple_id = target_run.couple_id
              and dq.question_id = q.id
          )
          or exists (
            select 1
            from public.ai_focused_questions as aifq
            where aifq.couple_id = target_run.couple_id
              and aifq.question_id = q.id
          )
        )
    ) then
      resolved_follow_up_outcome := 'duplicate';
    else
      resolved_follow_up_outcome := 'storage_rejected';
    end if;
  end if;

  update public.ai_user_questions
  set follow_up_outcome = resolved_follow_up_outcome
  where id = target_run.user_question_id;

  return true;
end;
$$;

revoke execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;
grant execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) to service_role;
