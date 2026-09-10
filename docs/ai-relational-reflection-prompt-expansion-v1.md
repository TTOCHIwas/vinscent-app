# 관계 회고·표현 프롬프트 확장 초안 v1

작성일: 2026-09-01

## 목적

확정된 일반 질문 96개와 기억 확장 질문 48개에 더해, 개인의 사적인 세계와
둘의 관계를 조금 더 재미있고 구체적으로 돌아볼 수 있는 콘텐츠를 보강한다.

이번 초안은 단순 질문뿐 아니라 서로 적어보고 정하는 활동도 포함한다. 질문이
아닌 문장을 현재 질문 데이터에 억지로 넣지 않도록 `prompt_kind`를 별도로
표시한다. 48개를 모두 채택하면 검토된 콘텐츠 후보는 총 192개가 된다.

## 구성 원칙

- 8개 주제마다 6개씩, 전체 48개를 구성한다.
- 이항 선택과 빈칸 채우기 형식은 사용하지 않는다.
- 질문은 한 번에 한 가지 기억이나 바람만 묻는다.
- 상대의 생각을 사실처럼 단정하지 않고, 필요한 경우 `상상하고`라는 표현을
  사용한다.
- 불만이나 경계를 묻는 콘텐츠는 비난으로 끝내지 않고 원하는 대안까지 말할
  수 있게 한다.
- 역할 흉내는 놀림이 되지 않도록 `다정하게`라는 기준을 둔다.
- 이름, 정확한 주소, 학교명처럼 개인을 식별할 수 있는 답을 요구하지 않는다.
- 경계와 약속 콘텐츠는 운영 시 연속으로 노출하지 않는다.

## 프롬프트 유형

| prompt_kind | 의미 | 현재 질문 화면 호환 |
|---|---|---|
| `question` | 각자 답하는 일반 질문 | 가능 |
| `reflection` | 기억이나 바람을 문장으로 정리하는 활동 | 별도 지원 필요 |
| `playful_activity` | 상상하거나 역할을 바꿔 표현하는 활동 | 별도 지원 필요 |
| `agreement_prompt` | 둘이 함께 약속이나 방식을 정하는 활동 | 별도 지원 필요 |

현재 DB와 모바일 모델은 모든 콘텐츠를 `question_text`와 `질문/답변` UI로
처리한다. 따라서 `question` 이외의 17개는 검토 후보로만 보관하고,
`prompt_kind`가 DB, RPC, 모바일 표시 문구에 추가되기 전에는 운영 질문 풀에
등록하지 않는다.

## 기존 질문과의 중복 제외

사용자가 예로 든 다음 두 방향은 이미 확정 질문에 있으므로 새 문장으로
겹쳐 넣지 않았다.

- 첫인상: `FQM-RB-01` - 처음 만났을 때 상대가 어떤 사람일 거라고 생각했어?
- 처음 느낀 호감: `foundation_v1_relationship_strength_02` - 상대의 어떤 모습 때문에 처음 마음이 갔어?

## 1. 개인적인 보물과 나만의 세계

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-TR-01 | question | lived_experience | memory_recall | 없음 | 어릴 때 보물처럼 아끼던 물건은 뭐였어? |
| [ o] | FRP-TR-02 | question | lived_experience | describe | 없음 | 남들은 평범하게 봐도 너에게 특별한 물건이 있어? |
| [ o] | FRP-TR-03 | question | personal_world | describe | 없음 | 혼자만 알고 싶을 만큼 아끼는 장소는 어떤 곳이야? |
| [ o] | FRP-TR-04 | question | lived_experience | memory_recall | 없음 | 어릴 때 받은 것 중 오래 기억에 남은 선물이 있어? |
| [ o] | FRP-TR-05 | question | lived_experience | memory_recall | 조건부 | 버리지 못하고 남겨둔 오래된 물건이 있다면 어떤 사연이 있어? |
| [ o] | FRP-TR-06 | question | scenario | playful_imagination | 없음 | 어린 시절의 너에게서 지금 하나 가져올 수 있다면 뭘 가져오고 싶어? |

## 2. 처음의 호감과 관계 속 변화

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-EA-01 | question | lived_experience | memory_recall | 없음 | 처음 만났던 날 상대의 목소리나 말투에서 기억나는 게 있어? |
| [ o] | FRP-EA-02 | question | lived_experience | memory_recall | 없음 | 상대가 생각보다 재미있는 사람이라고 처음 느낀 순간은 언제야? |
| [ o] | FRP-EA-03 | question | lived_experience | memory_recall | 없음 | 연애 초반 상대가 좋아하던 것 중 지금도 기억나는 게 있어? |
| [ o] | FRP-EA-04 | question | lived_experience | memory_recall | 없음 | 처음 상대에게 잘 보이고 싶어서 신경 쓴 게 있어? |
| [ o] | FRP-EA-05 | question | relationship_change | describe | 없음 | 만나면서 상대에게 새로 생긴 좋은 습관이 있어? |
| [ o] | FRP-EA-06 | question | relationship_change | describe | 없음 | 처음에는 몰랐지만 만나면서 좋아진 상대의 모습이 있어? |

## 3. 서로 다르게 기억하는 둘의 추억

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ x] | FRP-SM-01 | question | shared_memory | memory_recall | 없음 | 둘이 같은 날을 서로 다르게 기억하고 있는 일이 있어? |
| [ x] | FRP-SM-02 | question | shared_memory | memory_recall | 없음 | 처음 같이 먹어봤을 때 서로 반응이 달랐던 음식이 있어? |
| [ x] | FRP-SM-03 | question | shared_memory | memory_recall | 없음 | 둘이 길을 잘못 들었는데 지금은 웃긴 추억이 된 적이 있어? |
| [ x] | FRP-SM-04 | reflection | shared_memory | guided_reflection | 없음 | 둘이 같은 추억 하나를 고르고, 각자 가장 먼저 떠오른 장면을 적어봐. |
| [ x] | FRP-SM-05 | reflection | shared_memory | guided_reflection | 없음 | 기억나는 둘의 사진 한 장을 떠올리고, 사진 앞뒤에 있었던 일을 적어봐. |
| [ o] | FRP-SM-06 | question | shared_memory | memory_recall | 없음 | 둘이 처음 함께 해본 일 중 지금 다시 하면 다르게 할 것 같은 게 있어? |

## 4. 상대의 관점으로 보기

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-PP-01 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 자주 쓰는 말투를 다정하게 흉내 내서 오늘 하루를 정리해봐. |
| [ o] | FRP-PP-02 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 너를 다정하게 소개한다고 상상하고 한 문장으로 적어봐. |
| [ o] | FRP-PP-03 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 고를 것 같은 네 장점 세 가지를 적어봐. |
| [ x] | FRP-PP-04 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대의 시선으로 오늘을 본다고 상상하고 가장 기억에 남을 장면을 적어봐. |
| [ o] | FRP-PP-05 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 지금 보낼 것 같은 이모티콘 하나와 그 이유를 적어봐. |
| [ o] | FRP-PP-06 | playful_activity | role_swap | playful_imagination | 없음 | 서로 역할이 바뀐 하루를 상상하고 가장 먼저 할 일을 적어봐. |

## 5. 상대에게 바라는 작은 돌봄

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-CW-01 | reflection | current_need | guided_reflection | 없음 | 상대가 계속 해줬으면 하는 행동 하나와 그 이유를 적어봐. |
| [ o] | FRP-CW-02 | question | current_need | short_answer | 없음 | 요즘 상대가 더 자주 물어봐줬으면 하는 게 있어? |
| [ o] | FRP-CW-03 | question | current_need | short_answer | 없음 | 상대에게 부탁하고 싶은 작고 구체적인 일이 있어? |
| [ o] | FRP-CW-04 | question | current_need | short_answer | 없음 | 특별한 날이 아니어도 상대가 챙겨줬으면 하는 게 있어? |
| [ o] | FRP-CW-05 | question | current_need | short_answer | 없음 | 상대가 먼저 제안해줬으면 하는 활동이 있어? |
| [ o] | FRP-CW-06 | question | current_need | short_answer | 없음 | 요즘 상대가 알아줬으면 하는 네 수고가 있어? |

## 6. 하지 않았으면 하는 것과 경계

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-BN-01 | question | boundary | short_answer | 없음 | 장난이어도 하지 않았으면 하는 말이나 행동이 있어? |
| [ o] | FRP-BN-02 | question | boundary | describe | 없음 | 다른 사람 앞에서 상대가 지켜줬으면 하는 선이 있어? |
| [ o] | FRP-BN-03 | question | privacy | describe | 없음 | 둘의 사진이나 이야기를 다른 사람에게 전할 때 먼저 물어봐줬으면 하는 범위가 있어? |
| [ o] | FRP-BN-04 | question | communication | describe | 없음 | 약속이 바뀔 때 상대가 어떻게 알려줬으면 해? |
| [ o] | FRP-BN-05 | question | conflict | describe | 없음 | 감정이 격해졌을 때 피하고 싶은 대화 방식이 있어? |
| [ o] | FRP-BN-06 | reflection | boundary | guided_reflection | 없음 | 상대가 하지 않았으면 하는 행동 하나를, 대신 바라는 행동과 함께 적어봐. |

## 7. 둘만의 약속과 작은 의식

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-AG-01 | agreement_prompt | relationship_agreement | collaborative | 없음 | 서로에게 꼭 지켜주고 싶은 약속을 한 문장으로 적어봐. |
| [ o] | FRP-AG-02 | agreement_prompt | conflict_repair | collaborative | 없음 | 둘이 다툴 때 잠깐 멈추자는 신호를 하나 정해봐. |
| [ o] | FRP-AG-03 | agreement_prompt | communication | collaborative | 없음 | 바쁜 날에도 유지하고 싶은 최소한의 연락 방식을 적어봐. |
| [ o] | FRP-AG-04 | agreement_prompt | personal_space | collaborative | 없음 | 혼자 쉬고 싶다는 뜻을 편하게 전할 문장을 만들어봐. |
| [ x] | FRP-AG-05 | agreement_prompt | shared_ritual | collaborative | 없음 | 기념일이 아닌 날에도 이어가고 싶은 작은 의식을 하나 정해봐. |
| [ o] | FRP-AG-06 | agreement_prompt | appreciation | collaborative | 없음 | 서로 잘한 일을 발견했을 때 표현할 둘만의 방식을 정해봐. |

## 8. 상대에게 들려주고 싶은 과거

| 검토 | ID | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|
| [ o] | FRP-SH-01 | question | personal_history | describe | 없음 | 상대가 아직 모를 것 같은 어린 시절의 네 모습은 뭐야? |
| [ o] | FRP-SH-02 | question | personal_history | memory_recall | 없음 | 상대에게 들려주고 싶은 학창 시절 이야기가 있어? |
| [ o] | FRP-SH-03 | question | personal_history | memory_recall | 없음 | 상대에게 소개해주고 싶은 오래된 취미나 놀이가 있어? |
| [ o] | FRP-SH-04 | question | scenario | playful_imagination | 없음 | 네 과거의 한 장면을 상대가 직접 볼 수 있다면 어떤 날을 고를래? |
| [ o] | FRP-SH-05 | question | relationship_change | describe | 없음 | 옛 친구가 지금의 너를 보면 가장 놀랄 변화는 뭐야? |
| [ o] | FRP-SH-06 | playful_activity | perspective_taking | playful_imagination | 없음 | 어릴 때의 네가 지금 상대를 만났다고 상상하고, 처음 건넬 말을 적어봐. |

## 검토 결과 기록

| 항목 | 수량 |
|---|---:|
| 확장 주제 | 8개 |
| 주제별 후보 | 6개 |
| 전체 후보 | 48개 |
| 일반 질문 | 31개 |
| 활동형 프롬프트 | 17개 |
| 사용자 승인 | 41개 |
| 사용자 제외 | 7개 |
| 검토 대기 | 0개 |
| 이항 선택 | 0개 |
| 빈칸 채우기 | 0개 |

## 운영 전 조건

- `question` 31개는 사용자 검토 후 기존 질문 계약과 전체 중복 검사를 통과한
  항목만 일반 질문 후보에 합친다.
- 활동형 17개는 `prompt_kind` 저장, 콘텐츠별 안내 문구, 답변 저장 방식과
  접근성 라벨을 구현한 뒤 별도 트랙으로 노출한다.
- `boundary`, `conflict`, `relationship_agreement` 콘텐츠는 가벼운 기억이나
  놀이형 콘텐츠 사이에 배치하며 연속 노출하지 않는다.
- 한 사람이 작성한 경계나 요청을 상대의 동의로 간주하지 않는다.

## 자동 점검 결과

| 점검 항목 | 결과 |
|---|---:|
| 고유 콘텐츠 ID | 48 / 48 |
| 고유 콘텐츠 문장 | 48 / 48 |
| 주제별 후보 | 각 6개 |
| 질문형 운영 계약 위반 | 0건 |
| 확장 콘텐츠 내부 근접 중복 | 0건 |
| 확정 코어 96개와 근접 중복 | 0건 |
| 확정 기억 질문 48개와 근접 중복 | 0건 |
| 기존 기초 질문 24개와 근접 중복 | 0건 |

프롬프트 유형은 `question` 31개, `reflection` 4개,
`playful_activity` 7개, `agreement_prompt` 6개로 구성했다.

사용자 검토에서 주제와 내용은 전반적으로 좋았지만, 질문형 31개 중 23개가
`~있어?`로 끝나 사용자에게 같은 방식의 질문이 반복되는 문제가 확인됐다.
승인된 주제의 문장 형식을 다시 구성하고 제외된 7개를 대체하는 작업은 v2에서
진행한다.
