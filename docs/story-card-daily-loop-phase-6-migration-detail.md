# 스토리 카드 일일 루프 6단계 마이그레이션 상세 설계

작성일: 2026-07-06

본 문서는 6단계 migration, 즉 `daily_questions.story_loop_id`를 최종 제약으로 잠그는 단계의 상세 설계 문서다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`
- `docs/story-card-daily-loop-phase-4-migration-detail.md`
- `docs/story-card-daily-loop-phase-5-migration-detail.md`

기준 마이그레이션:

- `supabase/migrations/20260531002000_create_daily_questions.sql`
- `supabase/migrations/20260706002000_link_daily_questions_to_story_loops.sql`
- `supabase/migrations/20260706003000_bridge_legacy_daily_question_writes_to_story_loops.sql`
- `supabase/migrations/20260706004000_backfill_story_loops_from_daily_questions.sql`

---

## 1. 이번 단계의 목적

6단계 migration의 목적은 전환 기간 동안 nullable로 열어 두었던 `daily_questions.story_loop_id`를 최종 제약으로 닫아, 질문 row와 하루 루트의 1:1 연결을 DB 레벨에서 강제하는 것이다.

이번 단계에서 하는 일은 아래 네 가지다.

1. 제약 강화 전 선행 조건을 다시 검증한다.
2. `daily_questions.story_loop_id`에 대한 전역 unique 보장을 추가한다.
3. `daily_questions.story_loop_id`를 `not null`로 전환한다.
4. 3단계에서 임시로 둔 partial index를 정리한다.

이번 단계에서 하지 않는 일은 아래와 같다.

1. read RPC 추가
2. write RPC 전환
3. `daily_questions.status` 제거
4. `couple_id`, `assigned_date` 제거

즉 6단계는 구조 전환의 마지막 데이터 제약 잠금 단계다.

---

## 2. 현재 코드 기준 전제

6단계는 반드시 4단계와 5단계가 끝난 뒤에만 가능하다.

그 이유는 아래와 같다.

1. 4단계 이전에는 live traffic이 새 null `story_loop_id`를 만들 수 있었다.
2. 5단계 이전에는 과거 `daily_questions`에 남아 있던 null row가 존재할 수 있었다.
3. 따라서 6단계는 "재발 경로 차단"과 "과거 데이터 정리"가 모두 끝난 뒤에만 의미를 가진다.

정리하면, 6단계는 새로운 문제를 해결하는 단계가 아니라 4단계와 5단계가 만든 정합성을 DB 제약으로 영구 고정하는 단계다.

---

## 3. 이번 단계 요구사항

## 3.1 `story_loop_id`는 모든 질문 row에서 필수여야 한다

최종 상태에서는 모든 `daily_questions` row가 반드시 하루 루트 하나를 가져야 한다.

즉:

- `daily_questions.story_loop_id is not null`

이 제약은 더 이상 application helper의 선의에 의존하지 않고 DB가 직접 보장해야 한다.

## 3.2 질문 row와 루프 row는 1:1이어야 한다

물리 설계 기준으로 `daily_questions`는 하루 루트 아래 질문 자식이다.

이 말은 반대로:

- 하나의 `daily_story_loops.id`를 두 개 이상의 `daily_questions`가 공유하면 안 된다

따라서 최종 상태는 아래를 만족해야 한다.

- `unique (story_loop_id)`

## 3.3 기존 복합 FK는 유지한다

6단계에서 새로 추가하는 unique / not null 제약은 3단계에서 만든 아래 FK를 대체하는 것이 아니다.

- `(couple_id, assigned_date, story_loop_id)` ->
  `(couple_id, couple_date, id)`

이 복합 FK는 계속 유지되어야 한다.

이유:

1. 단순 `story_loop_id -> daily_story_loops(id)` FK만으로는 질문 row의 `couple_id`, `assigned_date`가 루프와 같은지 보장되지 않는다.
2. 현재 설계의 핵심은 질문 row가 자기 커플/날짜와 일치하는 하루 루프만 가리키게 만드는 것이다.

## 3.4 partial index는 최종 unique 제약 이후 정리한다

3단계에서 추가한 index는 아래와 같다.

- `daily_questions_story_loop_id_idx`
- `where story_loop_id is not null`

이 index는 nullable 전환 기간 동안 lookup 보조 역할로는 유효하지만, 6단계 이후에는 최종 unique index/constraint와 역할이 겹친다.

따라서 6단계가 끝나면 이 partial index는 제거한다.

---

## 4. SQL 설계 방향

권장 흐름은 아래와 같다.

1. 선행 조건 검증
2. unique index 생성
3. unique constraint 부여
4. `story_loop_id set not null`
5. 기존 partial index 제거

권장 초안:

```sql
do $$
begin
  if exists (
    select 1
    from public.daily_questions
    where story_loop_id is null
  ) then
    raise exception 'daily_question_story_loop_not_null_prerequisite_failed';
  end if;

  if exists (
    select story_loop_id
    from public.daily_questions
    group by story_loop_id
    having count(*) > 1
  ) then
    raise exception 'daily_question_story_loop_unique_prerequisite_failed';
  end if;
end;
$$;

create unique index if not exists daily_questions_story_loop_unique_idx
  on public.daily_questions (story_loop_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.daily_questions'::regclass
      and conname = 'daily_questions_story_loop_unique'
  ) then
    alter table public.daily_questions
      add constraint daily_questions_story_loop_unique
      unique using index daily_questions_story_loop_unique_idx;
  end if;
end;
$$;

alter table public.daily_questions
  alter column story_loop_id set not null;

drop index if exists public.daily_questions_story_loop_id_idx;
```

---

## 5. 순서 선택 이유

## 5.1 왜 선행 조건 검증을 먼저 하는가

`alter column set not null`이나 unique constraint는 실패하면 이미 긴 테이블 검사를 시작한 뒤 터진다.

사전에 더 명확한 예외 메시지로 막는 편이 좋다.

따라서 먼저 검증한다.

1. null row 존재 여부
2. 같은 `story_loop_id`를 두 질문 row가 공유하는지 여부

## 5.2 왜 unique를 먼저 추가하는가

이 단계의 본질은 단순 non-null화가 아니라 1:1 연결 잠금이다.

따라서 먼저 unique 보장을 만들어 두고, 그 위에서 필수 연결로 닫는 편이 더 의도가 분명하다.

또한 이미 5단계에서 null row가 제거되었으므로 unique index 생성 시 null 다중 허용에 기대는 상태가 아니다.

## 5.3 왜 partial index를 마지막에 제거하는가

최종 unique index / constraint가 성공적으로 만들어지기 전까지는 기존 partial index를 남겨 두는 편이 안전하다.

먼저 지우고 실패하면 읽기 성능에 불필요한 공백이 생긴다.

---

## 6. idempotency와 안전성

## 6.1 unique index / constraint는 재실행 가능해야 한다

운영 migration은 재실행 가능성이 있다.

따라서:

1. unique index는 `if not exists`
2. unique constraint는 `pg_constraint` 검사 후 `add constraint`

형태로 둔다.

## 6.2 `set not null`은 재실행 가능하다

이미 `not null`이면 같은 구문을 다시 실행해도 문제 없다.

따라서 별도 guard 없이 그대로 둔다.

## 6.3 partial index drop은 `if exists`로 둔다

이미 제거된 뒤 rerun 되어도 실패하지 않게 한다.

---

## 7. 검증 기준

6단계 migration 이후 아래가 확인되어야 한다.

1. `daily_questions.story_loop_id`가 모든 row에서 null이 아니다.
2. `daily_questions_story_loop_unique` constraint가 존재한다.
3. 하나의 `daily_story_loops.id`를 두 개 이상의 `daily_questions`가 참조하지 않는다.
4. 3단계의 복합 FK는 그대로 유지된다.
5. `daily_questions_story_loop_id_idx` partial index는 제거된다.

---

## 8. 다음 단계와의 연결

### 8.1 7단계 read RPC

6단계가 끝나야 read RPC는 `daily_questions`와 `daily_story_loops`의 연결을 전제로 더 단순하게 읽을 수 있다.

즉:

- null guard가 필요 없어진다.
- 한 질문 = 한 루프라는 전제를 그대로 사용할 수 있다.

### 8.2 8단계 write RPC 전환

이후 write RPC에서 질문 생성 책임이 story loop 쪽으로 완전히 넘어가더라도, 기존 질문 row는 이미 최종 제약 아래에서 동작하게 된다.

즉 6단계는 이후 전환 단계의 안전망이다.

---

## 9. 최종 결론

6단계의 본질은 `story_loop_id`를 붙이는 것이 아니라, 이제 그 연결이 절대 깨질 수 없도록 DB 제약으로 잠그는 것이다.

이번 단계에서 확정하는 내용은 아래 다섯 가지다.

1. 모든 `daily_questions` row는 반드시 `story_loop_id`를 가져야 한다.
2. 하나의 loop는 하나의 질문 row만 가질 수 있다.
3. 복합 FK는 유지된다.
4. 임시 partial index는 최종 unique 제약 이후 제거한다.
5. 이 단계 이후 질문-루프 연결은 helper가 아니라 DB 제약이 최종 권위가 된다.
