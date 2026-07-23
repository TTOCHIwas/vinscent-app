alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_processing_run_before_memory_v6;

revoke execute on function public.succeed_ai_processing_run_before_memory_v6(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated, service_role;

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
  output_item jsonb;
  output_memory public.ai_memories%rowtype;
  output_scope text;
  output_subject_user_id text;
  output_kind text;
  output_domain text;
  output_evidence_type text;
  output_statement text;
  previous_daily_evidence jsonb := '[]'::jsonb;
  previous_focused_evidence jsonb := '[]'::jsonb;
  completion_result boolean;
  repeated_question_count integer;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found or target_run.task <> 'extract_memories' then
    return public.succeed_ai_processing_run_before_memory_v6(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );
  end if;

  if requested_output is null
    or jsonb_typeof(requested_output) <> 'object'
    or jsonb_typeof(requested_output->'memories') <> 'array'
    or jsonb_array_length(requested_output->'memories') > 3
  then
    perform private.raise_app_error('invalid_ai_memory_output');
  end if;

  if exists (
    select 1
    from jsonb_array_elements(requested_output->'memories') as memory(value)
    where btrim(memory.value->>'scope') = 'personal'
    group by btrim(memory.value->>'subject_user_id')
    having count(*) > 1
  ) or (
    select count(*)
    from jsonb_array_elements(requested_output->'memories') as memory(value)
    where btrim(memory.value->>'scope') = 'couple'
  ) > 1 then
    perform private.raise_app_error('invalid_ai_memory_output');
  end if;

  for output_item in
    select value
    from jsonb_array_elements(requested_output->'memories')
  loop
    output_scope := btrim(output_item->>'scope');
    output_subject_user_id := nullif(
      btrim(output_item->>'subject_user_id'),
      ''
    );
    output_kind := btrim(output_item->>'kind');
    output_domain := btrim(output_item->>'learning_domain');
    output_evidence_type := btrim(output_item->>'evidence_type');
    output_statement := btrim(output_item->>'statement');

    if output_statement is null
      or output_statement ~* (
        '(파트너[[:space:]]*[ab]'
        || '|partner[_[:space:]-]?[ab]'
        || '|사용자[[:space:]]*[ab]'
        || '|(첫|두)[[:space:]]*번째[[:space:]]*(사용자|사람|파트너)'
        || '|[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12})'
      )
      or output_statement ~ (
        '(습니다|ㅂ니다|합니다|입니다|됩니다|드립니다|바랍니다'
        || '|한다|이다|된다|있다|없다)[.!?]?$'
      )
      or right(output_statement, 1) = '.'
      or (
        output_scope = 'personal'
        and jsonb_array_length(
          output_item->'evidence_answer_ids'
        ) <> 1
      )
      or (
        output_scope = 'couple'
        and jsonb_array_length(
          output_item->'evidence_answer_ids'
        ) <> 2
      )
    then
      perform private.raise_app_error('invalid_ai_memory_output');
    end if;

    if output_evidence_type = 'repeated_pattern' then
      select aim.*
      into output_memory
      from public.ai_memories as aim
      where aim.couple_id = target_run.couple_id
        and aim.memory_key = btrim(output_item->>'memory_key')
        and aim.scope = output_scope
        and coalesce(aim.subject_user_id::text, '') =
          coalesce(output_subject_user_id, '')
        and aim.kind = output_kind
        and aim.learning_domain = output_domain
        and aim.state not in ('rejected', 'superseded');

      if not found then
        perform private.raise_app_error('invalid_ai_memory_evidence');
      end if;

      select count(distinct evidence.question_instance_id)::integer
      into repeated_question_count
      from (
        select dqa.daily_question_id as question_instance_id
        from public.ai_memory_evidence as aime
        join public.daily_question_answers as dqa
          on dqa.id = aime.answer_id
        where aime.memory_id = output_memory.id

        union

        select aifqa.focused_question_id
        from public.ai_focused_memory_evidence as aifme
        join public.ai_focused_question_answers as aifqa
          on aifqa.id = aifme.answer_id
        where aifme.memory_id = output_memory.id
      ) as evidence;

      if repeated_question_count < 1 then
        perform private.raise_app_error('invalid_ai_memory_evidence');
      end if;
    end if;
  end loop;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_id', aime.memory_id,
        'answer_id', aime.answer_id,
        'relevance', aime.relevance
      )
    ),
    '[]'::jsonb
  )
  into previous_daily_evidence
  from public.ai_memory_evidence as aime
  join public.ai_memories as aim on aim.id = aime.memory_id
  where aim.couple_id = target_run.couple_id
    and exists (
      select 1
      from jsonb_array_elements(
        requested_output->'memories'
      ) as memory(value)
      where aim.memory_key = btrim(memory.value->>'memory_key')
        and aim.scope = btrim(memory.value->>'scope')
        and coalesce(aim.subject_user_id::text, '') = coalesce(
          nullif(btrim(memory.value->>'subject_user_id'), ''),
          ''
        )
        and aim.kind = btrim(memory.value->>'kind')
        and aim.learning_domain =
          btrim(memory.value->>'learning_domain')
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_id', aifme.memory_id,
        'answer_id', aifme.answer_id,
        'relevance', aifme.relevance
      )
    ),
    '[]'::jsonb
  )
  into previous_focused_evidence
  from public.ai_focused_memory_evidence as aifme
  join public.ai_memories as aim on aim.id = aifme.memory_id
  where aim.couple_id = target_run.couple_id
    and exists (
      select 1
      from jsonb_array_elements(
        requested_output->'memories'
      ) as memory(value)
      where aim.memory_key = btrim(memory.value->>'memory_key')
        and aim.scope = btrim(memory.value->>'scope')
        and coalesce(aim.subject_user_id::text, '') = coalesce(
          nullif(btrim(memory.value->>'subject_user_id'), ''),
          ''
        )
        and aim.kind = btrim(memory.value->>'kind')
        and aim.learning_domain =
          btrim(memory.value->>'learning_domain')
    );

  completion_result :=
    public.succeed_ai_processing_run_before_memory_v6(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );

  if completion_result is not true then
    return completion_result;
  end if;

  insert into public.ai_memory_evidence (
    memory_id,
    answer_id,
    relevance
  )
  select
    (evidence.value->>'memory_id')::uuid,
    (evidence.value->>'answer_id')::uuid,
    (evidence.value->>'relevance')::numeric
  from jsonb_array_elements(previous_daily_evidence) as evidence(value)
  on conflict on constraint ai_memory_evidence_pkey do update
  set relevance = excluded.relevance;

  insert into public.ai_focused_memory_evidence (
    memory_id,
    answer_id,
    relevance
  )
  select
    (evidence.value->>'memory_id')::uuid,
    (evidence.value->>'answer_id')::uuid,
    (evidence.value->>'relevance')::numeric
  from jsonb_array_elements(previous_focused_evidence) as evidence(value)
  on conflict on constraint ai_focused_memory_evidence_pkey do update
  set relevance = excluded.relevance;

  for output_item in
    select value
    from jsonb_array_elements(requested_output->'memories')
    where btrim(value->>'evidence_type') = 'repeated_pattern'
  loop
    select aim.*
    into output_memory
    from public.ai_memories as aim
    where aim.couple_id = target_run.couple_id
      and aim.memory_key = btrim(output_item->>'memory_key');

    select count(distinct evidence.question_instance_id)::integer
    into repeated_question_count
    from (
      select dqa.daily_question_id as question_instance_id
      from public.ai_memory_evidence as aime
      join public.daily_question_answers as dqa
        on dqa.id = aime.answer_id
      where aime.memory_id = output_memory.id

      union

      select aifqa.focused_question_id
      from public.ai_focused_memory_evidence as aifme
      join public.ai_focused_question_answers as aifqa
        on aifqa.id = aifme.answer_id
      where aifme.memory_id = output_memory.id
    ) as evidence;

    if repeated_question_count < 2 then
      perform private.raise_app_error('invalid_ai_memory_evidence');
    end if;
  end loop;

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
