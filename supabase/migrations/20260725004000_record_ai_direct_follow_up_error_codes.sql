alter table public.ai_user_questions
  add column follow_up_error_code text;

update public.ai_user_questions as aiuq
set follow_up_error_code = case aiuq.follow_up_outcome
  when 'generation_failed' then 'generation_reason_unavailable'
  when 'candidate_invalid' then 'validation_reason_unavailable'
  when 'storage_rejected' then 'storage_reason_unavailable'
  else null
end
where aiuq.follow_up_outcome in (
  'generation_failed',
  'candidate_invalid',
  'storage_rejected'
);

alter table public.ai_user_questions
  add constraint ai_user_questions_follow_up_error_code_check
    check (
      follow_up_error_code is null
      or (
        char_length(follow_up_error_code) between 1 and 160
        and follow_up_error_code ~ '^[a-z0-9_]+$'
      )
    );

alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_run_before_follow_up_errors_v16;

revoke execute on function
  public.succeed_ai_run_before_follow_up_errors_v16(
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
  normalized_error_code text;
  default_error_code text;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found or target_run.task <> 'answer_user_question' then
    return
      public.succeed_ai_run_before_follow_up_errors_v16(
        requested_run_id,
        requested_output,
        requested_input_token_count,
        requested_output_token_count,
        requested_latency_ms
      );
  end if;

  completion_result :=
    public.succeed_ai_run_before_follow_up_errors_v16(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );

  if completion_result is not true then
    return false;
  end if;

  normalized_answer_status := coalesce(
    nullif(btrim(requested_output->>'answer_status'), ''),
    'answered'
  );
  normalized_generation_status := nullif(
    btrim(requested_output->>'follow_up_generation_status'),
    ''
  );
  if normalized_generation_status is null then
    normalized_generation_status := case
      when normalized_answer_status = 'answered' then 'not_applicable'
      when jsonb_typeof(requested_output->'follow_up_question') = 'object'
        then 'generated'
      else 'generation_failed'
    end;
  end if;
  normalized_error_code := lower(
    nullif(btrim(requested_output->>'follow_up_error_code'), '')
  );

  if normalized_error_code is not null
    and (
      char_length(normalized_error_code) > 160
      or normalized_error_code !~ '^[a-z0-9_]+$'
    )
  then
    normalized_error_code := null;
  end if;

  if normalized_answer_status = 'answered'
    or normalized_generation_status in ('not_applicable', 'generated')
  then
    normalized_error_code := null;
  else
    default_error_code := case normalized_generation_status
      when 'generation_failed' then 'model_generation_failed'
      when 'candidate_invalid' then 'candidate_validation_failed'
      when 'duplicate' then 'duplicate_question'
      else 'candidate_validation_failed'
    end;
    normalized_error_code := coalesce(
      normalized_error_code,
      default_error_code
    );
  end if;

  update public.ai_user_questions
  set
    follow_up_outcome = case
      when normalized_answer_status = 'answered' then 'not_applicable'
      when normalized_generation_status = 'duplicate' then 'duplicate'
      else follow_up_outcome
    end,
    follow_up_error_code = normalized_error_code
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
