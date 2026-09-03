alter table public.questions
  add column fallback_position integer;

alter table public.questions
  add constraint questions_fallback_position_check
    check (
      fallback_position is null
      or (
        fallback_position >= 1
        and source = 'curated'
        and question_key is not null
        and curriculum_version is null
      )
    );

create unique index questions_fallback_position_unique
  on public.questions (fallback_position)
  where fallback_position is not null;

create index daily_questions_couple_question_idx
  on public.daily_questions (couple_id, question_id);

insert into public.questions (
  source,
  question_key,
  question_text,
  category,
  is_active,
  fallback_position
)
values
  ('curated', 'fallback_v1_general_personal_values_01', '새로운 걸 배울 때 설명부터 보는 편이야, 직접 해보는 편이야?', 'personal_values', true, 10),
  ('curated', 'fallback_v1_memory_childhood_home_01', '어릴 때 가장 자주 놀던 곳은 어디였어?', 'memory_childhood_home', true, 20),
  ('curated', 'fallback_v1_general_emotional_support_01', '애정 표현은 자주 조금씩 받는 것과 가끔 크게 받는 것 중 뭐가 좋아?', 'emotional_support', true, 30),
  ('curated', 'fallback_v1_relationship_personal_world_01', '어릴 때 보물처럼 아끼던 물건은 뭐였어?', 'relationship_personal_world', true, 40),
  ('curated', 'fallback_v1_general_communication_repair_01', '짧은 이야기는 전화와 메시지 중 뭐가 더 편해?', 'communication_repair', true, 50),
  ('curated', 'fallback_v1_memory_school_teachers_01', '학교 다닐 때 쉬는 시간에는 주로 뭘 했어?', 'memory_school_teachers', true, 60),
  ('curated', 'fallback_v1_general_daily_life_01', '간식은 달콤한 것과 짭짤한 것 중 뭐가 좋아?', 'daily_life', true, 70),
  ('curated', 'fallback_v1_relationship_attraction_change_01', '처음 만난 날, 상대의 목소리나 말투는 어떻게 기억나?', 'relationship_attraction_change', true, 80),
  ('curated', 'fallback_v1_general_relationship_strength_01', '둘의 추억은 사진과 영상 중 어떤 걸로 더 많이 남기고 싶어?', 'relationship_strength', true, 90),
  ('curated', 'fallback_v1_memory_friends_01', '예전에 친했던 친구와 처음 가까워진 계기를 기억해?', 'memory_friends', true, 100),
  ('curated', 'fallback_v1_general_future_boundaries_01', '서로의 일정은 자세히 아는 것과 중요한 것만 아는 것 중 뭐가 편해?', 'future_boundaries', true, 110),
  ('curated', 'fallback_v1_relationship_shared_memories_01', '둘이 함께한 날 중 제목을 붙여보고 싶은 하루는 언제야?', 'relationship_shared_memories', true, 120),
  ('curated', 'fallback_v1_general_personal_values_02', '작은 일을 꾸준히 하는 것과 한 번에 몰입하는 것 중 어느 쪽이 잘 맞아?', 'personal_values', true, 130),
  ('curated', 'fallback_v1_memory_media_play_01', '어릴 때 몇 번이고 다시 본 영화나 만화가 있어?', 'memory_media_play', true, 140),
  ('curated', 'fallback_v1_general_emotional_support_02', '상대가 바쁜 날에는 짧게 연락하는 것과 나중에 길게 이야기하는 것 중 뭐가 좋아?', 'emotional_support', true, 150),
  ('curated', 'fallback_v1_relationship_partner_perspective_01', '상대가 자주 쓰는 말투를 다정하게 흉내 내서 오늘 하루를 정리해봐.', 'relationship_partner_perspective', true, 160),
  ('curated', 'fallback_v1_general_communication_repair_02', '지금 상대와 가볍게 이야기해보고 싶은 주제가 있어?', 'communication_repair', true, 170),
  ('curated', 'fallback_v1_memory_landscape_travel_01', '오래전에 본 풍경 중 아직도 선명한 건 어떤 모습이야?', 'memory_landscape_travel', true, 180),
  ('curated', 'fallback_v1_general_daily_life_02', '영화는 집에서 편하게 보는 것과 영화관에서 보는 것 중 뭐가 좋아?', 'daily_life', true, 190),
  ('curated', 'fallback_v1_relationship_care_requests_01', '상대가 계속 해줬으면 하는 행동 하나와 그 이유를 적어봐.', 'relationship_care_requests', true, 200),
  ('curated', 'fallback_v1_general_relationship_strength_02', '상대에게 칭찬을 들을 때 귀엽다는 말과 멋지다는 말 중 뭐가 더 좋아?', 'relationship_strength', true, 210),
  ('curated', 'fallback_v1_memory_habits_language_play_01', '어릴 때 심심하면 가장 자주 하던 놀이는 뭐였어?', 'memory_habits_language_play', true, 220),
  ('curated', 'fallback_v1_general_future_boundaries_02', '혼자 쉬는 날과 함께 노는 날은 미리 나누는 게 좋아, 그때그때 정하는 게 좋아?', 'future_boundaries', true, 230),
  ('curated', 'fallback_v1_relationship_boundaries_01', '장난으로도 편하게 넘기기 어려운 말이나 행동은 어떤 거야?', 'relationship_boundaries', true, 240),
  ('curated', 'fallback_v1_general_personal_values_03', '지금 더 자주 하고 싶은 취미나 활동이 있어?', 'personal_values', true, 250),
  ('curated', 'fallback_v1_memory_animals_plants_01', '함께 지낸 반려동물이 있다면 가장 먼저 떠오르는 장면은 뭐야?', 'memory_animals_plants', true, 260),
  ('curated', 'fallback_v1_general_emotional_support_03', '지금 상대에게 듣고 싶은 다정한 한마디가 있어?', 'emotional_support', true, 270),
  ('curated', 'fallback_v1_relationship_promises_activities_01', '서로에게 꼭 지켜주고 싶은 약속을 한 문장으로 적어봐.', 'relationship_promises_activities', true, 280),
  ('curated', 'fallback_v1_general_communication_repair_03', '지금 상대에게 물어보고 싶었지만 미뤄둔 게 있어?', 'communication_repair', true, 290),
  ('curated', 'fallback_v1_memory_couple_beginning_01', '처음 만났을 때 상대가 어떤 사람일 거라고 생각했어?', 'memory_couple_beginning', true, 300),
  ('curated', 'fallback_v1_general_daily_life_03', '지금 둘이 다시 가고 싶은 장소가 있어?', 'daily_life', true, 310),
  ('curated', 'fallback_v1_relationship_past_stories_01', '상대가 아직 모를 것 같은 어린 시절의 네 모습은 뭐야?', 'relationship_past_stories', true, 320),
  ('curated', 'fallback_v1_general_relationship_strength_03', '둘을 떠올리면 가장 먼저 생각나는 노래가 있어?', 'relationship_strength', true, 330),
  ('curated', 'fallback_v1_memory_childhood_home_02', '어릴 때 살던 동네를 떠올리면 가장 먼저 생각나는 풍경은 뭐야?', 'memory_childhood_home', true, 340),
  ('curated', 'fallback_v1_general_future_boundaries_03', '지금 둘이 미리 정해두면 편할 약속이 있어?', 'future_boundaries', true, 350),
  ('curated', 'fallback_v1_relationship_personal_world_02', '남들은 평범하게 봐도 너에게 특별한 물건이 있어?', 'relationship_personal_world', true, 360),
  ('curated', 'fallback_v1_general_personal_values_04', '지금 하나쯤 배워보고 싶은 게 있어?', 'personal_values', true, 370),
  ('curated', 'fallback_v1_memory_school_teachers_02', '학교에서 가장 기다려졌던 시간은 언제였어?', 'memory_school_teachers', true, 380),
  ('curated', 'fallback_v1_general_emotional_support_04', '지금 상대에게 해주고 싶은 칭찬은 뭐야?', 'emotional_support', true, 390),
  ('curated', 'fallback_v1_relationship_attraction_change_02', '상대가 생각보다 재미있는 사람이라고 처음 느낀 순간은 언제야?', 'relationship_attraction_change', true, 400),
  ('curated', 'fallback_v1_general_communication_repair_04', '상대와 말이 잘 통한다고 느꼈던 사소한 순간이 있어?', 'communication_repair', true, 410),
  ('curated', 'fallback_v1_memory_friends_02', '친구들과 모이면 자주 하던 놀이나 장난이 뭐였어?', 'memory_friends', true, 420),
  ('curated', 'fallback_v1_general_daily_life_04', '지금 같이 보고 싶은 영화나 영상이 있어?', 'daily_life', true, 430),
  ('curated', 'fallback_v1_relationship_shared_memories_02', '둘이 함께한 순간을 떠올릴 때 같이 생각나는 소리나 냄새는 뭐야?', 'relationship_shared_memories', true, 440),
  ('curated', 'fallback_v1_general_relationship_strength_04', '지금 둘이 자주 쓰고 싶은 둘만의 인사말이 있어?', 'relationship_strength', true, 450),
  ('curated', 'fallback_v1_memory_media_play_02', '오래전에 읽었는데 아직 장면이 떠오르는 책이 있어?', 'memory_media_play', true, 460),
  ('curated', 'fallback_v1_general_future_boundaries_04', '약속을 잡을 때 상대가 알아두면 좋은 네 습관이 있어?', 'future_boundaries', true, 470),
  ('curated', 'fallback_v1_relationship_partner_perspective_02', '상대가 너를 다정하게 소개한다고 상상하고 한 문장으로 적어봐.', 'relationship_partner_perspective', true, 480),
  ('curated', 'fallback_v1_general_personal_values_05', '지금 스스로에게 더 자주 해주고 싶은 칭찬은 뭐야?', 'personal_values', true, 490),
  ('curated', 'fallback_v1_memory_landscape_travel_02', '다시 한 번 가보고 싶은 옛 여행지는 어디야?', 'memory_landscape_travel', true, 500),
  ('curated', 'fallback_v1_general_emotional_support_05', '지금 상대에게 보내고 싶은 이모티콘이 있다면 어떤 거야?', 'emotional_support', true, 510),
  ('curated', 'fallback_v1_relationship_care_requests_02', '요즘 상대가 먼저 어떤 걸 물어봐주면 좋겠어?', 'relationship_care_requests', true, 520),
  ('curated', 'fallback_v1_general_communication_repair_05', '설명을 듣고 바로 오해가 풀렸던 일이 있어?', 'communication_repair', true, 530),
  ('curated', 'fallback_v1_memory_habits_language_play_02', '어릴 때부터 지금까지 남아 있는 습관이 있어?', 'memory_habits_language_play', true, 540),
  ('curated', 'fallback_v1_general_daily_life_05', '둘이 먹었던 것 중 또 먹고 싶은 메뉴가 있어?', 'daily_life', true, 550),
  ('curated', 'fallback_v1_relationship_boundaries_02', '다른 사람 앞에서 상대가 지켜줬으면 하는 선이 있어?', 'relationship_boundaries', true, 560),
  ('curated', 'fallback_v1_general_relationship_strength_05', '지금 상대의 어떤 모습을 보면 괜히 미소가 나?', 'relationship_strength', true, 570),
  ('curated', 'fallback_v1_memory_animals_plants_02', '어릴 때 유난히 좋아했던 동물은 뭐였어?', 'memory_animals_plants', true, 580),
  ('curated', 'fallback_v1_general_future_boundaries_05', '지금 혼자서도 해보고 싶은 일이 하나 있다면 뭐야?', 'future_boundaries', true, 590),
  ('curated', 'fallback_v1_relationship_promises_activities_02', '둘이 다툴 때 잠깐 멈추자는 신호를 하나 정해봐.', 'relationship_promises_activities', true, 600),
  ('curated', 'fallback_v1_general_personal_values_06', '시간 가는 줄 모르고 하게 되는 일이 뭐야?', 'personal_values', true, 610),
  ('curated', 'fallback_v1_memory_couple_beginning_02', '첫인상과 지금 모습 사이에서 가장 달라 보이는 점은 뭐야?', 'memory_couple_beginning', true, 620),
  ('curated', 'fallback_v1_general_emotional_support_06', '지금 상대에게 말하지 못한 고마움이 있다면 뭐야?', 'emotional_support', true, 630),
  ('curated', 'fallback_v1_relationship_past_stories_02', '상대에게 들려주고 싶은 학창 시절 이야기가 있어?', 'relationship_past_stories', true, 640),
  ('curated', 'fallback_v1_general_communication_repair_06', '상대가 질문해줘서 말하기 쉬워졌던 적이 있어?', 'communication_repair', true, 650),
  ('curated', 'fallback_v1_memory_childhood_home_03', '어릴 적 집에 가는 길에서 유난히 기억나는 장소가 있어?', 'memory_childhood_home', true, 660),
  ('curated', 'fallback_v1_general_daily_life_06', '둘이 우연히 발견한 마음에 드는 장소가 있어?', 'daily_life', true, 670),
  ('curated', 'fallback_v1_relationship_personal_world_03', '혼자만 알고 싶을 만큼 아끼는 장소는 어떤 곳이야?', 'relationship_personal_world', true, 680),
  ('curated', 'fallback_v1_general_relationship_strength_06', '지금 둘 사이에서 계속 이어가고 싶은 장난이나 습관이 있어?', 'relationship_strength', true, 690),
  ('curated', 'fallback_v1_memory_school_teachers_03', '지금도 기억나는 선생님의 말이 있어?', 'memory_school_teachers', true, 700),
  ('curated', 'fallback_v1_general_future_boundaries_06', '지금 둘이 천천히 준비해보고 싶은 작은 계획이 있어?', 'future_boundaries', true, 710),
  ('curated', 'fallback_v1_relationship_attraction_change_03', '연애 초반 상대가 유난히 좋아했던 건 뭐였어?', 'relationship_attraction_change', true, 720),
  ('curated', 'fallback_v1_general_personal_values_07', '스스로 뿌듯했던 작은 일이 떠오르는 게 있어?', 'personal_values', true, 730),
  ('curated', 'fallback_v1_memory_friends_03', '학창 시절 친구들과 자주 가던 곳은 어디였어?', 'memory_friends', true, 740),
  ('curated', 'fallback_v1_general_emotional_support_07', '상대가 기억해줘서 기분 좋았던 사소한 취향이 있어?', 'emotional_support', true, 750),
  ('curated', 'fallback_v1_relationship_shared_memories_03', '둘의 추억 하나에 영화 제목처럼 이름을 붙여봐.', 'relationship_shared_memories', true, 760),
  ('curated', 'fallback_v1_general_communication_repair_07', '메시지보다 만나서 말하길 잘했다고 느낀 적이 있어?', 'communication_repair', true, 770),
  ('curated', 'fallback_v1_memory_media_play_03', '들으면 예전 기억이 바로 떠오르는 노래가 뭐야?', 'memory_media_play', true, 780),
  ('curated', 'fallback_v1_general_daily_life_07', '평범했는데 이상하게 기억에 남는 데이트가 있어?', 'daily_life', true, 790),
  ('curated', 'fallback_v1_relationship_partner_perspective_03', '상대가 고를 것 같은 네 장점 세 가지를 적어봐.', 'relationship_partner_perspective', true, 800),
  ('curated', 'fallback_v1_general_relationship_strength_07', '둘만 알아듣는 장난이나 표현이 있어?', 'relationship_strength', true, 810),
  ('curated', 'fallback_v1_memory_landscape_travel_03', '여행에서 우연히 발견한 장소 중 기억나는 곳은 어디야?', 'memory_landscape_travel', true, 820),
  ('curated', 'fallback_v1_general_future_boundaries_07', '서로 각자 시간을 보내고 나서 더 반가웠던 적이 있어?', 'future_boundaries', true, 830),
  ('curated', 'fallback_v1_relationship_care_requests_03', '상대에게 작은 부탁 하나를 한다면 무엇을 부탁하고 싶어?', 'relationship_care_requests', true, 840),
  ('curated', 'fallback_v1_general_personal_values_08', '어릴 때부터 크게 바뀌지 않은 취향이 있어?', 'personal_values', true, 850),
  ('curated', 'fallback_v1_memory_habits_language_play_03', '지금도 무심코 나오는 오래된 말버릇이 있어?', 'memory_habits_language_play', true, 860),
  ('curated', 'fallback_v1_general_emotional_support_08', '둘이 같이 웃어서 기분이 좋아진 일이 떠오르는 게 있어?', 'emotional_support', true, 870),
  ('curated', 'fallback_v1_relationship_boundaries_03', '둘의 사진이나 이야기를 다른 사람에게 전할 때, 어떤 내용은 꼭 먼저 물어봐줬으면 해?', 'relationship_boundaries', true, 880),
  ('curated', 'fallback_v1_general_communication_repair_08', '연락할 때 가장 편한 답장 속도는 어느 정도야?', 'communication_repair', true, 890),
  ('curated', 'fallback_v1_memory_animals_plants_03', '기억에 남는 동물과의 만남이 있어?', 'memory_animals_plants', true, 900),
  ('curated', 'fallback_v1_general_daily_life_08', '둘이 찍은 사진 중 보면 웃음 나는 사진이 있어?', 'daily_life', true, 910),
  ('curated', 'fallback_v1_relationship_promises_activities_03', '바쁜 날에도 유지하고 싶은 최소한의 연락 방식을 적어봐.', 'relationship_promises_activities', true, 920),
  ('curated', 'fallback_v1_general_relationship_strength_08', '상대 때문에 새로 좋아하게 된 것이 있어?', 'relationship_strength', true, 930),
  ('curated', 'fallback_v1_memory_couple_beginning_03', '처음 둘이 오래 이야기했던 날에 무슨 얘기를 했는지 기억나?', 'memory_couple_beginning', true, 940),
  ('curated', 'fallback_v1_general_future_boundaries_08', '미리 일정을 맞춰둬서 편했던 적이 있어?', 'future_boundaries', true, 950),
  ('curated', 'fallback_v1_relationship_past_stories_03', '상대에게 예전에 즐기던 취미나 놀이 하나를 소개한다면 뭘 고를래?', 'relationship_past_stories', true, 960),
  ('curated', 'fallback_v1_general_personal_values_09', '생각보다 잘 맞아서 계속하게 된 일이 있어?', 'personal_values', true, 970),
  ('curated', 'fallback_v1_memory_childhood_home_04', '어릴 때 자주 들르던 가게나 시장이 있었어?', 'memory_childhood_home', true, 980),
  ('curated', 'fallback_v1_general_emotional_support_09', '상대의 말투가 유난히 다정하게 느껴진 순간이 있어?', 'emotional_support', true, 990),
  ('curated', 'fallback_v1_relationship_personal_world_04', '어릴 때 받은 선물 중 지금도 가장 생생하게 기억나는 건 뭐였어?', 'relationship_personal_world', true, 1000),
  ('curated', 'fallback_v1_general_communication_repair_09', '읽기 편한 메시지는 어떤 스타일이야?', 'communication_repair', true, 1010),
  ('curated', 'fallback_v1_memory_school_teachers_04', '기억에 남는 선생님은 어떤 분이었어?', 'memory_school_teachers', true, 1020),
  ('curated', 'fallback_v1_general_daily_life_09', '함께 보낸 시간 중 유난히 빨리 지나간 것처럼 느껴진 적이 있어?', 'daily_life', true, 1030),
  ('curated', 'fallback_v1_relationship_attraction_change_04', '처음 상대에게 잘 보이고 싶어서 무엇을 가장 신경 썼어?', 'relationship_attraction_change', true, 1040),
  ('curated', 'fallback_v1_general_relationship_strength_09', '둘이 힘을 합쳐 빨리 끝낸 일이 있어?', 'relationship_strength', true, 1050),
  ('curated', 'fallback_v1_memory_friends_04', '친구가 해준 말이나 행동 중 아직 기억나는 게 있어?', 'memory_friends', true, 1060),
  ('curated', 'fallback_v1_general_future_boundaries_09', '상대가 네 취미 시간을 챙겨줘서 고마웠던 적이 있어?', 'future_boundaries', true, 1070),
  ('curated', 'fallback_v1_relationship_shared_memories_04', '둘의 추억 하나를 세 개의 이모티콘으로 표현해봐.', 'relationship_shared_memories', true, 1080),
  ('curated', 'fallback_v1_general_personal_values_10', '한 번 시작하면 끝까지 하고 싶은 일이 있어?', 'personal_values', true, 1090),
  ('curated', 'fallback_v1_memory_media_play_04', '처음 좋아하게 된 가수나 캐릭터를 기억해?', 'memory_media_play', true, 1100),
  ('curated', 'fallback_v1_general_emotional_support_10', '예상하지 못한 칭찬을 받아 기분 좋았던 적이 있어?', 'emotional_support', true, 1110),
  ('curated', 'fallback_v1_relationship_partner_perspective_04', '상대가 너를 만화 캐릭터로 그린다고 상상하고, 어떤 표정일지 적어봐.', 'relationship_partner_perspective', true, 1120),
  ('curated', 'fallback_v1_general_communication_repair_10', '상대가 내 이야기를 잘 들어준다고 느꼈던 순간이 있어?', 'communication_repair', true, 1130),
  ('curated', 'fallback_v1_memory_landscape_travel_04', '차나 기차 창밖으로 스쳐 지나간 풍경이 기억나?', 'memory_landscape_travel', true, 1140),
  ('curated', 'fallback_v1_general_daily_life_10', '둘이 해봤는데 생각보다 재미있었던 일이 있어?', 'daily_life', true, 1150),
  ('curated', 'fallback_v1_relationship_care_requests_04', '특별한 날이 아니어도 상대가 무엇을 챙겨주면 기분이 좋아질까?', 'relationship_care_requests', true, 1160),
  ('curated', 'fallback_v1_general_relationship_strength_10', '상대의 의외의 모습을 보고 웃었던 적이 있어?', 'relationship_strength', true, 1170),
  ('curated', 'fallback_v1_memory_habits_language_play_04', '어릴 때 잠들기 전에 꼭 하던 일이 뭐였어?', 'memory_habits_language_play', true, 1180),
  ('curated', 'fallback_v1_general_future_boundaries_10', '둘의 계획이 바뀌었는데 오히려 더 재미있었던 적이 있어?', 'future_boundaries', true, 1190),
  ('curated', 'fallback_v1_relationship_boundaries_04', '약속이 바뀔 때 상대가 어떻게 알려줬으면 해?', 'relationship_boundaries', true, 1200),
  ('curated', 'fallback_v1_general_personal_values_11', '다른 사람에게 자주 듣는 네 장점은 뭐야?', 'personal_values', true, 1210),
  ('curated', 'fallback_v1_memory_animals_plants_04', '키워봤거나 오래 지켜본 식물이 있어?', 'memory_animals_plants', true, 1220),
  ('curated', 'fallback_v1_general_emotional_support_11', '상대가 편을 들어줘서 든든했던 순간이 있어?', 'emotional_support', true, 1230),
  ('curated', 'fallback_v1_relationship_promises_activities_04', '혼자 쉬고 싶다는 뜻을 편하게 전할 문장을 만들어봐.', 'relationship_promises_activities', true, 1240),
  ('curated', 'fallback_v1_general_communication_repair_11', '둘이 말없이도 뜻이 통해서 웃었던 순간이 있어?', 'communication_repair', true, 1250),
  ('curated', 'fallback_v1_memory_couple_beginning_04', '첫 데이트나 처음 둘이 따로 보낸 날에서 가장 기억나는 장면은 뭐야?', 'memory_couple_beginning', true, 1260),
  ('curated', 'fallback_v1_general_daily_life_11', '둘이 같은 메뉴만 일주일 먹어야 한다면 어떤 메뉴를 고를래?', 'daily_life', true, 1270),
  ('curated', 'fallback_v1_relationship_past_stories_04', '네 과거의 한 장면을 상대가 직접 볼 수 있다면 어떤 날을 고를래?', 'relationship_past_stories', true, 1280),
  ('curated', 'fallback_v1_general_relationship_strength_11', '처음보다 서로 더 닮았다고 느끼는 부분이 있어?', 'relationship_strength', true, 1290),
  ('curated', 'fallback_v1_memory_childhood_home_05', '어릴 때 집에서 가장 좋아했던 자리는 어디였어?', 'memory_childhood_home', true, 1300),
  ('curated', 'fallback_v1_general_future_boundaries_11', '둘이 함께 정한 약속 중 잘 지켜지고 있는 게 있어?', 'future_boundaries', true, 1310),
  ('curated', 'fallback_v1_relationship_personal_world_05', '버리지 못하고 남겨둔 오래된 물건이 있다면, 어떤 사연 때문에 지금까지 남겨뒀어?', 'relationship_personal_world', true, 1320),
  ('curated', 'fallback_v1_general_personal_values_12', '새로운 일을 시작할 때 가장 먼저 챙기는 건 뭐야?', 'personal_values', true, 1330),
  ('curated', 'fallback_v1_memory_school_teachers_05', '학교 다닐 때 유난히 좋아했던 급식이나 간식은 뭐였어?', 'memory_school_teachers', true, 1340),
  ('curated', 'fallback_v1_general_emotional_support_12', '별말 없이 같이 있어도 편했던 순간이 있어?', 'emotional_support', true, 1350),
  ('curated', 'fallback_v1_relationship_attraction_change_05', '만나면서 상대에게 새로 생긴 좋은 습관이 있어?', 'relationship_attraction_change', true, 1360),
  ('curated', 'fallback_v1_general_communication_repair_12', '둘만 알아볼 수 있는 대화 신호를 만든다면 어떤 신호가 좋을까?', 'communication_repair', true, 1370),
  ('curated', 'fallback_v1_memory_friends_05', '친구들 사이에서 넌 주로 어떤 역할이었어?', 'memory_friends', true, 1380),
  ('curated', 'fallback_v1_general_daily_life_12', '데이트를 시작할 때 가장 먼저 정하고 싶은 건 뭐야?', 'daily_life', true, 1390),
  ('curated', 'fallback_v1_relationship_shared_memories_05', '둘이 처음 함께 해본 일 하나를 다시 한다면, 무엇을 다르게 해보고 싶어?', 'relationship_shared_memories', true, 1400),
  ('curated', 'fallback_v1_general_relationship_strength_12', '다른 사람에게 자랑하고 싶은 둘만의 추억이 있어?', 'relationship_strength', true, 1410),
  ('curated', 'fallback_v1_memory_media_play_05', '예전에 시간 가는 줄 모르고 하던 게임이 있어?', 'memory_media_play', true, 1420),
  ('curated', 'fallback_v1_general_future_boundaries_12', '둘이 한 달 동안 작은 도전을 한다면 뭘 해보고 싶어?', 'future_boundaries', true, 1430),
  ('curated', 'fallback_v1_relationship_partner_perspective_05', '상대가 지금 보낼 것 같은 이모티콘 하나와 그 이유를 적어봐.', 'relationship_partner_perspective', true, 1440),
  ('curated', 'fallback_v1_general_personal_values_13', '어떤 날을 보내면 스스로 뿌듯하다고 느껴?', 'personal_values', true, 1450),
  ('curated', 'fallback_v1_memory_landscape_travel_05', '사진은 없지만 머릿속에 남아 있는 장소가 있어?', 'memory_landscape_travel', true, 1460),
  ('curated', 'fallback_v1_general_emotional_support_13', '상대가 긴장하는 날이라면 어떤 짧은 말을 건네고 싶어?', 'emotional_support', true, 1470),
  ('curated', 'fallback_v1_relationship_care_requests_05', '상대가 먼저 "같이 하자"고 말해주면 가장 반가울 일은 뭘까?', 'relationship_care_requests', true, 1480),
  ('curated', 'fallback_v1_general_communication_repair_13', '둘의 평소 대화를 이모티콘 하나로 나타낸다면 어떤 걸 고를래?', 'communication_repair', true, 1490),
  ('curated', 'fallback_v1_memory_habits_language_play_05', '어릴 때 자주 하던 장난 중 지금 생각해도 웃긴 게 있어?', 'memory_habits_language_play', true, 1500),
  ('curated', 'fallback_v1_general_daily_life_13', '둘이 간식 가게를 연다면 대표 메뉴로 뭘 팔고 싶어?', 'daily_life', true, 1510),
  ('curated', 'fallback_v1_relationship_boundaries_05', '감정이 격해졌을 때 어떤 식의 대화가 가장 힘들어?', 'relationship_boundaries', true, 1520),
  ('curated', 'fallback_v1_general_relationship_strength_13', '둘의 관계에 별명을 붙인다면 뭐라고 하고 싶어?', 'relationship_strength', true, 1530),
  ('curated', 'fallback_v1_memory_animals_plants_05', '동물이나 식물을 돌본 적이 있다면 매일 챙기던 일은 뭐였어?', 'memory_animals_plants', true, 1540),
  ('curated', 'fallback_v1_general_future_boundaries_13', '둘이 함께 배울 수 있다면 어떤 수업을 골라보고 싶어?', 'future_boundaries', true, 1550),
  ('curated', 'fallback_v1_relationship_promises_activities_05', '둘이 한 달에 한 번 같이 하고 싶은 작은 일을 하나 정해봐.', 'relationship_promises_activities', true, 1560),
  ('curated', 'fallback_v1_general_personal_values_14', '지금 네 기분을 색으로 표현하면 무슨 색이야?', 'personal_values', true, 1570),
  ('curated', 'fallback_v1_memory_couple_beginning_05', '처음 주고받던 연락의 분위기는 어땠어?', 'memory_couple_beginning', true, 1580),
  ('curated', 'fallback_v1_general_emotional_support_14', '다정하다고 느끼는 말투는 어떤 말투야?', 'emotional_support', true, 1590),
  ('curated', 'fallback_v1_relationship_past_stories_05', '옛 친구가 지금의 너를 보면 가장 놀랄 변화는 뭐야?', 'relationship_past_stories', true, 1600),
  ('curated', 'fallback_v1_general_communication_repair_14', '상대와 이야기할 때 가장 편한 장소는 어디야?', 'communication_repair', true, 1610),
  ('curated', 'fallback_v1_memory_childhood_home_06', '어릴 때 지내던 동네를 상대에게 보여준다면 어디부터 같이 가고 싶어?', 'memory_childhood_home', true, 1620),
  ('curated', 'fallback_v1_general_daily_life_14', '둘이 하루 동안 관광객처럼 논다면 어디부터 가고 싶어?', 'daily_life', true, 1630),
  ('curated', 'fallback_v1_relationship_personal_world_06', '어린 시절의 너에게서 지금 하나 가져올 수 있다면 뭘 가져오고 싶어?', 'relationship_personal_world', true, 1640),
  ('curated', 'fallback_v1_general_relationship_strength_14', '둘의 추억 하나를 스티커로 만든다면 어떤 장면을 고를래?', 'relationship_strength', true, 1650),
  ('curated', 'fallback_v1_memory_school_teachers_06', '학교 행사나 소풍 중 다시 떠올리면 웃음 나는 날이 있어?', 'memory_school_teachers', true, 1660),
  ('curated', 'fallback_v1_general_future_boundaries_14', '둘이 계획을 세울 때 네 역할을 한 단어로 표현하면 뭐야?', 'future_boundaries', true, 1670),
  ('curated', 'fallback_v1_relationship_attraction_change_06', '처음에는 몰랐지만 만나면서 점점 좋아진 상대의 모습은 뭐야?', 'relationship_attraction_change', true, 1680),
  ('curated', 'fallback_v1_general_personal_values_15', '어떻게 쉬어야 제대로 쉬었다는 느낌이 들어?', 'personal_values', true, 1690),
  ('curated', 'fallback_v1_memory_friends_06', '옛 친구를 우연히 다시 만나면 어떤 얘기부터 하고 싶어?', 'memory_friends', true, 1700),
  ('curated', 'fallback_v1_general_emotional_support_15', '상대가 뭘 해주면 괜히 힘이 나?', 'emotional_support', true, 1710),
  ('curated', 'fallback_v1_relationship_partner_perspective_06', '서로 역할이 바뀐 하루를 상상하고 가장 먼저 할 일을 적어봐.', 'relationship_partner_perspective', true, 1720),
  ('curated', 'fallback_v1_general_communication_repair_15', '지금 상대에게 가장 먼저 전하고 싶은 소식은 뭐야?', 'communication_repair', true, 1730),
  ('curated', 'fallback_v1_memory_media_play_06', '예전에 좋아했던 작품 하나를 상대에게 보여준다면 뭘 고를래?', 'memory_media_play', true, 1740),
  ('curated', 'fallback_v1_general_daily_life_15', '둘이 같이 먹으면 더 맛있게 느껴지는 음식이 있어?', 'daily_life', true, 1750),
  ('curated', 'fallback_v1_relationship_care_requests_06', '요즘 네가 애쓰는 일 중 상대가 알아줬으면 하는 건 뭐야?', 'relationship_care_requests', true, 1760),
  ('curated', 'fallback_v1_general_relationship_strength_15', '둘에게 잘 어울리는 색 조합은 어떤 색들이야?', 'relationship_strength', true, 1770),
  ('curated', 'fallback_v1_memory_landscape_travel_06', '멀리 가지 않았는데도 여행처럼 느껴졌던 날이 있었어?', 'memory_landscape_travel', true, 1780),
  ('curated', 'fallback_v1_general_future_boundaries_15', '각자 시간을 보내는 날에도 꼭 함께하고 싶은 게 있어?', 'future_boundaries', true, 1790),
  ('curated', 'fallback_v1_relationship_boundaries_06', '상대가 하지 않았으면 하는 행동 하나를, 대신 바라는 행동과 함께 적어봐.', 'relationship_boundaries', true, 1800),
  ('curated', 'fallback_v1_general_personal_values_16', '최근에 시간을 쓰길 잘했다고 느낀 일이 있어?', 'personal_values', true, 1810),
  ('curated', 'fallback_v1_memory_habits_language_play_06', '예전에 즐기던 놀이 하나를 상대에게 알려준다면 뭘 골라?', 'memory_habits_language_play', true, 1820),
  ('curated', 'fallback_v1_general_emotional_support_16', '상대에게 가장 자주 전하고 싶은 마음은 뭐야?', 'emotional_support', true, 1830),
  ('curated', 'fallback_v1_relationship_promises_activities_06', '서로 잘한 일을 발견했을 때 표현할 둘만의 방식을 정해봐.', 'relationship_promises_activities', true, 1840),
  ('curated', 'fallback_v1_general_communication_repair_16', '둘이 어떤 이야기를 시작하면 시간이 빨리 가?', 'communication_repair', true, 1850),
  ('curated', 'fallback_v1_memory_animals_plants_06', '언젠가 함께 살아보고 싶은 동물이나 키워보고 싶은 식물이 있어?', 'memory_animals_plants', true, 1860),
  ('curated', 'fallback_v1_general_daily_life_16', '지금 둘이 사진으로 남기고 싶은 장면이 있어?', 'daily_life', true, 1870),
  ('curated', 'fallback_v1_relationship_past_stories_06', '어릴 때의 네가 지금 상대를 만났다고 상상하고, 처음 건넬 말을 적어봐.', 'relationship_past_stories', true, 1880),
  ('curated', 'fallback_v1_general_relationship_strength_16', '둘이 가장 우리답다고 느꼈던 순간은 언제야?', 'relationship_strength', true, 1890),
  ('curated', 'fallback_v1_memory_couple_beginning_06', '서로 농담할 만큼 편해졌다고 처음 느낀 순간은 언제였어?', 'memory_couple_beginning', true, 1900),
  ('curated', 'fallback_v1_general_future_boundaries_16', '지금 상대가 응원해주면 좋을 개인 목표가 있어?', 'future_boundaries', true, 1910)
on conflict (question_text) where source = 'curated'
do update
set
  question_key = excluded.question_key,
  category = excluded.category,
  is_active = excluded.is_active,
  fallback_position = excluded.fallback_position,
  updated_at = now()
where questions.curriculum_version is null;

do $$
begin
  if (
    select count(*)
    from public.questions as q
    where q.fallback_position is not null
      and q.is_active
  ) <> 191 then
    raise exception 'Expected 191 active curated fallback questions';
  end if;
end;
$$;

create or replace function private.assign_curated_fallback_question_to_story_loop(
  target_couple public.couples,
  target_story_loop public.daily_story_loops
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_daily_question public.daily_questions%rowtype;
  selected_question_id uuid;
  selected_question_category text;
  alternate_question_id uuid;
  previous_question_category text;
begin
  perform pg_advisory_xact_lock(
    hashtext('curated_fallback_question'),
    hashtext(target_couple.id::text)
  );

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.story_loop_id = target_story_loop.id
  for update;

  if found then
    return target_daily_question;
  end if;

  select exposed_question.category
  into previous_question_category
  from (
    select
      q.category,
      dq.created_at as exposed_at,
      dq.id
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_couple.id

    union all

    select
      q.category,
      aifq.created_at,
      aifq.id
    from public.ai_focused_questions as aifq
    join public.questions as q on q.id = aifq.question_id
    where aifq.couple_id = target_couple.id
  ) as exposed_question
  order by exposed_question.exposed_at desc, exposed_question.id desc
  limit 1;

  select q.id, q.category
  into selected_question_id, selected_question_category
  from public.questions as q
  where q.source = 'curated'
    and q.is_active
    and q.fallback_position is not null
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.couple_id = target_couple.id
        and dq.question_id = q.id
    )
    and not exists (
      select 1
      from public.ai_focused_questions as aifq
      where aifq.couple_id = target_couple.id
        and aifq.question_id = q.id
    )
  order by q.fallback_position
  limit 1;

  if selected_question_id is null then
    return null;
  end if;

  if previous_question_category is not null
    and selected_question_category = previous_question_category
  then
    select q.id
    into alternate_question_id
    from public.questions as q
    where q.source = 'curated'
      and q.is_active
      and q.fallback_position is not null
      and q.id <> selected_question_id
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.couple_id = target_couple.id
          and dq.question_id = q.id
      )
      and not exists (
        select 1
        from public.ai_focused_questions as aifq
        where aifq.couple_id = target_couple.id
          and aifq.question_id = q.id
      )
    order by q.fallback_position
    limit 1;

    selected_question_id := coalesce(
      alternate_question_id,
      selected_question_id
    );
  end if;

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date,
    story_loop_id
  )
  values (
    target_couple.id,
    selected_question_id,
    target_story_loop.couple_date,
    target_story_loop.id
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_story_loop.couple_date
  for update;

  if not found
    or target_daily_question.story_loop_id <> target_story_loop.id
  then
    return null;
  end if;

  return target_daily_question;
end;
$$;

revoke execute on function
  private.assign_curated_fallback_question_to_story_loop(
    public.couples,
    public.daily_story_loops
  ) from public, anon, authenticated;
