# 관계 회고·표현 프롬프트 확정본 v2

작성일: 2026-09-03

## 목적

v1 사용자 검토 결과를 반영해 좋은 주제는 유지하면서 반복적인 질문 문법과
답변하기 어색한 구조를 바로잡는다.

v1은 48개 중 41개가 승인되고 7개가 제외됐다. 승인된 41개 가운데 25개는
문장을 그대로 승계하고, `~있어?` 반복이 필요한 수준을 넘은 16개는 주제만
유지한 채 표현을 바꿨다. 제외된 7개는 각 사용자가 따로 답하는 현재 제품
구조에 맞는 새 콘텐츠로 교체했다.

## 반영 원칙

- `~있어?`를 다른 한 가지 종결형으로 일괄 치환하지 않는다.
- 존재 여부 확인이 실제로 필요한 4개만 `~있어?`를 유지한다.
- 직접 회상, 장면 묘사, 가상 선택, 짧은 요청, 공동 활동을 고르게 사용한다.
- 한 질문에서 여러 기억을 동시에 꺼내거나 상대의 답을 미리 알아야 하는
  구조를 사용하지 않는다.
- 상대와 특정 경험을 했다는 사실을 근거 없이 단정하지 않는다.
- 이항 선택과 빈칸 채우기는 사용하지 않는다.
- v1에서 승인됐더라도 문장이 바뀐 16개는 다시 검토한다.
- v1에서 제외된 7개는 기존 ID를 유지하지 않고 새 ID로 구분한다.

## 검토 표시

| 표시 | 의미 |
|---|---|
| `[o]` | v1 승인 문장을 그대로 승계 |
| `[ ]` | 표현 수정 또는 대체로 재검토 필요 |
| `[x]` | v2 검토에서 제외 |

## 프롬프트 유형과 현재 호환성

| prompt_kind | 의미 | 현재 질문 화면 호환 |
|---|---|---|
| `question` | 각자 답하는 일반 질문 | 가능 |
| `reflection` | 기억이나 바람을 문장으로 정리하는 활동 | 별도 지원 필요 |
| `playful_activity` | 상상하거나 역할을 바꿔 표현하는 활동 | 별도 지원 필요 |
| `agreement_prompt` | 둘이 함께 약속이나 방식을 정하는 활동 | 별도 지원 필요 |

현재 DB와 모바일 모델은 모든 콘텐츠를 `question_text`와 `질문/답변` UI로
처리한다. `question` 이외의 콘텐츠는 사용자 검토와 별개로 `prompt_kind`가
DB, RPC, 모바일 UI에 추가되기 전까지 운영 질문 풀에 등록하지 않는다.

## 1. 개인적인 보물과 나만의 세계

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [o] | FRP-TR-01 | 승계 | question | lived_experience | memory_recall | 없음 | 어릴 때 보물처럼 아끼던 물건은 뭐였어? |
| [o] | FRP-TR-02 | 승계 | question | lived_experience | describe | 없음 | 남들은 평범하게 봐도 너에게 특별한 물건이 있어? |
| [o] | FRP-TR-03 | 승계 | question | personal_world | describe | 없음 | 혼자만 알고 싶을 만큼 아끼는 장소는 어떤 곳이야? |
| [ o] | FRP2-TR-04 | 표현 수정 | question | lived_experience | memory_recall | 없음 | 어릴 때 받은 선물 중 지금도 가장 생생하게 기억나는 건 뭐였어? |
| [ o] | FRP2-TR-05 | 표현 수정 | question | lived_experience | memory_recall | 조건부 | 버리지 못하고 남겨둔 오래된 물건이 있다면, 어떤 사연 때문에 지금까지 남겨뒀어? |
| [o] | FRP-TR-06 | 승계 | question | scenario | playful_imagination | 없음 | 어린 시절의 너에게서 지금 하나 가져올 수 있다면 뭘 가져오고 싶어? |

## 2. 처음의 호감과 관계 속 변화

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [ o] | FRP2-EA-01 | 표현 수정 | question | lived_experience | memory_recall | 없음 | 처음 만난 날, 상대의 목소리나 말투는 어떻게 기억나? |
| [o] | FRP-EA-02 | 승계 | question | lived_experience | memory_recall | 없음 | 상대가 생각보다 재미있는 사람이라고 처음 느낀 순간은 언제야? |
| [ o] | FRP2-EA-03 | 표현 수정 | question | lived_experience | memory_recall | 없음 | 연애 초반 상대가 유난히 좋아했던 건 뭐였어? |
| [ o] | FRP2-EA-04 | 표현 수정 | question | lived_experience | memory_recall | 없음 | 처음 상대에게 잘 보이고 싶어서 무엇을 가장 신경 썼어? |
| [o] | FRP-EA-05 | 승계 | question | relationship_change | describe | 없음 | 만나면서 상대에게 새로 생긴 좋은 습관이 있어? |
| [ o] | FRP2-EA-06 | 표현 수정 | question | relationship_change | describe | 없음 | 처음에는 몰랐지만 만나면서 점점 좋아진 상대의 모습은 뭐야? |

## 3. 둘의 추억을 새롭게 꺼내기

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [ o] | FRP2-SM-01 | 대체 | question | shared_memory | memory_recall | 없음 | 둘이 함께한 날 중 제목을 붙여보고 싶은 하루는 언제야? |
| [ o] | FRP2-SM-02 | 대체 | question | sensory_memory | memory_recall | 없음 | 둘이 함께한 순간을 떠올릴 때 같이 생각나는 소리나 냄새는 뭐야? |
| [ x] | FRP2-SM-03 | 대체 | question | shared_memory | memory_recall | 없음 | 둘이 함께한 일 중 당시보다 지금 더 웃기게 느껴지는 건 뭐야? |
| [ o] | FRP2-SM-04 | 대체 | reflection | shared_memory | creative_expression | 없음 | 둘의 추억 하나에 영화 제목처럼 이름을 붙여봐. |
| [ o] | FRP2-SM-05 | 대체 | reflection | shared_memory | creative_expression | 없음 | 둘의 추억 하나를 세 개의 이모티콘으로 표현해봐. |
| [ o] | FRP2-SM-06 | 표현 수정 | question | shared_memory | playful_imagination | 없음 | 둘이 처음 함께 해본 일 하나를 다시 한다면, 무엇을 다르게 해보고 싶어? |

## 4. 상대의 관점으로 보기

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [o] | FRP-PP-01 | 승계 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 자주 쓰는 말투를 다정하게 흉내 내서 오늘 하루를 정리해봐. |
| [o] | FRP-PP-02 | 승계 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 너를 다정하게 소개한다고 상상하고 한 문장으로 적어봐. |
| [o] | FRP-PP-03 | 승계 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 고를 것 같은 네 장점 세 가지를 적어봐. |
| [ o] | FRP2-PP-04 | 대체 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 너를 만화 캐릭터로 그린다고 상상하고, 어떤 표정일지 적어봐. |
| [o] | FRP-PP-05 | 승계 | playful_activity | perspective_taking | playful_imagination | 없음 | 상대가 지금 보낼 것 같은 이모티콘 하나와 그 이유를 적어봐. |
| [o] | FRP-PP-06 | 승계 | playful_activity | role_swap | playful_imagination | 없음 | 서로 역할이 바뀐 하루를 상상하고 가장 먼저 할 일을 적어봐. |

## 5. 상대에게 바라는 작은 돌봄

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [o] | FRP-CW-01 | 승계 | reflection | current_need | guided_reflection | 없음 | 상대가 계속 해줬으면 하는 행동 하나와 그 이유를 적어봐. |
| [ o] | FRP2-CW-02 | 표현 수정 | question | current_need | short_answer | 없음 | 요즘 상대가 먼저 어떤 걸 물어봐주면 좋겠어? |
| [ o] | FRP2-CW-03 | 표현 수정 | question | current_need | short_answer | 없음 | 상대에게 작은 부탁 하나를 한다면 무엇을 부탁하고 싶어? |
| [ o] | FRP2-CW-04 | 표현 수정 | question | current_need | short_answer | 없음 | 특별한 날이 아니어도 상대가 무엇을 챙겨주면 기분이 좋아질까? |
| [ o] | FRP2-CW-05 | 표현 수정 | question | current_need | short_answer | 없음 | 상대가 먼저 "같이 하자"고 말해주면 가장 반가울 일은 뭘까? |
| [ o] | FRP2-CW-06 | 표현 수정 | question | current_need | short_answer | 없음 | 요즘 네가 애쓰는 일 중 상대가 알아줬으면 하는 건 뭐야? |

## 6. 하지 않았으면 하는 것과 경계

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [ o] | FRP2-BN-01 | 표현 수정 | question | boundary | short_answer | 없음 | 장난으로도 편하게 넘기기 어려운 말이나 행동은 어떤 거야? |
| [o] | FRP-BN-02 | 승계 | question | boundary | describe | 없음 | 다른 사람 앞에서 상대가 지켜줬으면 하는 선이 있어? |
| [ o] | FRP2-BN-03 | 표현 수정 | question | privacy | describe | 없음 | 둘의 사진이나 이야기를 다른 사람에게 전할 때, 어떤 내용은 꼭 먼저 물어봐줬으면 해? |
| [o] | FRP-BN-04 | 승계 | question | communication | describe | 없음 | 약속이 바뀔 때 상대가 어떻게 알려줬으면 해? |
| [ o] | FRP2-BN-05 | 표현 수정 | question | conflict | describe | 없음 | 감정이 격해졌을 때 어떤 식의 대화가 가장 힘들어? |
| [o] | FRP-BN-06 | 승계 | reflection | boundary | guided_reflection | 없음 | 상대가 하지 않았으면 하는 행동 하나를, 대신 바라는 행동과 함께 적어봐. |

## 7. 둘만의 약속과 작은 활동

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [o] | FRP-AG-01 | 승계 | agreement_prompt | relationship_agreement | collaborative | 없음 | 서로에게 꼭 지켜주고 싶은 약속을 한 문장으로 적어봐. |
| [o] | FRP-AG-02 | 승계 | agreement_prompt | conflict_repair | collaborative | 없음 | 둘이 다툴 때 잠깐 멈추자는 신호를 하나 정해봐. |
| [o] | FRP-AG-03 | 승계 | agreement_prompt | communication | collaborative | 없음 | 바쁜 날에도 유지하고 싶은 최소한의 연락 방식을 적어봐. |
| [o] | FRP-AG-04 | 승계 | agreement_prompt | personal_space | collaborative | 없음 | 혼자 쉬고 싶다는 뜻을 편하게 전할 문장을 만들어봐. |
| [ o] | FRP2-AG-05 | 대체 | agreement_prompt | shared_activity | collaborative | 없음 | 둘이 한 달에 한 번 같이 하고 싶은 작은 일을 하나 정해봐. |
| [o] | FRP-AG-06 | 승계 | agreement_prompt | appreciation | collaborative | 없음 | 서로 잘한 일을 발견했을 때 표현할 둘만의 방식을 정해봐. |

## 8. 상대에게 들려주고 싶은 과거

| 검토 | ID | 상태 | prompt_kind | 각도 | 답변 형식 | 전제 | 콘텐츠 |
|---|---|---|---|---|---|---|---|
| [o] | FRP-SH-01 | 승계 | question | personal_history | describe | 없음 | 상대가 아직 모를 것 같은 어린 시절의 네 모습은 뭐야? |
| [o] | FRP-SH-02 | 승계 | question | personal_history | memory_recall | 없음 | 상대에게 들려주고 싶은 학창 시절 이야기가 있어? |
| [ o] | FRP2-SH-03 | 표현 수정 | question | personal_history | memory_recall | 없음 | 상대에게 예전에 즐기던 취미나 놀이 하나를 소개한다면 뭘 고를래? |
| [o] | FRP-SH-04 | 승계 | question | scenario | playful_imagination | 없음 | 네 과거의 한 장면을 상대가 직접 볼 수 있다면 어떤 날을 고를래? |
| [o] | FRP-SH-05 | 승계 | question | relationship_change | describe | 없음 | 옛 친구가 지금의 너를 보면 가장 놀랄 변화는 뭐야? |
| [o] | FRP-SH-06 | 승계 | playful_activity | perspective_taking | playful_imagination | 없음 | 어릴 때의 네가 지금 상대를 만났다고 상상하고, 처음 건넬 말을 적어봐. |

## 검토 결과 기록

| 항목 | 수량 |
|---|---:|
| 전체 후보 | 48개 |
| v1 승인 문장 승계 | 25개 |
| 승인 주제 표현 수정 | 16개 |
| v1 제외 항목 대체 | 7개 |
| 사용자 확정 | 47개 |
| 사용자 제외 | 1개 |
| 재검토 대기 | 0개 |
| 확정 일반 질문 | 30개 |
| 확정 활동형 프롬프트 | 17개 |
| 확정 질문의 `~있어?` 종결 | 4개 / 30개 |
| 이항 선택 | 0개 |
| 빈칸 채우기 | 0개 |

## 운영 전 조건

- 사용자 검토를 마친 `[o]` 47개만 최종 목록에 포함한다.
- 확정된 `question` 30개만 일반 질문 후보에 합친다.
- 활동형 17개는 `prompt_kind` 저장, 콘텐츠별 안내 문구, 답변 저장 방식과
  접근성 라벨을 구현한 뒤 별도 트랙으로 노출한다.
- 경계와 약속 관련 콘텐츠는 가벼운 기억이나 놀이형 콘텐츠 사이에 배치하고
  연속으로 노출하지 않는다.
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
