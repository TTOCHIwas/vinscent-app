# AI Learning Foundation Design

작성일: 2026-07-20

## 1. 목표

무료 질문 24개를 통해 개인과 커플에 대한 초기 AI 프로필을 만들고,
25번째 질문부터 부족한 정보와 최근 변화를 보완하는 개인화 질문을 제공한다.

이 단계에서 AI 학습은 사용자별 모델 파인튜닝을 뜻하지 않는다. 답변에서
근거가 있는 기억 후보를 추출하고, 사용자 확인을 거쳐 저장한 뒤 다음 AI
작업에서 필요한 기억만 조회하는 구조를 뜻한다.

## 2. 현재 경계

- 질문은 두 번째 스토리 카드가 저장되는
  `private.assign_question_to_story_loop` 안에서 즉시 배정된다.
- 답변 두 개가 저장되면 `daily_questions.status`와
  `daily_story_loops.status`가 `completed`로 전환된다.
- 모바일은 질문 배정 방식을 알지 않고 story loop read RPC 결과만 소비한다.
- AI API 서버 디렉터리는 존재하지만 아직 구현은 없다.

카드 저장 트랜잭션 안에서 외부 LLM을 호출하면 저장 지연과 장애 전파가
발생한다. 따라서 AI는 다음 질문을 미리 추천하고, 카드 저장 트랜잭션은 그
추천을 소비하거나 DB fallback을 사용해야 한다.

## 3. 질문 커리큘럼

### 3.1 고정 질문

- 버전 1은 24개 질문으로 구성한다.
- 6개 학습 영역마다 4개 질문을 둔다.
- 질문마다 stable key, 커리큘럼 위치, 영역, 질문 각도를 저장한다.
- 기존 24개 질문은 비활성화하되 과거 FK 보존을 위해 삭제하지 않는다.
- 신규 커리큘럼 질문만 활성화한다.

학습 영역:

1. 개인 성향과 가치관
2. 애정 표현과 정서적 지원
3. 의사소통과 갈등 회복
4. 일상 취향과 생활 방식
5. 관계의 기억과 강점
6. 미래 기대와 관계의 경계

질문 각도:

- preference
- lived_experience
- scenario
- current_need

### 3.2 배정

1. 유효한 AI 사전 추천이 있으면 해당 질문을 사용한다.
2. 추천이 없거나 유효하지 않으면 아직 사용하지 않은 현재 커리큘럼 질문을
   `curriculum_position` 순서로 배정한다.
3. 24개를 모두 사용했고 AI 생성 질문이 준비되지 않았다면 최근 사용이 가장
   오래된 curated 질문을 fallback으로 사용한다.
4. 질문 배정 실패가 카드 저장 실패로 이어지지 않도록 항상 curated fallback을
   유지한다.

## 4. 동의

- AI 분석은 커플 구성원 두 명이 모두 동의한 경우에만 실행한다.
- 동의에는 정책 버전을 기록한다.
- 사용자는 언제든 동의를 철회할 수 있다.
- 철회 시 대기 중인 AI 작업과 질문 추천은 취소한다.
- 원본 질문과 답변 보관 여부는 기존 커플 기록 정책을 유지한다.
- AI 기억 노출과 후속 처리는 현재 동의 상태를 다시 확인한다.

## 5. 기억

기억은 `personal`과 `couple` scope로 구분한다.

- personal 기억은 대상 사용자만 승인하거나 거절할 수 있다.
- 승인 전 personal 기억은 대상 사용자에게만 보인다.
- 승인된 personal 기억만 상대 사용자에게 공유한다.
- couple 기억은 두 사용자 모두 승인해야 활성화한다.
- 어느 한쪽이 거절하면 해당 기억은 거절 상태가 된다.
- 기억은 statement, kind, confidence, 관찰 시점과 근거 answer id를 가진다.
- 기억 원문과 근거 없이 성격이나 관계를 단정하지 않는다.

## 6. 비동기 작업

질문 상태가 처음 `completed`가 될 때 다음 작업을 중복 없이 생성한다.

- extract_memories
- generate_feedback
- select_curated_question: 완료된 커리큘럼 질문이 24개 미만인 경우
- generate_personalized_question: 24개가 완료된 경우

동의를 나중에 완료한 커플에는 `rebuild_profile` 작업을 생성해 완료된 공개
답변을 다시 처리할 수 있게 한다.

작업에는 원문 답변을 복사하지 않는다. couple id와 daily question id만 저장하고
worker가 실행 직전에 권한과 동의를 다시 확인해 원문을 조회한다.

## 7. 실행 로그

AI 실행 로그에는 다음만 저장한다.

- 작업 종류
- provider와 model
- prompt version
- 입력 question/answer 식별자
- 상태, 지연시간, token 사용량
- 안전 검사 상태와 최소 오류 코드

전체 prompt와 원문 응답은 기본 로그에 저장하지 않는다.

## 8. 모델 독립 계약

AI API 도메인 계층은 다음 기능별 인터페이스를 제공한다.

- rankFoundationQuestions
- extractMemoryCandidates
- generateCoupleFeedback
- generatePersonalizedQuestion

provider에 전달하는 문맥은 실제 user id 대신 `partner_a`, `partner_b` 별칭을
사용한다. 결과의 memory evidence는 입력에 포함된 answer id만 참조할 수 있어야
한다.

## 9. 진행도

- 0~7개: collecting
- 8~15개: exploring
- 16~23개: refining
- 24개 이상: ready

진행도는 단순 답변 행 수가 아니라 현재 커리큘럼의 서로 다른 질문 중 두 답변이
모두 완료된 수로 계산한다. 영역별 완료 수를 함께 반환한다.

## 10. 구현 단계와 커밋 메시지

1. 질문 커리큘럼과 테스트
   - `feat(ai): add versioned foundation question curriculum`
2. 동의, 기억, 작업과 실행 로그
   - `feat(ai): add consent and memory persistence foundation`
3. 답변 완료 작업과 질문 추천 배정
   - `feat(ai): connect completed answers to learning jobs`
4. 모델 독립 AI API 도메인 계약
   - `feat(ai): scaffold provider independent learning contracts`

## 11. 이번 단계 제외

- 실제 LLM provider 연결
- 최종 모델 선정
- 유료 집중 질문
- 벡터 검색
- 자유형 AI 챗봇
- 자체 추론 장비와 GPU 서버
- AI 탭 최종 UI
