# 스토리카드 일일 루프 2단계 마이그레이션 상세 설계

작성일: 2026-07-06

본 문서는 `story-card-daily-loop-migration-phase-design.md`에서 정의한 2단계 migration을 실제 SQL로 옮기기 직전까지 쪼개어 정리한 상세 설계 문서다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`
- `docs/story-card-daily-loop-phase-1-migration-detail.md`

기준 마이그레이션:

- `supabase/migrations/20260623000000_add_couple_archive_lifecycle.sql`
- `supabase/migrations/20260629002000_add_storage_cleanup_requests.sql`
- `supabase/migrations/20260629003000_redirect_storage_deletes_to_cleanup_requests.sql`

---

## 1. 이번 단계의 목적

2단계 migration의 목적은 스토리카드 storage 객체가 기존 정리 큐에 안전하게 들어갈 수 있도록 `storage_cleanup_requests`의 허용 범위를 확장하는 것이다.

이번 단계에서 해결하는 것은 다음 두 가지뿐이다.

1. `story-cards` bucket을 cleanup queue가 허용하도록 만든다.
2. 스토리카드 전용 cleanup reason을 queue가 허용하도록 만든다.

반대로 이번 단계에서 아직 하지 않는 것은 다음과 같다.

1. 스토리카드 cleanup helper 추가
2. archive purge 함수 수정
3. 스토리카드 orphan 정리 RPC 추가
4. Edge Function 또는 스케줄러 연결

즉, 이번 단계는 caller를 추가하는 단계가 아니라 queue 스키마가 미래 caller를 받아들일 수 있게 만드는 단계다.

---

## 2. 현재 코드 기준 메서드 추적

## 2.1 caller

현재 cleanup queue에 요청을 넣는 실제 caller는 다음 네 군데다.

1. `private.delete_couple_recording_if_orphaned(...)`
2. `private.delete_couple_recording_storage_objects(...)`
3. `private.delete_couple_character_storage_objects(...)`
4. `public.discard_uploaded_couple_recording(...)`

위 함수들은 모두 `supabase/migrations/20260629003000_redirect_storage_deletes_to_cleanup_requests.sql`에 정의되어 있다.

## 2.2 actual method in use

위 caller들은 공통으로 아래 helper를 호출한다.

- `private.enqueue_storage_cleanup_request(requested_bucket_id, requested_object_path, requested_cleanup_reason, requested_source_couple_id)`

이 helper는 `supabase/migrations/20260629002000_add_storage_cleanup_requests.sql`에 정의되어 있다.

이 함수는 다음 역할만 수행한다.

1. bucket / path / reason trim
2. 비어 있으면 return
3. `public.storage_cleanup_requests` insert
4. 중복 pending/processing row는 `on conflict do nothing`

즉 이 함수 자체는 recording 전용이나 character 전용 로직을 갖고 있지 않다. 실제 허용 범위는 전적으로 `storage_cleanup_requests` 테이블의 check constraint가 결정한다.

## 2.3 error origin

현재 `public.storage_cleanup_requests`는 아래 제약을 갖고 있다.

- `storage_cleanup_requests_bucket_id_check`
  - `'couple-recordings'`
  - `'couple-characters'`
- `storage_cleanup_requests_cleanup_reason_check`
  - `'orphan_recording'`
  - `'archive_recording'`
  - `'archive_character'`

따라서 이후 단계에서 스토리카드 helper가 아래와 같은 insert를 시도하면:

- `bucket_id = 'story-cards'`
- `cleanup_reason = 'archive_story_card'`
또는
- `cleanup_reason = 'orphan_story_card'`

실패 지점은 `private.enqueue_storage_cleanup_request(...)` 내부 insert가 아니라, 그 insert가 닿는 `public.storage_cleanup_requests`의 check constraint다.

## 2.4 root cause

근본 원인은 cleanup queue 구조가 generic하게 만들어져 있음에도, 허용 bucket과 reason이 기존 기능 두 개에만 닫혀 있다는 점이다.

즉 문제는 helper 부족이 아니라 queue 수용 범위 부족이다.

---

## 3. 이번 단계에서 잠글 설계 결정

## 3.1 bucket 허용 범위 확장

`storage_cleanup_requests_bucket_id_check`는 아래 집합으로 확장한다.

- `couple-recordings`
- `couple-characters`
- `story-cards`

기존 두 bucket의 동작은 그대로 유지하고, `story-cards`만 추가한다.

## 3.2 cleanup reason 허용 범위 확장

`storage_cleanup_requests_cleanup_reason_check`는 아래 집합으로 확장한다.

- `orphan_recording`
- `archive_recording`
- `archive_character`
- `orphan_story_card`
- `archive_story_card`

이 두 reason 이름은 이후 단계의 caller 목적과 직접 매핑된다.

- `orphan_story_card`
  - storage 업로드는 되었지만 DB finalize 이전에 버려진 객체
- `archive_story_card`
  - 커플 해제 후 즉시 삭제 또는 30일 만료 purge에서 제거될 객체

## 3.3 cleanup row 단위는 “카드”가 아니라 “스토리지 객체”다

스토리카드 한 장은 storage 객체를 두 개 가진다.

1. `preview.png`
2. `scene.json`

따라서 cleanup queue에도 카드당 1건이 아니라 객체당 1건을 넣는다.

예를 들어 한 카드 삭제가 필요하면 아래 두 row가 각각 enqueue된다.

1. `story-cards / {path}/preview.png / ...`
2. `story-cards / {path}/scene.json / ...`

이 설계는 현재 queue의 unique partial index와 정확히 맞물린다.

## 3.4 unique partial index는 유지한다

현재 인덱스:

- `storage_cleanup_requests_pending_unique`
- key: `(bucket_id, object_path)`
- condition: `status in ('pending', 'processing')`

이 인덱스는 그대로 유지한다.

유지하는 이유는 다음과 같다.

1. cleanup 대상의 실질적 중복 키는 object 단위다.
2. 스토리카드도 preview / scene 각각 서로 다른 object path를 가진다.
3. 같은 object를 여러 caller가 동시에 enqueue해도 중복 pending row가 생기지 않는다.

즉 스토리카드 도입 때문에 인덱스 구조를 바꿀 이유는 없다.

## 3.5 `private.enqueue_storage_cleanup_request(...)`는 변경하지 않는다

이 helper는 이미 generic하다.

- bucket을 하드코딩하지 않는다.
- reason을 하드코딩하지 않는다.
- object path 단위 dedupe를 `on conflict do nothing`으로 처리한다.

따라서 이번 단계에서 helper 함수 본문 수정은 필요 없다. 제약 확장만 해주면 된다.

---

## 4. SQL 설계 방향

## 4.1 제약 수정 방식

이번 단계에서는 기존 check constraint를 drop 후 동일한 이름으로 다시 add한다.

권장 형태:

```sql
alter table public.storage_cleanup_requests
  drop constraint if exists storage_cleanup_requests_bucket_id_check,
  drop constraint if exists storage_cleanup_requests_cleanup_reason_check;

alter table public.storage_cleanup_requests
  add constraint storage_cleanup_requests_bucket_id_check
    check (
      bucket_id in (
        'couple-recordings',
        'couple-characters',
        'story-cards'
      )
    ),
  add constraint storage_cleanup_requests_cleanup_reason_check
    check (
      cleanup_reason in (
        'orphan_recording',
        'archive_recording',
        'archive_character',
        'orphan_story_card',
        'archive_story_card'
      )
    );
```

## 4.2 기존 데이터 호환성

이 변경은 허용 집합을 넓히는 방향이다.

따라서 이미 존재하는 row들은 모두 새 constraint에도 그대로 유효하다. 데이터 backfill이나 상태 변환은 필요 없다.

## 4.3 이번 단계에서 건드리지 않는 제약

아래 제약은 그대로 유지한다.

- `storage_cleanup_requests_object_path_check`
- `storage_cleanup_requests_status_check`

이유:

1. object path 길이 규칙은 스토리카드에도 그대로 유효하다.
2. status machine은 기능 종류와 무관한 공통 queue 상태다.

---

## 5. 다음 단계와의 연결 지점

## 5.1 archive purge 확장과의 연결

이후 archive purge 확장 단계에서는 스토리카드 row를 순회하면서 각 카드마다:

1. `preview_path`
2. `scene_data_path`

를 읽어 `archive_story_card`로 enqueue하면 된다.

이번 단계는 그 insert가 실패하지 않도록 queue를 먼저 열어두는 역할이다.

## 5.2 orphan 정리와의 연결

이후 스토리카드 write RPC 또는 discard RPC가 upload-first 흐름에서 실패 복구를 담당할 때,

- preview 객체
- scene 객체

를 `orphan_story_card` reason으로 enqueue하면 된다.

이번 단계는 그 caller를 아직 만들지 않지만, 나중에 같은 helper를 재사용할 수 있도록 기반을 맞춰둔다.

## 5.3 phase 1 storage path 설계와의 연결

phase 1에서 고정한 storage path는 아래 형태다.

- `{couple_id}/loops/{couple_date}/{author_user_id}/preview.png`
- `{couple_id}/loops/{couple_date}/{author_user_id}/scene.json`

이번 단계는 object_path를 자유 문자열로 저장하는 queue 구조를 그대로 유지하므로, 위 경로를 별도 파싱 없이 그대로 cleanup 대상으로 넣을 수 있다.

---

## 6. 이번 단계에서 일부러 미루는 것

## 6.1 object 존재 여부 검사

character cleanup helper는 enqueue 전에 `storage.objects` 존재 여부를 검사하는 경로가 있고, recording orphan 경로는 검사 없이 enqueue하는 경로가 있다.

스토리카드는 어느 쪽 패턴을 따를지 이후 caller 설계에서 결정한다. 이번 단계는 queue 스키마 확장만 다루므로 object existence 정책은 잠그지 않는다.

## 6.2 cleanup_reason 세분화

현재 스토리카드 reason은 두 개만 도입한다.

- `orphan_story_card`
- `archive_story_card`

예를 들어 “replace_story_card” 같은 더 세분화된 reason은 지금 범위에 필요하지 않다. queue 목적은 감사 로그가 아니라 삭제 실행 분류이기 때문이다.

---

## 7. 검증 기준

2단계 migration 이후 아래가 확인되어야 한다.

1. 기존 recording/character enqueue가 그대로 동작한다.
2. `story-cards` bucket으로 pending row insert가 가능하다.
3. `orphan_story_card`, `archive_story_card` reason insert가 가능하다.
4. 동일 `bucket_id + object_path`에 대해 pending/processing 중복 row가 계속 막힌다.
5. 기존 row 데이터 수정이나 재처리 없이 migration이 통과한다.

---

## 8. 최종 결론

2단계의 핵심은 새로운 스토리카드 삭제 로직을 추가하는 것이 아니라, 기존 generic cleanup queue가 스토리카드 객체도 받아들일 수 있게 제약을 넓히는 것이다.

이번 단계에서 확정하는 내용은 아래 네 가지다.

1. `story-cards` bucket을 cleanup queue 허용 목록에 추가한다.
2. `orphan_story_card`, `archive_story_card` reason을 허용 목록에 추가한다.
3. cleanup row 단위는 카드가 아니라 storage object 단위로 유지한다.
4. unique partial index와 `private.enqueue_storage_cleanup_request(...)` 본문은 그대로 유지한다.

이렇게 하면 이후 단계의 archive purge helper와 orphan discard caller가 기존 queue 체계 안으로 자연스럽게 편입된다.
