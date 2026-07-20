begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(25);

select ok(
  to_regclass('public.ai_question_curricula') is not null,
  'ai_question_curricula exists'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'questions'
      and column_name = 'question_key'
  ),
  'questions has a stable question_key'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'questions'
      and column_name = 'curriculum_version'
  ),
  'questions has curriculum_version'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'questions'
      and column_name = 'learning_domain'
  ),
  'questions has learning_domain'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'questions'
      and column_name = 'prompt_angle'
  ),
  'questions has prompt_angle'
);
select is(
  (
    select count(*)
    from public.questions
    where curriculum_version = 1
      and is_active
  ),
  24::bigint,
  'foundation curriculum has exactly 24 active questions'
);
select is(
  (
    select count(distinct learning_domain)
    from public.questions
    where curriculum_version = 1
      and is_active
  ),
  6::bigint,
  'foundation curriculum covers six learning domains'
);
select ok(
  not exists (
    select learning_domain
    from public.questions
    where curriculum_version = 1
      and is_active
    group by learning_domain
    having count(*) <> 4
  ),
  'each learning domain has four questions'
);

select ok(to_regclass('public.ai_user_consents') is not null, 'ai_user_consents exists');
select ok(to_regclass('public.ai_processing_jobs') is not null, 'ai_processing_jobs exists');
select ok(to_regclass('public.ai_runs') is not null, 'ai_runs exists');
select ok(to_regclass('public.ai_memories') is not null, 'ai_memories exists');
select ok(to_regclass('public.ai_memory_evidence') is not null, 'ai_memory_evidence exists');
select ok(to_regclass('public.ai_memory_confirmations') is not null, 'ai_memory_confirmations exists');
select ok(to_regclass('public.ai_question_feedbacks') is not null, 'ai_question_feedbacks exists');
select ok(to_regclass('public.ai_question_recommendations') is not null, 'ai_question_recommendations exists');

select ok(
  to_regprocedure('public.set_my_ai_consent(boolean,text)') is not null,
  'set_my_ai_consent exists'
);
select ok(
  to_regprocedure('public.get_ai_learning_progress()') is not null,
  'get_ai_learning_progress exists'
);
select ok(
  to_regprocedure('public.list_ai_memories()') is not null,
  'list_ai_memories exists'
);
select ok(
  to_regprocedure('public.confirm_ai_memory(uuid,text)') is not null,
  'confirm_ai_memory exists'
);
select ok(
  to_regprocedure('public.claim_ai_processing_jobs(text,integer)') is not null,
  'claim_ai_processing_jobs exists'
);
select ok(
  to_regprocedure('public.complete_ai_processing_job(uuid,text,text)') is not null,
  'complete_ai_processing_job exists'
);
select ok(
  to_regprocedure('public.record_ai_question_recommendation(uuid,uuid,uuid,text)') is not null,
  'record_ai_question_recommendation exists'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.daily_questions'::regclass
      and tgname = 'daily_questions_enqueue_ai_learning_jobs'
      and not tgisinternal
  ),
  'completed questions enqueue AI learning jobs'
);
select ok(
  to_regprocedure(
    'private.assign_question_to_story_loop(public.couples,public.daily_story_loops)'
  ) is not null,
  'story loop question assignment remains available'
);

select * from finish();
rollback;
