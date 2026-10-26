# 이미지·음성 검사 설계와 평가 준비

작성일: 2026-10-26. 코드 추적 기준: `95a1154c`와 이번 평가 준비 커밋.
이번 범위는 설계·합성 자료·오프라인 도구다. 새 유료 API 호출, 운영 DB 변경,
Storage 정책 변경, Edge Function 배포와 앱 배포를 하지 않았다.

## 측정된 사실과 아직 모르는 것

[2026-10-25 한국어 텍스트 결과](content-safety-evaluation-2026-10-25/README.md)는
OpenAI와 Cloudflare 각각 합성 18개에서 기대 판정 18개 일치, 오허용·오차단·판정 불가 0개다.
지연 p50/p95는 각각 527/1,421 ms와 299/694 ms다. 이 수치는 실제 텍스트 호출 결과다.
작은 표본·초안 라벨·공급자별 1회·고정 실행 순서의 한계가 있다.
이미지·OCR·음성 인식의 품질, 비용과 지연은 아직 측정하지 않았다. 운영 공급자도 미선정이다.

## 실제 저장·공개 흐름

아래는 저장소 코드에서 확인한 흐름이다. 운영 프로젝트의 적용 migration/RLS를 조회한 결과는 아니다.
공통 원인은 검사 어댑터가 기존 저장·조회·공개 경계에 연결되지 않았다는 점이다.

| 대상 | caller → 실제 저장 method → 공개·조회 | 검사해야 하는 실제 자료와 누락 가능성 |
| --- | --- | --- |
| 사진 포함 카드 | `story_card_editor_screen.dart::_saveCard/_capturePreview` → `StoryCardEditorController.save` → `SupabaseStoryLoopWriteRepository.saveTodayCard` → 업로드 → `upsert_today_story_loop_card_v3` | `story-cards`의 revision별 `preview.png`, `scene.json`, 비 four-cut의 `background.jpg`. 미리보기와 사진 배경이 다르므로 잘린 영역·가려진 글·반전·작은 글·필터 적용 전후를 구분한다. four-cut은 저장 method에서 별도 배경 업로드를 하지 않으므로 업로드되지 않는 원본 네 장을 서버가 받았다고 가정하지 않는다. |
| 카드의 한국어·그림 | 동일 경로의 scene에 `strokes`, `text_layers`, `caption` 저장 → `StoryLoopReadRepository`의 signed URL → 편집·표시 | 명시적 text layer/caption을 서버에서 추출해 검사하고 합성 PNG와 사진의 글은 OCR로 별도 검사한다. 투명·숨김 레이어와 재편집 가능한 scene도 동일 revision에 묶는다. scene 문자열의 글만 검사하면 손글씨·사진 속 글은 누락된다. |
| 캐릭터 그림 | `character_editor_screen.dart::_save` → `CoupleCharacterController.saveCharacter` → `CoupleCharacterRepository.saveCharacter` → PNG·drawing JSON 업로드 → `upsert_couple_character` | `couple-characters`의 `revisions/{revision}/preview.png`, `drawing.json`. 조회는 signed URL과 원본 download를 사용한다. 래스터 검사와 서버 재렌더의 일치, 획으로 그린 글·기호, 위젯 캐시를 포함한다. legacy `current.png/current.json` 경로도 남아 있다. |
| 녹음 슬롯 그림·제목 | artwork editor → overview controller → `SupabaseCoupleRecordingSlotArtworkStore.saveSlotArtwork` → preview WebP·gzip drawing 업로드 → `save_couple_recording_slot_artwork`; 제목은 `save_current_couple_recording_to_slot` | `couple-recording-artworks/{couple}/slots/{slot}/artworks/{artifact}/preview.webp`, `drawing.json.gz`. gzip 해제 한도·서버 렌더 검증·OCR 필요. 기존 승인 음성을 재사용해도 신규 제목·그림은 새 검사 대상이다. |
| 일정 그림·텍스트 | event editor → `DefaultCoupleCalendarEventRepository.saveEvent` → `SupabaseCoupleCalendarEventArtworkStore.uploadArtwork` → `SupabaseCoupleCalendarEventGateway.saveEvent` → `save_couple_calendar_event` | `couple-calendar-artworks`의 event/artifact별 WebP·gzip drawing과 RPC title/memo. signed preview와 drawing download, 알림 본문까지 같은 승인 revision을 사용해야 한다. |
| 앱 녹음 | capture controller/pending upload coordinator → recording repository → `SupabaseCurrentCoupleRecordingWriter.uploadCurrentRecording` → M4A 업로드 → `replace_current_couple_recording` | `couple-recordings/{couple}/recordings/{recording}.m4a`, MIME `audio/mp4`. 서버 bytes·실제 duration·디코딩 결과를 확인해야 한다. 클라이언트 duration만 신뢰하지 않는다. 현재 기능의 녹음 제한은 15초다. |
| Android 위젯 녹음 | `WidgetRecordingUploadWorker` → `WidgetRecordingFlutterBridge` → Dart background handler/task → `SupabaseWidgetRecordingUploadGateway.upload` → 동일 recording repository | 네이티브 업로드·재시도가 앱 저장 경계를 우회하지 않아야 한다. 업로드 receipt 후 `HomeWidgetRecordingPlaybackCache.replace`가 로컬 재생 캐시를 설치하므로 향후 업로드 완료와 공개 승인 완료를 구분한다. |
| iOS 위젯 녹음 | `VinscentWidgetAudioController` → `VinscentWidgetRecordingUploadBridge` → Dart task/gateway → 동일 repository | App Group 초안·background task·재시도·Live Activity와 WidgetKit 상태를 포함한다. Swift 경로가 Dart 저장 흐름에 합류한다. Windows에서 iOS 빌드·실행 확인은 하지 않았다. |

근거 파일은 `apps/mobile/lib/features/{story_loops,characters,recordings,calendar,home_widgets}` 아래
위 표의 파일들과 `apps/mobile/{android/app/src/main/kotlin/com/vinscent/vinscent/widgets,ios/Runner}`다.
사진은 gallery picker의 normalized bytes 및 camera 경로를 사용한다.
`StoryCardGalleryPicker`는 requestFullMetadata=false로 읽고 `StoryCardImageNormalizer`가
방향 보정·최대 2048 크기·JPEG 재인코딩·5 MiB 제한을 적용한다. 이것은 클라이언트 전처리이며
서버가 클라이언트·직접 업로드의 모든 메타데이터를 검증했다는 뜻은 아니다.

조회 우회 경로도 있다. `home_widget_partner_card_repository.dart::fetchLatestPartnerCard`는
`story_loop_cards`를 직접 select하고 preview signed URL을 발급한다. read RPC만 변경하면 충분하지 않다.
`home_widget_recording_cache_repository.dart` 등의 로컬 캐시와 이미지 URL 캐시도 검증 대상이다.

## 검사 단위와 실패 원칙

이미지의 시각 판정, OCR 결과의 텍스트 판정, 명시적 scene/caption/title/memo 판정을 구분한다.
그림 JSON·gzip은 지원되는 스키마로 해석하고 제한된 서버 렌더링으로 검사한다. 이를 이미지
공급자에 그대로 보내거나 클라이언트 미리보기만 믿지 않는다. 원본·미리보기·편집 자료는
동일 snapshot/hash/revision으로 고정한다. 외부 URL을 임의 fetch하는 검사 API는 만들지 않는다.

음성은 `디코딩/길이 검증 → 음성 감지 → 한국어 ASR → 전사 완전성 검토 → 텍스트 분류`를 평가한다.
빈 전사, 침묵·잡음, 언어 불명, 인식 실패·일부 인식, timeout과 미지원 유형은 `unavailable`이다.
비어 있지 않은 환각 전사도 가능하므로 전사문 존재만으로 음성이 있다고 판단하지 않는다.
비명·협박조·배경음·비언어적 위험은 전사 텍스트로 보증할 수 없다.

새 `eval/media-safety-evaluation.ts`는 외부 I/O를 port로 주입하는 평가 전용 조합이다.
image 검사와 OCR/text 검사 모두 유효해야 한다. audio는 `status: complete`, `language: ko`,
`speechDetected: true`와 비어 있지 않은 전사를 요구한다. 이미지에 한해 확인된 `no_text`를 허용한다.
모호한 응답·exception·전체 deadline 초과는 승인으로 바뀌지 않는다.
각 port는 signal을 받고 취소를 무시해도 평가 결과는 timeout으로 끝난다.
이 필드는 ASR 공급자 응답에 자동으로 생기지 않는다. 후속 adapter가 실제 VAD·완전성 근거를
만들어야 하며 상수 true나 기대 대본으로 채우면 안 된다. 허용 결과도 `transcribed_speech_only`이고
`originalAudioCovered: false`다. 이 도구는 게시 승인, MIME decoder 또는 DB gateway가 아니다.

## 공급자·단계 비교

공식 사양 확인일: 2026-10-26. 아래 비용은 USD, 세금·계정 할인·무료 잔여량·스토리지 비용 제외다.

| 후보와 역할 | 지원·한국어 평가 | 비용과 지연 | 외부 전송·보관 |
| --- | --- | --- | --- |
| OpenAI `omni-moderation-latest` | 텍스트·이미지, 음성 직접 미지원. 이미지가 지원하지 않는 harassment/hate 등의 분류가 있어 OCR 텍스트 검사가 필요하다. 한국어 이미지·손글씨 품질은 미측정 | moderation 무료. 기존 텍스트 지연만 측정됨. 이미지 지연은 별도 실측 | 서버가 이미지 bytes 또는 텍스트를 전송. 해당 endpoint는 공식 표상 학습·abuse monitoring/application state 보관 없음. 이미지 관련 안전 예외는 별도 확인 |
| OpenAI ASR 후보 `gpt-4o-mini-transcribe` | 음성→전사, 안전 분류 자체가 아니다. 부정어·위협·잡음·침묵·혼합언어별 ASR와 후단 분류를 분리 평가 | 공식 추정 $0.003/분. 파일별 지연·전체 pipeline p50/p95 미측정 | 원음이 추가 외부 전송됨. `/v1/audio/transcriptions`는 공식 표상 학습·abuse/application state 보관 없음. 계정별 지역 처리 조건은 미확인 |
| Cloudflare `@cf/meta/llama-guard-3-8b` | 현재 어댑터는 텍스트 전용. 한국어는 Meta의 명시적 지원 언어 목록에 없어 실측 필요. OCR/전사문 분류 후보이며 이미지 자체 검사를 대체하지 않음 | 입력 $0.484/백만 토큰, 출력 $0.030/백만 토큰. 기존 텍스트 지연만 측정 | Workers AI 직접 호출. 표준 stateless inference의 콘텐츠 보관 최소화·학습 미사용 약속이 있으나 예외와 stateful feature·Gateway logging/caching 조건이 다름 |
| Cloudflare ASR 후보 `@cf/openai/whisper-large-v3-turbo` | 언어 hint·VAD·no-speech 설정 제공. `ko` 지정만으로 한국어 정확도나 완전성을 보증하지 않음. 출력 응답과 실제 코덱 호환성 검증 필요 | 가격표 $0.0005/분, 모델 페이지 $0.000513/분으로 차이가 있어 예산은 큰 값 사용. 지연 미측정 | Cloudflare에서 원음 처리. OpenAI 이름의 모델이지만 OpenAI API endpoint에 보내는 경로는 아님. 위 Workers AI 조건 적용 |
| OCR 비교안: 로컬 OCR / OpenAI vision | 로컬 OCR은 한국어 언어팩·손글씨 지원 확인 필요. vision은 글 추출용 후보일 뿐 완전한 OCR 보증 없음. 모델 자체 판정과 OCR 문자 정확도를 혼동하지 않음. 아래 가격 예시의 `gpt-4.1-mini`는 현재 공식 페이지에 deprecated 표시가 있어 신규 구현 모델로 확정하지 않음 | 로컬은 외부 API 비용 0, 실행비 별도. 가격 산식 예시로 `gpt-4.1-mini` 입력 $0.40/백만·출력 $1.60/백만 토큰, 이미지 토큰도 과금. 지연 미측정. 실제 실행에는 활성 모델·접근 가능 여부·단가 재확인 필요 | 로컬 구현이면 해당 단계 외부 전송 없음. OpenAI Responses를 쓰면 `store:false`로 application state를 제어해도 기본 abuse monitoring 30일 조건은 별도 검토. moderation/ASR의 보관 조건을 OCR에 확대 적용하지 않음 |

공급자 선정 전에 원본 전송 최소화, 동의 시점, 목적·항목·처리자·국외 처리 안내,
보관·삭제·접근 통제와 계정의 실제 설정을 확인한다. 위 표는 법적 적합성 판정이 아니다.
키·사용자 ID·signed URL·원문을 로그에 남기지 않는다. 이미지 속 이름·얼굴·주소도 개인정보다.
알려져 있거나 의심되는 아동 성착취 자료는 평가에 수집·생성·전송하지 않는다.

## 합성 평가 자료와 실행 준비

manifest: `services/ai-api/eval/fixtures/content-safety-media-ko.json`.
합성 24개: 이미지 12개, 음성 12개. 기대 라벨은 검토용 초안이며 아직 humanReviewed=false다.

- 이미지: 정상·관용구·부정·위협·강요의 인쇄 한국어, 작은 저대비 글, 회전 글,
  원본/크롭 검토용 기준, 글 없는 기하 그림, 손상 PNG 및 미지원 SVG.
- 음성: 한국어 발화 대본 8개, PCM 침묵·고정 seed 잡음 2개, 손상·미지원 파일 2개.
- 실제 생성 파일 16개는 SHA-256으로 고정한다. 이 PC에는 한국어 로컬 TTS가 없어 발화 파일
  8개는 `asset: null`로 남겼다. 외부 TTS 호출이나 실제 사용자 녹음으로 채우지 않았다.
- 기하 이미지가 사진 품질 평가를 대신하지 않는다. 실제 합성 사진, 손글씨·혼합언어,
  심한 가림·압축, JPEG/WebP, 앱 M4A 코덱, 화자/속도/배경음 다양화는 별도 준비 대상이다.
- 위험 시각물 생성 대신 현재 자료는 무해한 기하 도형과 합성 문구를 사용한다.
  따라서 노출·폭력 시각물 검출률을 이 자료로 측정했다고 선언할 수 없다.

```powershell
cd services/ai-api
npm.cmd run --silent eval:content-safety-media
npm.cmd run --silent eval:content-safety-media -- --validate-assets
node --experimental-strip-types --test test/media-safety-evaluation.test.ts test/media-safety-cli.test.ts
```

두 CLI 명령은 외부 요청 0건이다. `--live`와 공급자 인자는 명시적으로 거부한다.
실제 평가 adapter/계정 사용은 아직 연결하지 않았다. `evaluateMediaSafety`에 각 단계 port를
연결하고 `summarizeMediaEvaluation`로 결과를 집계하는 API는 테스트로 검증했다.
generator는 Windows에서 `powershell -NoProfile -ExecutionPolicy Bypass -File eval/generate-media-fixtures.ps1`로
실행한다. PowerShell 5의 한글 해석을 위해 generator의 UTF-8 BOM을 유지한다.
생성 파일은 Mac에서도 그대로 읽을 수 있으므로 인계 시 재생성이 필수는 아니다.

발화 제작 시 대본만 읽는 로컬 한국어 합성 음성을 사용하고 모델·속도·샘플레이트를 기록한다.
발화 8개는 각각 15초 이하, WAV와 앱 호환 M4A 파생본, 무음·잡음 파생본을 대조한다.
실제 생성·청취 검토 후 asset/hash/duration/humanReviewed를 기록하고 표본·비용 계획을 재계산한다.
기존 generator는 초안 manifest를 다시 만들므로 검토·녹음 추가 후 덮어쓰지 않는다.

## 품질 평가 방법과 보고 형식

동일 bytes/hash·대본·라벨·실행 횟수·timeout을 유지한다. 원본 언어를 번역하지 않는다.
이미지 시각 판정, OCR 문자 인식, ASR, 추출 텍스트 분류와 종단 판정을 각각 기록한다.
종단 오류가 생기면 인식 누락/환각과 분류 오류를 구분한다. 기대 대본을 실제 OCR/전사 입력으로
대신 넣지 않는다. 문자 정확도는 NFC·공백 정규화 후 CER로 비교하며 CER는 1을 넘을 수 있다.
CER만으로 의미를 판단하지 않고 특히 부정어·강요·위협 주체의 누락을 사람이 검토한다.
침묵에 생긴 전사, 손글씨의 글 없음 판정도 별도 실패로 검토한다.

보고서는 사례 ID/hash, 설정 모델과 확인 가능한 실제 snapshot, 기대/실제 판정,
오허용·오차단·판정 불가·unexpectedApprovals, 단계별/종단 지연과 CER만 남긴다.
원음·이미지·전사 원문·키·공급자 오류 본문은 결과 로그에 남기지 않는다.
오류 HTTP 상태/인증·권한·429·네트워크 실패는 품질 오류와 구분한다.
초기 1회는 smoke이며 품질 확정용 반복이 아니다. 확대 평가 시 먼저 비용을 다시 제시한다.

## 다음 유료 호출 수와 예상 비용: 아직 실행하지 않음

현재 자료의 손상/미지원 각 2개는 로컬 실패 검증으로만 사용한다.
발화 파일 준비·라벨 검토·decoder 검증 뒤 1회 실행을 가정한 사전 예산이다.

| 단계 | 최대 호출 수 | 예상 비용 근거 |
| --- | --- | --- |
| OpenAI 시각 moderation | 이미지 10회 | $0 |
| 공통 OCR | 이미지 10회 | 로컬이면 외부 API $0. vision 후보라면 총 입력 10,000·출력 2,000 토큰 가정 시 $0.0072. 실제 이미지 토큰·prompt에 따라 변하는 예산 예시이며 상한 보증 아님 |
| OpenAI ASR | 음성/침묵/잡음 10회, 보수적으로 총 2.5분 | 추정 $0.0075 |
| Cloudflare ASR | 같은 10회·2.5분 | $0.0012825, 모델 페이지의 큰 단가 적용 |
| 두 후보에 동일 OCR/전사문 텍스트 분류 | 후보당 최대 20회, 총 40회 | OpenAI $0. Cloudflare 20회 총 입력 20,000·출력 2,560 토큰 가정 시 $0.0097568. 시스템 템플릿 포함 실제 토큰은 실행 전에 다시 확인 |

전사 비교의 입력 공정성을 위해 1차 안전 분류 비교는 공통 추출 결과를 사용한다.
각 ASR의 고유 전사로 하는 종단 비교까지 추가하면 최대 20회 텍스트 요청이 더 필요하므로
위 40회 안에 몰래 추가하지 않는다. 텍스트 없는 이미지·전사 실패는 분류 호출을 생략한다.
기본 계획은 최대 80회(시각 10 + OCR 10 + ASR 20 + 텍스트 40)다.
유료 OCR 예시를 포함한 합계는 약 $0.026, 로컬 OCR이면 약 $0.019다.
이는 단가와 토큰/분량 가정에 따른 예상액이며 실제 청구액이나 실행 승인으로 취급하지 않는다.
무료 할당량을 사용할 수 있다고 가정하지 않았다. 계정별 잔여량·한도는 미확인이다.
새 호출 전 모델·해상도·대본·분량·계정 한도·예산을 다시 확인하고 재시도는 기본 0회로 둔다.

## 다음 DB/Storage 구현의 노출 차단 항목

다음은 구현·SQL RED 테스트 대상이며 이번에 migration을 적용하지 않았다.

| 경계 | 현재 근거 | 다음 실패 검증 |
| --- | --- | --- |
| 카드 Storage 원본·scene·preview | `20260710001000_add_story_card_write_boundary.sql`의 readable helper는 커플·경로·관계 조건으로 읽기 허용 | 등록 RPC 전에도 상대 direct download/list/signed URL 발급이 거부되는지, legacy 경로·새 revision·scene 숨김 글 포함 |
| 녹음 Storage | 최신 helper는 `20260729006000_add_user_blocking.sql`에 재정의되어 readable member + recordings prefix 사용 | 등록 전 파일, 추측 경로, 예전 녹음·슬롯 재사용, 승인 대기 M4A direct read 차단 |
| 캐릭터 Storage | 같은 migration의 character helper와 `20260722000000_make_character_artifacts_atomic.sql` | legacy current 및 revision PNG/JSON 읽기·덮어쓰기, 미리보기/JSON 불일치, 초기 설정 권한 유지 |
| 녹음 artwork Storage | `20260722002000_fix_storage_policy_helper_boundaries.sql`는 슬롯·멤버·artifact 경로 확인 | 슬롯 존재만으로 새 미승인 artifact가 읽히지 않는지, gzip 원본·preview 모두 차단 |
| 일정 artwork Storage | `20260726000000_add_couple_calendar_events.sql`는 event에 연결된 경로와 readable member 확인 | 미승인 path를 event에 먼저 연결하는 RPC 우회, 원본 download와 signed URL 차단 |
| DB 쓰기·읽기 | 카드 v3는 `20261011143000_connect_monthly_retrospective.sql` wrapper → `...v3_before_monthly`, 실제 저장 정책은 `20260921090000_add_story_card_layout_versions.sql`도 추적 필요 | 모든 기존 RPC·직접 table select/write·view·read RPC에서 승인 version만 상대에게 보임. 월간 회고 부수 효과·동의·차단·초기 설정 규칙 보존 |
| 공개 원자성 | 현재 `ContentSafetyGateway`는 port이며 실제 DB 구현 없음 | 검사 중 수정·삭제·차단·관계 해제·동의 철회·정책 변경·만료·중복 worker·위조 claim을 승인하지 않음. snapshot hash와 revision을 한 transaction에서 재검증 |
| 알림·Realtime·위젯 | 직접 partner-card select, recording playback cache, `dispatch-scheduled-notifications/calendar_event_reminder_handler.ts`, Realtime publication | 승인 전 INSERT/UPDATE payload·알림 title/memo·scheduled reminder·featured card·위젯 download/cache가 새 원문을 전달하지 않음 |
| 기존 URL·로컬 캐시 | signed URL은 발급 후 유효기간이 있고 기기 캐시는 이미 내려받은 bytes | 판정/관계 변경 시 재발급 중단·캐시 무효화·기존 URL 수명 정책. RLS 변경으로 이미 발급한 URL/내려받은 bytes가 즉시 회수된다고 가정하지 않음 |

작성자 초안 읽기와 기존 승인본 읽기를 보존하고, 실패 시 새 미승인본으로 기존 승인본을
교체하지 않는다. 파일별 불변 경로·JSON/gzip 해제·렌더링·디코딩 제한·서비스 권한 전용 승인
기록·정리 작업도 테스트한다. 로컬 SQL/Storage 통합 검증과 iOS/Android 실기기 증거가 필요하다.

## 공식 자료

- [OpenAI moderation의 분류별 입력 지원](https://developers.openai.com/api/docs/guides/moderation)
- [OpenAI 음성 전사](https://developers.openai.com/api/docs/guides/speech-to-text)
- [OpenAI 가격](https://developers.openai.com/api/docs/pricing), [OCR 후보 가격](https://developers.openai.com/api/docs/models/gpt-4.1-mini)
- [OpenAI endpoint별 데이터 보관](https://developers.openai.com/api/docs/guides/your-data)
- [Cloudflare Llama Guard](https://developers.cloudflare.com/workers-ai/models/llama-guard-3-8b/)
- [Meta Llama Guard 지원 언어](https://github.com/meta-llama/PurpleLlama/blob/main/Llama-Guard3/8B/MODEL_CARD.md)
- [Cloudflare Whisper 모델·VAD 설정](https://developers.cloudflare.com/workers-ai/models/whisper-large-v3-turbo/)
- [Cloudflare 요금표](https://developers.cloudflare.com/workers-ai/platform/pricing/)
- [Cloudflare 데이터 처리·보관 예외](https://developers.cloudflare.com/workers-ai/platform/data-usage/)
