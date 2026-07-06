# 스토리 카드 일일 루프 5단계 마이그레이션 상세 설계

작성일: 2026-07-06

본 문서는 5단계 migration, 즉 기존 `daily_questions` 데이터를 `daily_story_loops`로 backfill 하고, 카드 없는 브리지 loop의 상태를 정규화하는 단계의 상세 설계 문서다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`
- `docs/story-card-daily-loop-phase-4-migration-detail.md`

기준 마이그레이션:

- `supabase/migrations/20260531002000_create_daily_questions.sql`
- `supabase/migrations/20260531006000_create_daily_question_answers.sql`
- `supabase/migrations/20260601000000_reveal_completed_daily_question_answers.sql`
- `supabase/migrations/20260706003000_bridge_legacy_daily_question_writes_to_story_loops.sql`

---

## 1. 이번 단계의 목적

5단계 migration의 목적은 기존 `daily_questions` row를 기준으로 최소한의 historical loop를 생성하고, 각 질문 row를 그 loop에 연결한 뒤, 카드 없는 브리지 loop의 상태를 질문 상태와 일치시키는 것이다.

이번 단계에서 하는 일은 아래 다섯 가지다.

1. `story_loop_id is null` 상태의 기존 `daily_questions`를 읽는다.
2. `(couple_id, assigned_date)` 기준 `daily_story_loops` row를 생성한다.
3. 생성했거나 이미 존재하는 loop id를 각 `daily_questions.story_loop_id`에 채운다.
4. 카드 없는 bridge / historical loop의 상태와 타임스탬프를 `daily_questions` 기준으로 정규화한다.
5. 최종 검증으로 미연결 질문 row와 상태 불일치 loop가 남지 않았는지 확인한다.

이번 단계에서 하지 않는 일은 아래와 같다.

1. `story_loop_id not null` 강제
2. `unique (story_loop_id)` 강제
3. story card row backfill
4. read RPC / write RPC 전환

즉 5단계는 카드 데이터를 되살리는 단계가 아니라, 기존 질문 이력을 하루 공용 루트 아래로 정리하고 브리지 흔적을 정규화하는 단계다.

---

## 2. 현재 코드 기준 전제

4단계에서 기존 질문 생성 helper가 브리지화된 뒤에는, live traffic 기준으로 새 null `story_loop_id` row가 더 이상 생기지 않는다.

따라서 5단계는 아래 성질을 가진다.

1. source 집합이 닫혀 있다.
2. 미연결 질문 row는 과거에 이미 남아 있는 null row다.
3. 다만 4단계 적용 직후 self-heal된 row는 이미 `story_loop_id`를 가졌더라도 loop status가 `question_generated`로 남아 있을 수 있다.
4. 따라서 5단계는 단순 연결 보강뿐 아니라 카드 없는 bridge loop 상태 정규화까지 맡는 편이 안전하다.

이 전제가 4단계 이전에는 성립하지 않았다.

---

## 3. 이번 단계 요구사항

## 3.1 backfill 기준 날짜는 재계산하지 않고 `assigned_date`를 그대로 사용한다

이번 단계에서는 timezone을 다시 계산하지 않는다.

이유:

1. 기존 질문 row에는 이미 `assigned_date`가 저장돼 있다.
2. 그 값이 당시 실제 서비스가 사용하던 날짜 기준이다.
3. 지금 다시 `current_date_in_timezone(...)` 같은 계산을 적용하면 historical row를 현재 규칙으로 재해석하게 된다.

따라서 backfill 날짜 기준은 하나로 고정한다.

- `daily_questions.assigned_date`

## 3.2 미연결 질문 row는 `story_loop_id is null`인 기존 질문 row만 대상이다

loop 생성과 연결 보강의 source 대상은 아래 row만이다.

- `public.daily_questions`
- `where story_loop_id is null`

이유:

1. 4단계 이후 새 null row는 더 이상 생기지 않는다.
2. 이미 연결된 row를 다시 연결할 이유가 없다.
3. rerun 시에도 남은 row만 채우는 쪽이 안전하다.

## 3.3 loop는 `(couple_id, assigned_date)` 기준으로 생성한다

historical loop 생성 기준은 아래 조합이다.

- `couple_id`
- `assigned_date`

이유:

1. 기존 `daily_questions`에는 `unique (couple_id, assigned_date)` 제약이 있다.
2. `daily_story_loops`에는 `unique (couple_id, couple_date)`가 있다.
3. 따라서 기존 질문 row 1개는 같은 커플, 같은 날짜 loop 1개에 1:1로 대응한다.

## 3.4 historical loop는 카드 없는 loop다

backfill로 생성되는 loop는 story card를 갖지 않는다.

이유:

1. 기존 시스템에는 story card 테이블이 존재하지 않았다.
2. 이번 단계의 범위는 질문/답변 이력의 부모 루트 복원이다.
3. 존재하지 않았던 카드 데이터를 추정 생성하면 요구사항과 실제 데이터 모두를 왜곡한다.

따라서 backfill loop는 아래 성격으로 정의한다.

- question/answer history anchor
- no `story_loop_cards`

## 3.5 상태 매핑은 `daily_questions.status`를 그대로 신뢰한다

현재 코드 기준으로 `daily_questions.status`는 `submit_today_question_answer(text)`에서 실제 답변 수를 계산해 갱신된다.

따라서 상태 매핑은 아래처럼 고정한다.

- `pending` -> `question_generated`
- `answered_by_one` -> `answered_by_one`
- `completed` -> `completed`

### 왜 `pending -> waiting_partner_card`가 아닌가

새 구조에서 `waiting_partner_card`는 카드 1장만 있고 질문이 아직 생성되지 않은 상태다.

하지만 기존 `daily_questions` row가 존재한다는 것은 이미 질문이 생성된 상태라는 뜻이다.

따라서 카드 정보가 없더라도 질문 단계까지는 이미 도달한 이력으로 해석해야 하므로 `pending`은 `question_generated`로 간다.

## 3.6 타임스탬프는 질문 row의 이력 시점을 최대한 보존한다

cardless bridge loop에 채울 시간값은 아래 규칙으로 정한다.

- `daily_story_loops.question_generated_at = daily_questions.created_at`
- `daily_story_loops.story_edit_locked_at = daily_questions.created_at`
- `daily_story_loops.updated_at = greatest(daily_story_loops.updated_at, daily_questions.updated_at)`

historical loop 신규 insert 시에는 아래도 함께 따른다.

- `daily_story_loops.created_at = daily_questions.created_at`
- `daily_story_loops.updated_at = daily_questions.updated_at`

이유:

1. 기존 시스템에서 질문 row 생성 시점이 곧 질문 생성 시점이다.
2. 질문이 생성되면 카드 수정은 더 이상 허용되지 않는 새 규칙과도 가장 가깝다.
3. `daily_questions.updated_at`은 마지막 질문/답변 연동 시점의 근사값이다.

## 3.7 cardless bridge loop 정규화가 필요하다

4단계 helper는 기존 null row를 self-heal 할 때 loop를 만든다.

하지만 그 loop는 질문이 이미 생성된 흐름만 보장할 뿐, 기존 `daily_questions.status`가 `answered_by_one`, `completed`인 경우까지 자동으로 승격하지는 않는다.

따라서 5단계는 아래 대상을 추가로 정규화해야 한다.

1. `daily_questions.story_loop_id is not null`
2. 연결된 `daily_story_loops`가 존재
3. 연결된 loop에 `story_loop_cards`가 없음

즉 “카드 없는 loop”는 historical loop와 4단계 bridge loop를 함께 포괄하는 정규화 대상이다.

## 3.8 couple 상태로 필터링하지 않는다

backfill과 정규화는 `daily_questions`에 남아 있는 row 전체를 대상으로 한다.

즉 아래 필터는 걸지 않는다.

- active couple만
- readable couple만
- relationship_start_date 유효한 것만

이유:

1. migration은 요청 흐름이 아니라 저장된 데이터 정합 단계다.
2. `daily_questions` row가 살아 있다면 참조 중인 `couples` row도 살아 있다.
3. historical loop는 현재 접근 권한과 무관하게 과거 저장 데이터를 정렬하는 역할이다.

---

## 4. SQL 설계 방향

권장 흐름은 아래와 같다.

1. 미연결 질문 row를 기준으로 historical loop insert
2. `(couple_id, assigned_date)` 기준으로 다시 join 해서 `story_loop_id` update
3. 카드 없는 loop의 상태와 타임스탬프 정규화
4. 최종 검증으로 null 잔존 여부와 상태 불일치 여부 확인

권장 초안:

```sql
insert into public.daily_story_loops (
  couple_id,
  couple_date,
  status,
  question_generated_at,
  story_edit_locked_at,
  created_at,
  updated_at
)
select
  dq.couple_id,
  dq.assigned_date,
  case dq.status
    when 'pending' then 'question_generated'
    when 'answered_by_one' then 'answered_by_one'
    when 'completed' then 'completed'
  end,
  dq.created_at,
  dq.created_at,
  dq.created_at,
  dq.updated_at
from public.daily_questions as dq
where dq.story_loop_id is null
on conflict (couple_id, couple_date) do nothing;

update public.daily_questions as dq
set story_loop_id = dsl.id
from public.daily_story_loops as dsl
where dq.story_loop_id is null
  and dsl.couple_id = dq.couple_id
  and dsl.couple_date = dq.assigned_date;

update public.daily_story_loops as dsl
set
  status = normalized.loop_status,
  question_generated_at = coalesce(
    dsl.question_generated_at,
    normalized.question_generated_at
  ),
  story_edit_locked_at = coalesce(
    dsl.story_edit_locked_at,
    normalized.story_edit_locked_at
  ),
  updated_at = greatest(
    dsl.updated_at,
    normalized.loop_updated_at
  )
from (
  select
    dq.story_loop_id,
    case dq.status
      when 'pending' then 'question_generated'
      when 'answered_by_one' then 'answered_by_one'
      when 'completed' then 'completed'
    end as loop_status,
    dq.created_at as question_generated_at,
    dq.created_at as story_edit_locked_at,
    dq.updated_at as loop_updated_at
  from public.daily_questions as dq
  where dq.story_loop_id is not null
) as normalized
where dsl.id = normalized.story_loop_id
  and not exists (
    select 1
    from public.story_loop_cards as slc
    where slc.story_loop_id = dsl.id
  )
  and (
    dsl.status is distinct from normalized.loop_status
    or dsl.question_generated_at is null
    or dsl.story_edit_locked_at is null
    or dsl.updated_at < normalized.loop_updated_at
  );

do $$
begin
  if exists (
    select 1
    from public.daily_questions
    where story_loop_id is null
  ) then
    raise exception 'daily_question_story_loop_backfill_incomplete';
  end if;

  if exists (
    select 1
    from public.daily_questions as dq
    join public.daily_story_loops as dsl
      on dsl.id = dq.story_loop_id
    where not exists (
      select 1
      from public.story_loop_cards as slc
      where slc.story_loop_id = dsl.id
    )
      and (
        dsl.status is distinct from case dq.status
          when 'pending' then 'question_generated'
          when 'answered_by_one' then 'answered_by_one'
          when 'completed' then 'completed'
        end
        or dsl.question_generated_at is null
        or dsl.story_edit_locked_at is null
        or dsl.updated_at < dq.updated_at
      )
  ) then
    raise exception 'daily_question_story_loop_status_normalization_incomplete';
  end if;
end;
$$;
```

---

## 5. idempotency와 안전성

## 5.1 insert는 `on conflict do nothing`으로 둔다

이유:

1. 이미 삽입된 historical loop가 있으면 재삽입되지 않아야 한다.
2. migration 재실행 시 중복 loop 생성이 막혀야 한다.
3. `daily_story_loops_couple_date_unique`가 자연 dedupe 키다.

## 5.2 update는 미연결 row와 cardless loop만 다룬다

연결 update 대상은 아래로 제한한다.

- `where dq.story_loop_id is null`

정규화 update 대상은 아래로 제한한다.

- `daily_questions.story_loop_id is not null`
- `not exists story_loop_cards`

이유:

1. 이미 연결된 row를 다시 다른 loop로 바꾸지 않기 위해서다.
2. 실제 story card가 있는 미래 loop를 질문 이력 기준으로 덮어쓰지 않기 위해서다.
3. 부분 성공 후 재실행 때 남은 정규화 작업만 수행하기 위해서다.

## 5.3 최종 검증이 이제 유효한 이유

4단계 이전에는 live traffic이 새 null row를 만들 수 있었기 때문에, 마지막 null 검증이 비결정적으로 실패할 수 있었다.

하지만 4단계 이후에는:

1. 기존 helper가 새 row 생성 시 loop를 먼저 확보하고
2. 오늘 기존 null row도 self-heal 하므로
3. backfill 시점에 새 null row가 재생성되지 않는다

따라서 이 단계의 최종 검증은 다시 의미를 가진다.

---

## 6. 검증 기준

5단계 migration 이후 아래가 확인되어야 한다.

1. 기존 `daily_questions` 중 `story_loop_id is null`이던 row가 모두 loop id를 가진다.
2. 모든 연결은 같은 `couple_id`, 같은 `assigned_date`를 가진 loop를 가리킨다.
3. `daily_story_loops`에는 과거 질문 row 수에 대응하는 historical loop가 생성된다.
4. `pending` 질문은 `question_generated` loop로 들어간다.
5. `answered_by_one`, `completed` 질문은 동일한 의미의 loop 상태로 들어간다.
6. cardless bridge loop도 질문 상태 기준으로 정규화된다.
7. created/generated/locked 시간은 `daily_questions.created_at` 기준으로 보존된다.
8. loop `updated_at`은 `daily_questions.updated_at`을 반영한다.
9. rerun 시 중복 loop가 생기지 않는다.

---

## 7. 다음 단계와의 연결

### 7.1 6단계 제약 강화

5단계가 끝나야 6단계에서 아래를 강제할 수 있다.

1. `daily_questions.story_loop_id set not null`
2. `unique (story_loop_id)`

### 7.2 이후 read/write 전환

historical loop가 채워지고 cardless bridge loop 상태가 정규화되어야 월간 캘린더와 상세 조회에서 질문 이력과 story loop 이력을 같은 부모 기준으로 읽을 수 있다.

즉 5단계는 read/write 전환 전의 데이터 바닥을 만든다.

---

## 8. 최종 결론

5단계의 본질은 과거 질문 데이터를 새 구조로 재해석하는 것이 아니라, 기존 의미를 보존한 채 루프 부모 아래로 정렬하고 카드 없는 bridge loop 상태까지 일관되게 정규화하는 것이다.

이번 단계에서 확정하는 내용은 아래 일곱 가지다.

1. backfill 기준 날짜는 `assigned_date`를 그대로 사용한다.
2. 미연결 source 대상은 `story_loop_id is null`인 기존 `daily_questions` row만이다.
3. loop 생성 키는 `(couple_id, assigned_date)`다.
4. 상태 매핑은 `daily_questions.status`를 그대로 신뢰한다.
5. historical loop는 카드 없는 최소 부모 루트다.
6. cardless bridge loop도 같은 상태 규칙으로 정규화한다.
7. 타임스탬프는 `daily_questions.created_at/updated_at` 기준으로 최대한 보존한다.

이렇게 해야 6단계 제약 강화와 이후 read/write 전환을 위한 데이터 바닥이 일관되게 준비된다.
