# 일반 질문 폴백 초안 v4

작성일: 2026-09-01

## 목적

v3 사용자 검토 결과를 반영해 영역별 16개, 전체 96개의 운영 후보를 구성한다.
빈칸 채우기 형식은 질문의 의미에 비해 형식 자체가 두드러지고 반복적으로
느껴져 전부 자연스러운 직접 질문으로 바꿨다.

## 반영 원칙

- v3 승인 102개 중 95개를 본선에 유지했다.
- 영역별 16개를 넘는 승인 질문 7개는 삭제하지 않고 예비 목록으로 옮겼다.
- 개인 성향과 가치관 영역에 보강한 신규 질문 1개도 사용자 검토를 거쳐
  확정했다.
- v3에서 제외한 6개는 본선과 예비 목록에 포함하지 않았다.
- `sentence_completion` 형식은 이번 운영 후보에서 사용하지 않는다.
- 선택형 질문은 영역별 최대 2개를 유지한다.

## 1. 개인 성향과 가치관

| 검토 | V4 ID | 기존 ID | 각도 | 답변 형식 | 질문 |
|---|---|---|---|---|---|
| [o] | FQ4-PV-01 | FQ3-PV-01 | preference | choice | 새로운 걸 배울 때 설명부터 보는 편이야, 직접 해보는 편이야? |
| [o] | FQ4-PV-02 | FQ3-PV-02 | preference | choice | 작은 일을 꾸준히 하는 것과 한 번에 몰입하는 것 중 어느 쪽이 잘 맞아? |
| [o] | FQ4-PV-03 | FQ3-PV-03 | current_need | short_answer | 지금 더 자주 하고 싶은 취미나 활동이 있어? |
| [o] | FQ4-PV-04 | FQ3-PV-04 | current_need | short_answer | 지금 하나쯤 배워보고 싶은 게 있어? |
| [o] | FQ4-PV-05 | FQ3-PV-05 | current_need | short_answer | 지금 스스로에게 더 자주 해주고 싶은 칭찬은 뭐야? |
| [o] | FQ4-PV-06 | FQ3-PV-06 | lived_experience | short_answer | 시간 가는 줄 모르고 하게 되는 일이 뭐야? |
| [o] | FQ4-PV-07 | FQ3-PV-07 | lived_experience | memory_recall | 스스로 뿌듯했던 작은 일이 떠오르는 게 있어? |
| [o] | FQ4-PV-08 | FQ3-PV-08 | lived_experience | memory_recall | 어릴 때부터 크게 바뀌지 않은 취향이 있어? |
| [o] | FQ4-PV-09 | FQ3-PV-09 | lived_experience | memory_recall | 생각보다 잘 맞아서 계속하게 된 일이 있어? |
| [o] | FQ4-PV-10 | FQ3-PV-10 | lived_experience | short_answer | 한 번 시작하면 끝까지 하고 싶은 일이 있어? |
| [o] | FQ4-PV-11 | FQ3-PV-11 | lived_experience | short_answer | 다른 사람에게 자주 듣는 네 장점은 뭐야? |
| [o] | FQ4-PV-12 | FQ3-PV-12 | preference | short_answer | 새로운 일을 시작할 때 가장 먼저 챙기는 건 뭐야? |
| [o] | FQ4-PV-13 | FQ3-PV-16 | preference | short_answer | 어떤 날을 보내면 스스로 뿌듯하다고 느껴? |
| [o] | FQ4-PV-14 | FQ3-PV-17 | current_need | describe | 지금 네 기분을 색으로 표현하면 무슨 색이야? |
| [o] | FQ4-PV-15 | FQ3-PV-18 | preference | describe | 어떻게 쉬어야 제대로 쉬었다는 느낌이 들어? |
| [o] | FQ4-PV-16 | new | lived_experience | memory_recall | 최근에 시간을 쓰길 잘했다고 느낀 일이 있어? |

## 2. 애정 표현과 정서적 지원

| 검토 | V4 ID | 기존 ID | 각도 | 답변 형식 | 질문 |
|---|---|---|---|---|---|
| [o] | FQ4-ES-01 | FQ3-ES-01 | preference | choice | 애정 표현은 자주 조금씩 받는 것과 가끔 크게 받는 것 중 뭐가 좋아? |
| [o] | FQ4-ES-02 | FQ3-ES-02 | preference | choice | 상대가 바쁜 날에는 짧게 연락하는 것과 나중에 길게 이야기하는 것 중 뭐가 좋아? |
| [o] | FQ4-ES-03 | FQ3-ES-03 | current_need | short_answer | 지금 상대에게 듣고 싶은 다정한 한마디가 있어? |
| [o] | FQ4-ES-04 | FQ3-ES-04 | current_need | short_answer | 지금 상대에게 해주고 싶은 칭찬은 뭐야? |
| [o] | FQ4-ES-05 | FQ3-ES-05 | current_need | short_answer | 지금 상대에게 보내고 싶은 이모티콘이 있다면 어떤 거야? |
| [o] | FQ4-ES-06 | FQ3-ES-06 | current_need | short_answer | 지금 상대에게 말하지 못한 고마움이 있다면 뭐야? |
| [o] | FQ4-ES-07 | FQ3-ES-07 | lived_experience | memory_recall | 상대가 기억해줘서 기분 좋았던 사소한 취향이 있어? |
| [o] | FQ4-ES-08 | FQ3-ES-08 | lived_experience | memory_recall | 둘이 같이 웃어서 기분이 좋아진 일이 떠오르는 게 있어? |
| [o] | FQ4-ES-09 | FQ3-ES-09 | lived_experience | memory_recall | 상대의 말투가 유난히 다정하게 느껴진 순간이 있어? |
| [o] | FQ4-ES-10 | FQ3-ES-10 | lived_experience | memory_recall | 예상하지 못한 칭찬을 받아 기분 좋았던 적이 있어? |
| [o] | FQ4-ES-11 | FQ3-ES-11 | lived_experience | memory_recall | 상대가 편을 들어줘서 든든했던 순간이 있어? |
| [o] | FQ4-ES-12 | FQ3-ES-12 | lived_experience | memory_recall | 별말 없이 같이 있어도 편했던 순간이 있어? |
| [o] | FQ4-ES-13 | FQ3-ES-13 | scenario | short_answer | 상대가 긴장하는 날이라면 어떤 짧은 말을 건네고 싶어? |
| [o] | FQ4-ES-14 | FQ3-ES-14 | preference | describe | 다정하다고 느끼는 말투는 어떤 말투야? |
| [o] | FQ4-ES-15 | FQ3-ES-17 | preference | short_answer | 상대가 뭘 해주면 괜히 힘이 나? |
| [o] | FQ4-ES-16 | FQ3-ES-18 | current_need | short_answer | 상대에게 가장 자주 전하고 싶은 마음은 뭐야? |

## 3. 대화와 갈등 회복

| 검토 | V4 ID | 기존 ID | 각도 | 답변 형식 | 질문 |
|---|---|---|---|---|---|
| [o] | FQ4-CR-01 | FQ3-CR-01 | preference | choice | 짧은 이야기는 전화와 메시지 중 뭐가 더 편해? |
| [o] | FQ4-CR-02 | FQ3-CR-02 | current_need | short_answer | 지금 상대와 가볍게 이야기해보고 싶은 주제가 있어? |
| [o] | FQ4-CR-03 | FQ3-CR-03 | current_need | short_answer | 지금 상대에게 물어보고 싶었지만 미뤄둔 게 있어? |
| [o] | FQ4-CR-04 | FQ3-CR-04 | lived_experience | memory_recall | 상대와 말이 잘 통한다고 느꼈던 사소한 순간이 있어? |
| [o] | FQ4-CR-05 | FQ3-CR-05 | lived_experience | memory_recall | 설명을 듣고 바로 오해가 풀렸던 일이 있어? |
| [o] | FQ4-CR-06 | FQ3-CR-06 | lived_experience | memory_recall | 상대가 질문해줘서 말하기 쉬워졌던 적이 있어? |
| [o] | FQ4-CR-07 | FQ3-CR-07 | lived_experience | memory_recall | 메시지보다 만나서 말하길 잘했다고 느낀 적이 있어? |
| [o] | FQ4-CR-08 | FQ3-CR-08 | preference | short_answer | 연락할 때 가장 편한 답장 속도는 어느 정도야? |
| [o] | FQ4-CR-09 | FQ3-CR-09 | preference | describe | 읽기 편한 메시지는 어떤 스타일이야? |
| [o] | FQ4-CR-10 | FQ3-CR-10 | lived_experience | memory_recall | 상대가 내 이야기를 잘 들어준다고 느꼈던 순간이 있어? |
| [o] | FQ4-CR-11 | FQ3-CR-11 | lived_experience | memory_recall | 둘이 말없이도 뜻이 통해서 웃었던 순간이 있어? |
| [o] | FQ4-CR-12 | FQ3-CR-12 | scenario | playful_imagination | 둘만 알아볼 수 있는 대화 신호를 만든다면 어떤 신호가 좋을까? |
| [o] | FQ4-CR-13 | FQ3-CR-14 | scenario | describe | 둘의 평소 대화를 이모티콘 하나로 나타낸다면 어떤 걸 고를래? |
| [o] | FQ4-CR-14 | FQ3-CR-15 | preference | describe | 상대와 이야기할 때 가장 편한 장소는 어디야? |
| [o] | FQ4-CR-15 | FQ3-CR-16 | current_need | short_answer | 지금 상대에게 가장 먼저 전하고 싶은 소식은 뭐야? |
| [o] | FQ4-CR-16 | FQ3-CR-18 | preference | short_answer | 둘이 어떤 이야기를 시작하면 시간이 빨리 가? |

## 4. 일상 취향과 함께하는 활동

| 검토 | V4 ID | 기존 ID | 각도 | 답변 형식 | 질문 |
|---|---|---|---|---|---|
| [o] | FQ4-DL-01 | FQ3-DL-01 | preference | choice | 간식은 달콤한 것과 짭짤한 것 중 뭐가 좋아? |
| [o] | FQ4-DL-02 | FQ3-DL-02 | preference | choice | 영화는 집에서 편하게 보는 것과 영화관에서 보는 것 중 뭐가 좋아? |
| [o] | FQ4-DL-03 | FQ3-DL-04 | current_need | short_answer | 지금 둘이 다시 가고 싶은 장소가 있어? |
| [o] | FQ4-DL-04 | FQ3-DL-05 | current_need | short_answer | 지금 같이 보고 싶은 영화나 영상이 있어? |
| [o] | FQ4-DL-05 | FQ3-DL-06 | lived_experience | memory_recall | 둘이 먹었던 것 중 또 먹고 싶은 메뉴가 있어? |
| [o] | FQ4-DL-06 | FQ3-DL-07 | lived_experience | memory_recall | 둘이 우연히 발견한 마음에 드는 장소가 있어? |
| [o] | FQ4-DL-07 | FQ3-DL-08 | lived_experience | memory_recall | 평범했는데 이상하게 기억에 남는 데이트가 있어? |
| [o] | FQ4-DL-08 | FQ3-DL-09 | lived_experience | memory_recall | 둘이 찍은 사진 중 보면 웃음 나는 사진이 있어? |
| [o] | FQ4-DL-09 | FQ3-DL-10 | lived_experience | memory_recall | 함께 보낸 시간 중 유난히 빨리 지나간 것처럼 느껴진 적이 있어? |
| [o] | FQ4-DL-10 | FQ3-DL-11 | lived_experience | memory_recall | 둘이 해봤는데 생각보다 재미있었던 일이 있어? |
| [o] | FQ4-DL-11 | FQ3-DL-12 | scenario | playful_imagination | 둘이 같은 메뉴만 일주일 먹어야 한다면 어떤 메뉴를 고를래? |
| [o] | FQ4-DL-12 | FQ3-DL-13 | preference | short_answer | 데이트를 시작할 때 가장 먼저 정하고 싶은 건 뭐야? |
| [o] | FQ4-DL-13 | FQ3-DL-14 | scenario | playful_imagination | 둘이 간식 가게를 연다면 대표 메뉴로 뭘 팔고 싶어? |
| [o] | FQ4-DL-14 | FQ3-DL-15 | scenario | playful_imagination | 둘이 하루 동안 관광객처럼 논다면 어디부터 가고 싶어? |
| [o] | FQ4-DL-15 | FQ3-DL-17 | preference | short_answer | 둘이 같이 먹으면 더 맛있게 느껴지는 음식이 있어? |
| [o] | FQ4-DL-16 | FQ3-DL-18 | current_need | short_answer | 지금 둘이 사진으로 남기고 싶은 장면이 있어? |

## 5. 관계의 기억과 강점

| 검토 | V4 ID | 기존 ID | 각도 | 답변 형식 | 질문 |
|---|---|---|---|---|---|
| [o] | FQ4-RS-01 | FQ3-RS-01 | preference | choice | 둘의 추억은 사진과 영상 중 어떤 걸로 더 많이 남기고 싶어? |
| [o] | FQ4-RS-02 | FQ3-RS-02 | preference | choice | 상대에게 칭찬을 들을 때 귀엽다는 말과 멋지다는 말 중 뭐가 더 좋아? |
| [o] | FQ4-RS-03 | FQ3-RS-03 | current_need | short_answer | 둘을 떠올리면 가장 먼저 생각나는 노래가 있어? |
| [o] | FQ4-RS-04 | FQ3-RS-04 | current_need | short_answer | 지금 둘이 자주 쓰고 싶은 둘만의 인사말이 있어? |
| [o] | FQ4-RS-05 | FQ3-RS-05 | current_need | short_answer | 지금 상대의 어떤 모습을 보면 괜히 미소가 나? |
| [o] | FQ4-RS-06 | FQ3-RS-06 | current_need | short_answer | 지금 둘 사이에서 계속 이어가고 싶은 장난이나 습관이 있어? |
| [o] | FQ4-RS-07 | FQ3-RS-07 | lived_experience | memory_recall | 둘만 알아듣는 장난이나 표현이 있어? |
| [o] | FQ4-RS-08 | FQ3-RS-08 | lived_experience | memory_recall | 상대 때문에 새로 좋아하게 된 것이 있어? |
| [o] | FQ4-RS-09 | FQ3-RS-09 | lived_experience | memory_recall | 둘이 힘을 합쳐 빨리 끝낸 일이 있어? |
| [o] | FQ4-RS-10 | FQ3-RS-10 | lived_experience | memory_recall | 상대의 의외의 모습을 보고 웃었던 적이 있어? |
| [o] | FQ4-RS-11 | FQ3-RS-11 | lived_experience | memory_recall | 처음보다 서로 더 닮았다고 느끼는 부분이 있어? |
| [o] | FQ4-RS-12 | FQ3-RS-12 | lived_experience | memory_recall | 다른 사람에게 자랑하고 싶은 둘만의 추억이 있어? |
| [o] | FQ4-RS-13 | FQ3-RS-13 | scenario | describe | 둘의 관계에 별명을 붙인다면 뭐라고 하고 싶어? |
| [o] | FQ4-RS-14 | FQ3-RS-14 | scenario | playful_imagination | 둘의 추억 하나를 스티커로 만든다면 어떤 장면을 고를래? |
| [o] | FQ4-RS-15 | FQ3-RS-16 | preference | describe | 둘에게 잘 어울리는 색 조합은 어떤 색들이야? |
| [o] | FQ4-RS-16 | FQ3-RS-18 | lived_experience | memory_recall | 둘이 가장 우리답다고 느꼈던 순간은 언제야? |

## 6. 미래 기대와 관계의 경계

| 검토 | V4 ID | 기존 ID | 각도 | 답변 형식 | 질문 |
|---|---|---|---|---|---|
| [o] | FQ4-FB-01 | FQ3-FB-01 | preference | choice | 서로의 일정은 자세히 아는 것과 중요한 것만 아는 것 중 뭐가 편해? |
| [o] | FQ4-FB-02 | FQ3-FB-02 | preference | choice | 혼자 쉬는 날과 함께 노는 날은 미리 나누는 게 좋아, 그때그때 정하는 게 좋아? |
| [o] | FQ4-FB-03 | FQ3-FB-03 | current_need | short_answer | 지금 둘이 미리 정해두면 편할 약속이 있어? |
| [o] | FQ4-FB-04 | FQ3-FB-04 | current_need | short_answer | 약속을 잡을 때 상대가 알아두면 좋은 네 습관이 있어? |
| [o] | FQ4-FB-05 | FQ3-FB-05 | current_need | short_answer | 지금 혼자서도 해보고 싶은 일이 하나 있다면 뭐야? |
| [o] | FQ4-FB-06 | FQ3-FB-06 | current_need | short_answer | 지금 둘이 천천히 준비해보고 싶은 작은 계획이 있어? |
| [o] | FQ4-FB-07 | FQ3-FB-07 | lived_experience | memory_recall | 서로 각자 시간을 보내고 나서 더 반가웠던 적이 있어? |
| [o] | FQ4-FB-08 | FQ3-FB-08 | lived_experience | memory_recall | 미리 일정을 맞춰둬서 편했던 적이 있어? |
| [o] | FQ4-FB-09 | FQ3-FB-09 | lived_experience | memory_recall | 상대가 네 취미 시간을 챙겨줘서 고마웠던 적이 있어? |
| [o] | FQ4-FB-10 | FQ3-FB-10 | lived_experience | memory_recall | 둘의 계획이 바뀌었는데 오히려 더 재미있었던 적이 있어? |
| [o] | FQ4-FB-11 | FQ3-FB-11 | lived_experience | memory_recall | 둘이 함께 정한 약속 중 잘 지켜지고 있는 게 있어? |
| [o] | FQ4-FB-12 | FQ3-FB-14 | scenario | playful_imagination | 둘이 한 달 동안 작은 도전을 한다면 뭘 해보고 싶어? |
| [o] | FQ4-FB-13 | FQ3-FB-15 | scenario | playful_imagination | 둘이 함께 배울 수 있다면 어떤 수업을 골라보고 싶어? |
| [o] | FQ4-FB-14 | FQ3-FB-16 | scenario | describe | 둘이 계획을 세울 때 네 역할을 한 단어로 표현하면 뭐야? |
| [o] | FQ4-FB-15 | FQ3-FB-17 | current_need | short_answer | 각자 시간을 보내는 날에도 꼭 함께하고 싶은 게 있어? |
| [o] | FQ4-FB-16 | FQ3-FB-18 | current_need | short_answer | 지금 상대가 응원해주면 좋을 개인 목표가 있어? |

## 예비 질문

다음 질문은 사용자 검토에서 승인됐지만 영역별 16개 제한과 의미·형식 분산을
위해 본선에서만 제외했다. 운영 질문 소진이나 후속 개편 시 다시 사용할 수 있다.

| 기존 ID | 영역 | 질문 | 예비 사유 |
|---|---|---|---|
| FQ3-ES-15 | 애정 표현과 정서적 지원 | 상대에게 기분 좋은 쪽지 한 줄을 남긴다면 뭐라고 쓸래? | 짧은 응원 표현 질문 집중 완화 |
| FQ3-ES-16 | 애정 표현과 정서적 지원 | 상대를 위한 작은 응원 쿠폰을 만든다면 어떤 쿠폰이야? | 가상 응원 표현 질문 집중 완화 |
| FQ3-CR-13 | 대화와 갈등 회복 | 상대에게 세 글자로 답장을 보내야 한다면 어떤 말을 쓸래? | 제한형 답변 질문 집중 완화 |
| FQ3-CR-17 | 대화와 갈등 회복 | 상대에게 하루를 설명한다면 가장 먼저 말할 장면은 뭐야? | 첫 소식 질문과 의미 인접 |
| FQ3-DL-03 | 일상 취향과 함께하는 활동 | 지금 둘이 같이 먹고 싶은 메뉴가 있어? | 음식 질문 집중 완화 |
| FQ3-RS-15 | 관계의 기억과 강점 | 둘이 한 팀으로 게임에 나간다면 팀 이름을 뭐라고 지을래? | 관계 별명 질문과 의미 인접 |
| FQ3-FB-12 | 미래 기대와 관계의 경계 | 약속을 잡을 때 가장 먼저 확인하는 건 뭐야? | 일정·계획 질문 집중 완화 |

## v3 검토 제외

| 기존 ID | 질문 |
|---|---|
| FQ3-PV-13 | 네가 좋아하는 하루의 속도를 한 단어로 표현하면 뭐야? |
| FQ3-PV-14 | 하루 동안 무엇이든 아주 잘할 수 있다면 어떤 걸 골라보고 싶어? |
| FQ3-PV-15 | 새로운 취미 가게에 들어갔다면 가장 먼저 둘러볼 코너는 어디야? |
| FQ3-DL-16 | 둘의 평범한 데이트를 날씨로 표현하면 어떤 날씨야? |
| FQ3-RS-17 | 둘이 캐릭터가 된다면 어떤 조합일 것 같아? |
| FQ3-FB-13 | 둘이 역할을 나눠서 계획을 더 쉽게 세운 적이 있어? |

## 검토 결과 기록

| 항목 | 수량 |
|---|---:|
| 본선 후보 | 96 |
| v3 승인 승계 | 95 |
| v4 신규 확정 | 1 |
| 검토 대기 | 0 |
| 예비 질문 | 7 |
| 사용자 검토 제외 | 6 |
| 빈칸 채우기 형식 | 0 |

## 자동 점검 결과

| 점검 항목 | 결과 |
|---|---:|
| 고유 V4 ID | 96 / 96 |
| 고유 질문 문장 | 96 / 96 |
| 영역별 본선 후보 | 각 16개 |
| 선택형 질문 | 전체 11개, 영역별 최대 2개 |
| 운영 질문 계약 위반 | 0건 |
| 본선 내부 근접 중복 | 0건 |
| 기존 기초 질문 24개와 근접 중복 | 0건 |

답변 형식은 `short_answer` 35개, `memory_recall` 34개, `choice` 11개,
`describe` 9개, `playful_imagination` 7개로 구성했다.

96개 질문은 사용자 검토를 마친 확정 목록이다. 운영 데이터 등록 전 전체
노출 이력과 의미 중복을 마지막으로 검사한다.
