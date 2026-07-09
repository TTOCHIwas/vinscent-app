# 스토리 카드 Write 및 편집기 설계

작성일: 2026-07-10

## 1. 목적

하루 커플 공용 루프에서 각 사용자가 스토리 카드 한 장을 확정하고, 두 카드가 모두 남아 있을 때만 질문을 생성한다. 기존 질문 답변 구조와 읽기 RPC는 유지하고, 카드 저장·수정·삭제와 질문 생성의 서버 write 경계를 추가한다.

## 2. 확정 요구사항

- 카드 확정은 편집 화면의 `올리기`만으로 수행한다. 서버에는 임시 초안을 저장하지 않는다.
- 하루·커플·사용자 조합당 카드 한 장만 존재한다.
- 두 카드가 모두 존재할 때만 기존 curated 질문 순환 방식으로 질문을 생성한다.
- 질문 생성 전에는 본인 카드만 수정·삭제·재등록할 수 있다. 삭제가 먼저 확정되어 카드가 한 장 이하가 되면 질문은 생성하지 않는다.
- 질문 생성과 동시에 두 카드는 잠기며, 이후 수정·삭제할 수 없다.
- 사진은 카드당 배경 한 장이며, 1:1 캔버스에서 중앙 크롭을 시작점으로 확대·축소·이동할 수 있다.
- 텍스트는 최대 10개 레이어, 레이어당 500자, 전체 5,000자다.
- 드로잉은 고정 색상 팔레트와 굵기 선택만 제공한다. 되돌리기·다시 실행은 이번 범위에서 제외한다.
- 카드가 보관 읽기 전용 상태이면 preview만 표시한다. scene JSON과 배경 원본은 앱과 Storage 정책 모두에서 접근시키지 않는다.
- 상대 카드의 최초 업로드·삭제 후 재등록은 새 알림 대상이다. 같은 카드를 수정 저장하는 경우에는 알림을 반복 발송하지 않는다.
- 질문 생성 알림은 기존 `daily_question_enabled`, 상대 카드 업로드 알림은 새 `partner_story_card_enabled`, 상대 답변 완료 알림은 기존 `partner_answer_enabled`를 사용한다.

## 3. 파일 및 데이터 구조

### 3.1 카드 데이터

`public.story_loop_cards`는 기존 preview와 scene 경로에 더해 nullable `background_image_path`, `text_layer_count`, `text_character_count`를 가진다.

- preview: 홈·캘린더·위젯에서 사용하는 완성 PNG
- scene: 편집 재개를 위한 JSON. 배경 변환, 드로잉 stroke, 텍스트 레이어를 저장한다.
- background: 사진 카드만 사용하는 원본 배경 이미지

카드의 `revision`은 DB의 낙관적 동시성 제어값이다. 이미 저장된 카드를 수정할 때 앱은 읽은 revision을 함께 전송한다.

### 3.2 불변 Storage 경로

고정 파일을 먼저 덮어쓰지 않는다. 저장 시 UUID upload revision을 새로 만든다.

```
{coupleId}/loops/{coupleDate}/{authorUserId}/{uploadId}/preview.png
{coupleId}/loops/{coupleDate}/{authorUserId}/{uploadId}/scene.json
{coupleId}/loops/{coupleDate}/{authorUserId}/{uploadId}/background.jpg
```

RPC가 성공해야만 DB가 새 경로를 가리킨다. RPC가 실패하면 앱이 새 upload revision 파일을 정리 요청한다. 성공 뒤 이전 revision 파일은 기존 Storage cleanup 흐름으로 삭제한다. 이 방식은 상대가 두 번째 카드를 저장해 잠그는 순간에도 미확정 편집본이 확정 카드의 preview를 덮어쓰지 않게 한다.

## 4. Write 경계

### 4.1 `upsert_today_story_loop_card`

호출자는 활성 커플의 오늘 날짜에 대해서만 자신의 카드를 저장한다.

1. 앱이 background(선택), preview, scene을 불변 경로에 업로드한다.
2. 앱이 upload revision, 경로, 콘텐츠 flag, 텍스트 계수, 기존 revision을 RPC로 전달한다.
3. RPC는 커플·날짜 advisory lock과 루프 행 lock을 획득한다.
4. 질문이 이미 존재하거나 루프가 잠겼으면 저장을 거절한다.
5. 기존 카드가 있으면 revision 일치를 검증하고 새 경로로 갱신한다. 없으면 새 카드로 삽입한다.
6. 카드 수가 두 장이면 같은 트랜잭션에서 curated 질문을 선택해 `daily_questions.story_loop_id`로 연결하고, 루프 상태를 `question_generated`, `story_edit_locked_at`으로 갱신한다.
7. 질문 생성 전에는 `waiting_partner_card` 상태를 유지한다.
8. 최초 삽입·삭제 후 재등록에는 상대 카드 업로드 이벤트를, 질문 생성에는 두 사용자 대상 이벤트를 기록한다.

RPC 반환값은 저장한 카드 revision, 루프 상태, 질문 생성 여부다. 앱은 성공 후 today/detail/month provider를 모두 invalidate한다.

### 4.2 `delete_today_story_loop_card`

활성 커플의 오늘 본인 카드만 삭제한다.

1. 동일한 커플·날짜 lock과 카드 revision 검증을 수행한다.
2. 질문이 존재하거나 루프가 잠겼으면 거절한다.
3. 카드 행을 삭제하고 모든 artifact 경로를 cleanup 요청에 넣는다.
4. 남은 카드가 한 장이면 루프 상태를 `waiting_partner_card`로 둔다. 카드가 없으면 빈 루프 행은 삭제한다.

질문 생성 RPC와 삭제 RPC는 같은 lock을 사용하므로, 먼저 lock을 얻어 확정된 상태가 결과가 된다. 삭제가 먼저 확정되면 두 카드 조건이 성립하지 않아 질문도 생성되지 않는다.

## 5. 읽기 및 보관 정책

- `get_today_story_loop_summary`, `get_story_loop_detail`, `get_story_loop_month_summary`의 카드 순서와 preview 계약은 유지한다.
- 상세 RPC만 활성 커플일 때 scene/background 경로를 반환한다. archive access mode에서는 두 값을 `null`로 반환한다.
- Storage select policy도 archive 상태에서 `preview.png`만 허용한다.
- Flutter read repository는 preview와 활성 상태의 background/scene만 signed URL 또는 download 대상으로 사용한다.
- 커플 archive 즉시 삭제와 30일 만료 purge 함수는 `story_loop_cards`의 모든 revision artifact를 `story-cards` cleanup queue에 넣은 뒤 커플 행을 삭제한다.

## 6. Flutter 구성

### 6.1 도메인과 저장소

`features/story_loops`에 write repository, write failure, editable scene model, controller를 추가한다.

- `StoryCardScene`: background transform, normalized drawing stroke, text layer 목록
- `StoryCardDraft`: 편집 화면에서만 유지되는 임시 상태
- `StoryCardWriteRepository`: artifact upload, write RPC, 실패 artifact cleanup
- `StoryCardEditorController`: 저장 중복 방지와 provider invalidation

기존 녹음 저장소의 upload-first → RPC finalize → 실패 cleanup 패턴을 그대로 따른다.

### 6.2 편집 화면과 경로

`/home/story` 경로를 추가한다. 홈의 스토리 CTA와 위젯 진입은 이 경로로 연결한다.

- 새 카드: 빈 1:1 캔버스로 시작한다.
- 수정 카드: 활성 상태에서만 scene과 background를 불러온다.
- 사진은 카메라 또는 갤러리에서 하나를 고른 뒤 중앙 크롭 상태로 시작한다.
- 드로잉은 기존 캐릭터 캔버스의 normalized stroke/painter 방식을 재사용 가능한 story 전용 모델로 분리한다.
- 텍스트는 레이어로 관리하며, 저장 전 개수·문자 수를 검증한다.
- `올리기`가 성공할 때까지 화면 내 초안만 변경한다.

## 7. 알림

`user_notification_preferences`에 `partner_story_card_enabled boolean not null default true`를 추가한다. get/update RPC, Flutter model/controller/settings UI를 함께 확장한다.

`story_loop_notification_events`의 두 event type을 각각 발송하는 Edge Function과 Database Webhook을 둔다.

- `partner_story_card_uploaded`: 수신자의 새 preference를 검사한다.
- `question_generated`: 수신자의 기존 `daily_question_enabled`를 검사한다.

## 8. 단계와 커밋

1. **서버 write 기반과 접근 정책**
   - migration: immutable artifact 경로, background/텍스트 메타데이터, write RPC, 질문 생성 원자성, archive preview-only 정책, archive artifact cleanup
   - 커밋: `feat: 스토리 카드 저장과 질문 생성 write 경계 추가`

2. **스토리 카드 도메인과 저장소**
   - Flutter scene/draft/repository/controller, Storage artifact 업로드·cleanup, read model 확장
   - 커밋: `feat: 스토리 카드 편집 저장소와 초안 모델 추가`

3. **스토리 카드 편집 화면과 홈 진입**
   - 사진·드로잉·텍스트 1:1 편집기, 저장/삭제, router와 홈 CTA 연결
   - 커밋: `feat: 스토리 카드 편집과 홈 작성 흐름 추가`

4. **실제 preview 렌더링과 캘린더 연결**
   - signed preview URL, 홈·캘린더 preview 렌더링, active/archive 분기
   - 커밋: `feat: 홈과 캘린더에 스토리 카드 preview 연결`

5. **상대 카드 업로드 알림 설정**
   - preference migration/app UI, Edge Function, webhook 문서화
   - 커밋: `feat: 상대 스토리 카드 업로드 알림 추가`

6. **검증**
   - RPC 동시성·revision·잠금·archive 테스트, repository/controller/widget 테스트, analyzer와 대상 test 실행
   - 커밋: `test: 스토리 카드 저장과 잠금 흐름 검증 추가`

## 9. 설계 검토 결과

- 기존 fixed path는 잠금 경쟁에서 확정 preview를 덮어쓸 수 있어 revision별 immutable path로 교체한다.
- 질문 선택은 기존 curated 순환 로직을 새 write RPC 내부의 private helper로 옮겨, `daily_questions.story_loop_id`를 한 트랜잭션에서 보장한다.
- 카드 삭제와 질문 생성은 같은 advisory lock을 사용해 순서가 확정된다.
- 기존 read RPC와 질문 답변 RPC의 계약은 유지한다. 카드 생성 전까지 질문을 읽거나 답변할 수 없는 현재 경계도 유지한다.
