# 스토리 카드 일일 루프 3단계 마이그레이션 상세 설계

작성일: 2026-07-06

본 문서는 3단계 migration, 즉 기존 `daily_questions` row가 하루 공용 루트 `daily_story_loops`를 가리킬 수 있도록 연결 지점을 추가하는 단계의 상세 설계 문서다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`

기준 코드:

- `apps/mobile/lib/features/questions/data/daily_question_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`

기준 마이그레이션:

- `supabase/migrations/20260531002000_create_daily_questions.sql`
- `supabase/migrations/20260623001000_add_readable_access_and_couple_timezone_dates.sql`

---

## 1. 이번 단계의 목적

3단계 migration의 목적은 기존 `daily_questions` row가 새 하루 공용 루트 `daily_story_loops`를 가리킬 수 있도록 연결 축을 먼저 추가하는 것이다.

이번 단계에서 하는 일은 아래 다섯 가지다.

1. `public.daily_questions.story_loop_id` nullable 컬럼 추가
2. `daily_story_loops` 쪽에 질문-루프 복합 참조용 키 추가
3. 질문 row가 자기 커플, 자기 날짜 루프만 가리키도록 복합 foreign key 추가
4. FK를 `not valid -> validate` 순서로 적용
5. 이후 backfill과 read/write 전환을 위한 `story_loop_id` 인덱스 추가

이번 단계에서 하지 않는 일은 아래와 같다.

1. 기존 `daily_questions` row backfill
2. `story_loop_id not null` 강제
3. `unique (story_loop_id)` 강제
4. 기존 질문 RPC를 `story_loop_id` 기준으로 동작하게 수정

즉 3단계는 질문 모델을 바꾸는 단계가 아니라, 질문 row를 새 루프 아래에 안전하게 매달 수 있게 준비하는 단계다.

---

## 2. 현재 코드 기준 메서드 추적

### 2.1 caller

현재 앱에서 질문 축을 직접 읽는 caller는 아래 네 갈래다.

1. 오늘 질문 조회
   - `apps/mobile/lib/features/questions/data/daily_question_repository.dart`
   - RPC `get_or_assign_today_question`
2. 오늘 답변 상태 조회
   - `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`
   - RPC `get_today_question_answer_state`
3. 오늘 답변 저장
   - `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`
   - RPC `submit_today_question_answer`
4. 날짜별 질문/답변 상세 조회
   - RPC `get_daily_question_answer_state_for_date`

### 2.2 actual method in use

현재 공개 RPC와 helper는 모두 `public.daily_questions`를 하루 공용 루트처럼 사용한다.

중심 컬럼은 아래 네 가지다.

- `couple_id`
- `question_id`
- `assigned_date`
- `status`

즉 지금 질문 축은 “질문 row 자체가 그날의 중심 row”라는 전제를 공유한다.

### 2.3 missing link

이번 단계에서 빠져 있는 것은 새로운 조회 함수나 쓰기 함수가 아니라 아래 연결 자체다.

- `daily_questions` -> `daily_story_loops`

이 연결이 없으면 이후 단계에서 아래가 모두 불안정해진다.

1. backfill이 어떤 루프를 어떤 질문과 묶는지 DB가 보장하지 못한다.
2. write RPC가 질문 상태와 루프 상태를 함께 갱신할 기준 축이 없다.
3. 질문 row가 다른 커플, 다른 날짜 루프를 잘못 가리켜도 DB가 막지 못한다.

### 2.4 root cause

현재 구조의 근원 문제는 `daily_questions`가 독립 루트로 존재하고 있으며, 새 부모 루트 `daily_story_loops`와의 관계가 스키마 차원에서 정의되어 있지 않다는 점이다.

따라서 3단계의 본질은 기능 추가가 아니라 관계 모델 보강이다.

---

## 3. 이번 단계 요구사항

## 3.1 `story_loop_id`는 nullable로 시작한다

추가 컬럼은 아래 형태로 시작한다.

- `public.daily_questions.story_loop_id uuid null`

nullable로 시작해야 하는 이유는 다음과 같다.

1. 기존 `daily_questions` row에는 아직 연결 대상 loop가 없다.
2. 그 연결은 다음 단계의 브리지와 backfill에서 채워진다.
3. 지금 바로 `not null`을 걸면 기존 질문 축이 즉시 깨진다.

## 3.2 foreign key는 지금 바로 건다

`story_loop_id`가 null 허용이더라도 참조 무결성은 지금부터 잡아야 한다.

이유는 다음과 같다.

1. 이후 브리지와 backfill에서 잘못된 loop를 연결하는 실수를 즉시 막을 수 있다.
2. 이후 write RPC가 새 연결을 쓰기 시작할 때도 잘못된 값 주입을 막을 수 있다.
3. `on delete cascade`로 loop 삭제 시 질문 row 정리 방향도 고정할 수 있다.

## 3.3 연결 무결성은 "같은 커플, 같은 날짜"까지 DB가 보장해야 한다

단순히 `story_loop_id`가 존재하는 loop id인지 확인하는 것만으로는 부족하다.

이번 단계에서 잡아야 하는 요구사항은 아래 두 가지다.

1. `daily_questions.couple_id`와 `daily_story_loops.couple_id`가 같아야 한다.
2. `daily_questions.assigned_date`와 `daily_story_loops.couple_date`가 같아야 한다.

즉 질문 row는 아무 loop를 가리키는 것이 아니라 자기 커플, 자기 날짜 loop만 가리켜야 한다.

이 요구사항은 애플리케이션 규칙이 아니라 DB FK 제약으로 직접 보장되어야 한다.

## 3.4 FK는 명시 이름과 부모 참조 키를 먼저 준비한 뒤 건다

권장 constraint 이름:

- `daily_questions_story_loop_match_fkey`

부모 쪽 준비 제약:

- `daily_story_loops_reference_unique`
- `unique (couple_id, couple_date, id)`

이렇게 분리하는 이유는 다음과 같다.

1. 배포 실패 범위를 줄이기 쉽다.
2. `not valid -> validate` 패턴을 쓰기 쉽다.
3. 이후 문제 발생 시 어느 단계에서 깨졌는지 추적이 쉽다.

## 3.5 인덱스는 partial index로 둔다

권장 인덱스:

- `daily_questions_story_loop_id_idx`
- key: `(story_loop_id)`
- condition: `where story_loop_id is not null`

이유:

1. 3단계 직후 대부분의 기존 row는 null 상태다.
2. 전체 인덱스를 만들면 쓸모 없는 null row까지 인덱싱한다.
3. 실제 조회는 연결된 질문 row를 대상으로 하므로 non-null partial index가 맞다.

## 3.6 unique는 아직 걸지 않는다

`unique (story_loop_id)`는 3단계에서 걸지 않는다.

이유:

1. 3단계 시점에는 null row가 대부분이다.
2. 먼저 연결 축을 만들고, 브리지와 backfill이 끝난 뒤 정합성을 본 다음 강제해야 한다.
3. 전체 단계 설계상 unique는 6단계 제약 강화에서 거는 것이 맞다.

---

## 4. SQL 설계 방향

권장 순서는 아래와 같다.

1. `daily_story_loops` 참조 키 추가
2. `daily_questions.story_loop_id` 컬럼 추가
3. FK 추가 (`not valid`)
4. FK validate
5. partial index 추가

권장 초안:

```sql
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.daily_story_loops'::regclass
      and conname = 'daily_story_loops_reference_unique'
  ) then
    alter table public.daily_story_loops
      add constraint daily_story_loops_reference_unique
      unique (couple_id, couple_date, id);
  end if;
end;
$$;

alter table public.daily_questions
  add column story_loop_id uuid;

alter table public.daily_questions
  add constraint daily_questions_story_loop_match_fkey
    foreign key (couple_id, assigned_date, story_loop_id)
    references public.daily_story_loops(couple_id, couple_date, id)
    on delete cascade
    not valid;

alter table public.daily_questions
  validate constraint daily_questions_story_loop_match_fkey;

create index daily_questions_story_loop_id_idx
  on public.daily_questions (story_loop_id)
  where story_loop_id is not null;
```

---

## 5. 이 단계가 끝난 뒤 보장되는 것

이번 단계 이후에도 아래는 그대로 유지된다.

1. `daily_questions.couple_id + assigned_date` 기준 오늘 질문 조회
2. `daily_questions.status` 기준 답변 상태 계산
3. 기존 질문/답변 RPC 이름과 반환 형식
4. 기존 모바일 repository 호출 구조

즉 3단계 적용 직후에도 기존 질문 축은 깨지지 않는다.

---

## 6. 다음 단계와의 연결

## 6.1 4단계 브리지

4단계에서는 기존 질문 생성 helper가 더 이상 null `story_loop_id`를 만들지 못하도록 브리지 로직을 먼저 넣는다.

핵심은 아래 두 가지다.

1. 새 `daily_questions` row 생성 시 loop를 먼저 확보한 뒤 `story_loop_id`를 채워 insert 한다.
2. 오늘 이미 존재하는 null row도 helper 진입 시 self-heal 한다.

이 단계가 먼저 들어가야 5단계 backfill의 입력 집합이 닫힌다.

## 6.2 5단계 backfill

5단계에서는 기존 `daily_questions` row마다 아래가 수행된다.

1. `(couple_id, assigned_date)` 기준 `daily_story_loops` row 생성
2. 생성된 루프 id를 `story_loop_id`에 채움

이번 단계는 컬럼/FK/index를 바로 그 backfill의 착지 지점으로 준비하는 단계다.

## 6.3 6단계 제약 강화

backfill이 끝나면 아래를 건다.

1. `story_loop_id set not null`
2. `unique (story_loop_id)`

즉 3단계는 6단계 강화를 위한 조건을 만드는 단계다.

## 6.4 8단계 write RPC 전환

질문 생성과 답변 저장이 루프 상태와 질문 상태를 함께 갱신하려면 질문 row가 어떤 루프 소속인지 확실히 알아야 한다.

이번 단계가 그 연결 축을 제공한다.

---

## 7. 검증 기준

3단계 migration 이후 아래가 확인되어야 한다.

1. `public.daily_questions`에 `story_loop_id` 컬럼이 생긴다.
2. 기존 row는 모두 `story_loop_id is null` 상태로 그대로 남는다.
3. `story_loop_id`가 채워진 질문 row는 반드시 같은 `couple_id`, 같은 `assigned_date`를 가진 루프만 가리킬 수 있다.
4. `story_loop_id is not null` row를 대상으로 하는 partial index가 준비된다.
5. 기존 질문 조회/답변 저장 RPC의 이름, 반환 형식, 기존 동작은 변하지 않는다.

---

## 8. 최종 결론

3단계의 본질은 기존 질문 row를 새 루프 아래에 매달 수 있게 하는 연결 축을 DB 차원에서 먼저 여는 것이다.

이번 단계에서 확정하는 내용은 아래 여섯 가지다.

1. `story_loop_id`는 nullable로 추가한다.
2. FK는 지금부터 건다.
3. FK는 같은 커플, 같은 날짜까지 DB가 보장해야 한다.
4. 부모 쪽 복합 unique를 먼저 준비한다.
5. 인덱스는 non-null partial index로 둔다.
6. unique와 not null은 6단계에서 강제한다.
