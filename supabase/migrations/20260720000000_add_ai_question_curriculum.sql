create table public.ai_question_curricula (
  version integer primary key,
  curriculum_key text not null unique,
  question_count integer not null,
  status text not null default 'draft',
  activated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_question_curricula_version_check
    check (version >= 1),
  constraint ai_question_curricula_key_check
    check (char_length(btrim(curriculum_key)) between 1 and 100),
  constraint ai_question_curricula_question_count_check
    check (question_count >= 1),
  constraint ai_question_curricula_status_check
    check (status in ('draft', 'active', 'retired')),
  constraint ai_question_curricula_activation_check
    check (
      (status = 'active' and activated_at is not null)
      or status <> 'active'
    )
);

create unique index ai_question_curricula_one_active_idx
  on public.ai_question_curricula ((status))
  where status = 'active';

alter table public.ai_question_curricula enable row level security;

create trigger ai_question_curricula_set_updated_at
  before update on public.ai_question_curricula
  for each row
  execute function public.set_updated_at();

create policy "ai_question_curricula_select_active_authenticated"
  on public.ai_question_curricula
  for select
  to authenticated
  using (status = 'active');

alter table public.questions
  add column question_key text,
  add column curriculum_version integer
    references public.ai_question_curricula(version) on delete restrict,
  add column curriculum_position integer,
  add column learning_domain text,
  add column prompt_angle text,
  add constraint questions_question_key_check
    check (
      question_key is null
      or char_length(btrim(question_key)) between 1 and 120
    ),
  add constraint questions_curriculum_position_check
    check (curriculum_position is null or curriculum_position >= 1),
  add constraint questions_learning_domain_check
    check (
      learning_domain is null
      or learning_domain in (
        'personal_values',
        'emotional_support',
        'communication_repair',
        'daily_life',
        'relationship_strength',
        'future_boundaries'
      )
    ),
  add constraint questions_prompt_angle_check
    check (
      prompt_angle is null
      or prompt_angle in (
        'preference',
        'lived_experience',
        'scenario',
        'current_need'
      )
    ),
  add constraint questions_curriculum_metadata_check
    check (
      (
        curriculum_version is null
        and curriculum_position is null
        and learning_domain is null
        and prompt_angle is null
      )
      or (
        source = 'curated'
        and question_key is not null
        and curriculum_version is not null
        and curriculum_position is not null
        and learning_domain is not null
        and prompt_angle is not null
      )
    );

create unique index questions_question_key_unique
  on public.questions (question_key)
  where question_key is not null;

create unique index questions_curriculum_position_unique
  on public.questions (curriculum_version, curriculum_position)
  where curriculum_version is not null;

insert into public.ai_question_curricula (
  version,
  curriculum_key,
  question_count,
  status,
  activated_at
)
values (
  1,
  'foundation-v1',
  24,
  'active',
  now()
);

update public.questions
set is_active = false
where source = 'curated'
  and curriculum_version is null
  and is_active = true;

insert into public.questions (
  source,
  question_key,
  question_text,
  category,
  mood,
  curriculum_version,
  curriculum_position,
  learning_domain,
  prompt_angle,
  is_active
)
values
  (
    'curated',
    'foundation_v1_personal_values_01',
    '요즘 네가 가장 소중하게 지키고 싶은 건 뭐야?',
    'personal_values',
    'thoughtful',
    1,
    1,
    'personal_values',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_personal_values_02',
    '힘든 선택을 할 때 가장 중요하게 생각하는 기준은 뭐야?',
    'personal_values',
    'thoughtful',
    1,
    2,
    'personal_values',
    'scenario',
    true
  ),
  (
    'curated',
    'foundation_v1_personal_values_03',
    '아무 일정도 없는 하루가 생기면 어떻게 보내고 싶어?',
    'personal_values',
    'calm',
    1,
    3,
    'personal_values',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_personal_values_04',
    '요즘 예전과 달라졌다고 느끼는 생각이나 가치가 있어?',
    'personal_values',
    'thoughtful',
    1,
    4,
    'personal_values',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_emotional_support_01',
    '기분이 가라앉았을 때 상대가 어떻게 곁에 있어주면 가장 힘이 돼?',
    'emotional_support',
    'caring',
    1,
    5,
    'emotional_support',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_emotional_support_02',
    '상대에게 사랑받고 있다고 가장 크게 느끼는 순간은 언제야?',
    'emotional_support',
    'warm',
    1,
    6,
    'emotional_support',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_emotional_support_03',
    '고마운 마음을 표현할 때 가장 자연스러운 방법은 뭐야?',
    'emotional_support',
    'warm',
    1,
    7,
    'emotional_support',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_emotional_support_04',
    '요즘 상대에게 받고 싶은 작은 배려가 있다면?',
    'emotional_support',
    'caring',
    1,
    8,
    'emotional_support',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_communication_repair_01',
    '생각이 다를 때 어떤 대화를 하면 이해받았다고 느껴?',
    'communication_repair',
    'thoughtful',
    1,
    9,
    'communication_repair',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_communication_repair_02',
    '다툰 뒤 마음을 다시 열게 되는 상대의 행동은 뭐야?',
    'communication_repair',
    'caring',
    1,
    10,
    'communication_repair',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_communication_repair_03',
    '서운할 때 바로 말하는 편이야, 생각을 정리할 시간이 필요한 편이야?',
    'communication_repair',
    'thoughtful',
    1,
    11,
    'communication_repair',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_communication_repair_04',
    '우리 대화에서 앞으로도 지키고 싶은 좋은 방식은 뭐야?',
    'communication_repair',
    'hopeful',
    1,
    12,
    'communication_repair',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_daily_life_01',
    '함께 있을 때 가장 편안한 일상의 모습은 어떤 장면이야?',
    'daily_life',
    'calm',
    1,
    13,
    'daily_life',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_daily_life_02',
    '혼자만의 시간이 필요할 때 상대가 어떻게 알아주면 좋겠어?',
    'daily_life',
    'thoughtful',
    1,
    14,
    'daily_life',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_daily_life_03',
    '둘이 함께 정하면 좋겠다고 느끼는 생활 습관이 있어?',
    'daily_life',
    'practical',
    1,
    15,
    'daily_life',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_daily_life_04',
    '최근 함께 해보고 싶은 소소한 활동은 뭐야?',
    'daily_life',
    'playful',
    1,
    16,
    'daily_life',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_relationship_strength_01',
    '우리 사이가 단단하다고 느꼈던 순간은 언제야?',
    'relationship_strength',
    'warm',
    1,
    17,
    'relationship_strength',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_relationship_strength_02',
    '상대의 어떤 모습 때문에 처음 마음이 갔어?',
    'relationship_strength',
    'warm',
    1,
    18,
    'relationship_strength',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_relationship_strength_03',
    '함께 겪어서 더 가까워졌다고 느낀 일이 있어?',
    'relationship_strength',
    'thoughtful',
    1,
    19,
    'relationship_strength',
    'lived_experience',
    true
  ),
  (
    'curated',
    'foundation_v1_relationship_strength_04',
    '우리 관계에서 앞으로도 잃고 싶지 않은 장점은 뭐야?',
    'relationship_strength',
    'hopeful',
    1,
    20,
    'relationship_strength',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_future_boundaries_01',
    '앞으로 1년 동안 둘이 함께 이루고 싶은 작은 목표는 뭐야?',
    'future_boundaries',
    'hopeful',
    1,
    21,
    'future_boundaries',
    'current_need',
    true
  ),
  (
    'curated',
    'foundation_v1_future_boundaries_02',
    '서로의 선택을 존중하기 위해 꼭 지키고 싶은 선은 뭐야?',
    'future_boundaries',
    'thoughtful',
    1,
    22,
    'future_boundaries',
    'preference',
    true
  ),
  (
    'curated',
    'foundation_v1_future_boundaries_03',
    '바쁜 시기에도 우리 관계를 위해 남겨두고 싶은 시간은 언제야?',
    'future_boundaries',
    'practical',
    1,
    23,
    'future_boundaries',
    'scenario',
    true
  ),
  (
    'curated',
    'foundation_v1_future_boundaries_04',
    '우리의 미래를 생각할 때 가장 기대되는 장면은 뭐야?',
    'future_boundaries',
    'hopeful',
    1,
    24,
    'future_boundaries',
    'scenario',
    true
  );
