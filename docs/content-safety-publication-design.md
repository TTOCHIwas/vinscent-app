# 공유 콘텐츠 게시 전 검사: 경계와 공급자 평가

기준일: 2026-10-25. 분석 기준: `d3010e95`.

Windows에서 이어갈 때는 [Windows 인계 절차](release/content-safety-windows-handoff.md)를 따른다.

## 현재 상태와 이번 변경

Apple 정식 출시 준비의 첫 작업이다. 사용자는 기존 공급자 유지보다 검사 품질과
한국어 지원을 비교해 적합한 서비스를 선정하도록 요청했다.

이번 변경은 공급자에 독립적인 판정 계약, 서버 검사 유스케이스, OpenAI와
Cloudflare 후보 어댑터, 합성 한국어 비교 도구를 추가한다. 아직 어느 공급자도
운영용으로 선정하지 않았다. 운영 요청을 보내지 않았으며 실제 한국어 정확도와
지연 시간도 측정하지 않았다.

**게시 전 필터링 기능은 아직 완료되지 않았다.** 신규 모듈은 앱이나 Edge 진입점에
연결하지 않았다. DB gateway 구현, 공개를 막는 DB/Storage 경계, 모바일 저장 흐름,
음성 검사, 이미지 품질 평가와 정책·동의 변경은 후속 작업이다. 기존 저장·공개
동작과 운영 DB는 이번 변경으로 달라지지 않는다.

## 적용하는 프로젝트 규칙

- `docs/code-architecture-and-verification.md`: domain은 순수 정책·값,
  application은 유스케이스와 port, infrastructure는 외부 I/O를 담당한다.
- 중요한 정책은 앱의 버튼 상태가 아닌 서버에서 강제한다.
- 기존 caller와 저장·읽기 경계를 추적하고 테스트를 먼저 실행해 RED를 확인한다.
- 테스트와 구현을 별도 커밋으로 남기며 한글 결과를 커밋 메시지에 쓴다.
- push, 운영 반영, TestFlight 업로드는 별도의 명시적 승인 후 진행한다.

## 기존 호출 흐름과 필요한 변경

| 콘텐츠 | 현재 주요 호출 경로 | 검사·공개 경계에서 확인할 내용 |
| --- | --- | --- |
| 카드 | editor → StoryLoopWriteRepository.saveTodayCard → Storage 업로드 → upsert_today_story_loop_card_v3 | 미리보기·원본 사진·글·그림의 동일 버전 검사. 편집 JSON과 원본 파일도 상대가 직접 읽지 못해야 함 |
| 일일 답변 | submit controller → DailyQuestionAnswerRepository → submit_daily_question_answer | 기존 답변 공개 조건과 함께 새 답변 및 수정 버전을 검사 |
| 월간 회고 답변 | MonthlyRetrospectiveRepository.save → submit_current_monthly_retrospective_answer | 충돌 보호 버전을 유지하고 저장·수정본 공개 전에 검사. 기존 UGC 동의 trigger 목록만으로 포함됐다고 가정하지 않음 |
| 캐릭터 | character controller → CoupleCharacterRepository → 그림 업로드·저장 RPC | 렌더링 이미지와 수정 가능한 그림 데이터, 위젯에 반영되는 파일 버전 |
| 일정 | event editor → CoupleCalendarEventRepository → 일정 저장 | 제목·메모·그림과 일정 알림 본문 |
| 녹음 | mobile/native widget → recording uploader → 파일 업로드·등록 | 앱·Android 위젯·iOS 위젯 경로를 모두 포함. 현재 녹음은 최대 15초 |
| 녹음 슬롯 | slot writer/artwork store → 제목·그림 저장 RPC | 이미 검사된 음성의 재사용과 신규 제목·그림 검사를 구분 |
| AI 입력·출력 | 직접 질문·집중 질문·생성 worker | 입력 필터와 생성 결과 검증을 구분하고 기존 AI 동의·공개 조건 유지 |
| 표시 이름 | 프로필·온보딩 → display name 저장 → 상대 이름 조회 | 연결 전에 작성한 이름의 상대방 노출과 동의 시점도 별도 확인 |

현재 안전 약관 동의 trigger는 검사 결과를 확인하는 경계가 아니다. 원본 파일이
private bucket에 있더라도 상대방에게 읽기 권한이 있거나 signed URL을 만들 수 있으면
검사 대기 중 콘텐츠가 노출될 수 있다. RPC 반환값만 숨기는 방식은 충분하지 않다.

## 서버 계약

목표 흐름은 `사용자 입력 → 작성자만 읽는 임시 저장 → 서버 snapshot/검사 → 승인된
동일 버전의 원자적 공개`다. 아래 DB 책임은 설계이며 아직 구현하지 않았다.

1. 서버는 JWT 사용자, 활성 관계, 정책 동의와 소유권을 확인한다. 사용자가 임의로
   제공한 외부 URL이나 사용자·커플 ID를 검사 대상의 근거로 신뢰하지 않는다.
2. `ContentSafetyGateway.prepare`는 서버가 읽은 변경 불가능한 검사 snapshot과
   비공개 claim token을 돌려준다. 실제 텍스트와 파일 bytes를 구성하며 미리보기만
   검사하고 수정 원문을 그대로 공개하지 않는다.
3. `CheckSharedContent`는 모든 part가 지원되고 정상 응답을 받은 경우에만 허용한다.
   알 수 없는 결과, 누락된 분류, 지원하지 않는 음성, 오류와 시간 초과는
   `unavailable`이다. 해당 상태는 승인으로 취급하지 않는다.
4. `complete`의 실제 DB 구현은 claim/revision, 관계·소유권·정책 유효성을 다시
   확인해야 한다. 검사 중 편집, 연결 해제, 차단 또는 삭제가 발생하면 오래된
   판정을 현재 콘텐츠에 적용하지 않는다. 이번 테스트는 이 port의 실패 결과를
   유스케이스가 어떻게 처리하는지만 검증하며 실제 SQL의 원자성을 입증하지 않는다.
5. 최종 공개 RPC/trigger와 Storage RLS는 사용자·대상·내용 hash·정책 버전·만료에
   묶인 서버 승인 결과를 검증한다. 클라이언트가 보낸 `safe: true`는 사용하지 않는다.
6. 파일은 버전별 불변 경로를 사용한다. 공개된 경로에 검사하지 않은 새 파일을
   덮어쓰거나, 검사 대기 파일의 signed URL을 상대에게 발급할 수 없어야 한다.
7. 승인 전에는 알림·Realtime·홈 위젯에도 새 콘텐츠를 보내지 않는다. 작성자는
   초안을 유지하고 검사 실패 뒤 재시도할 수 있어야 한다.

`CheckSharedContent`는 판정만 기록한다. 게시 허용 권한이나 DB 승인 증명 자체가
아니며, 위 gateway와 공개 경계를 연결하기 전에는 보호 기능으로 간주하지 않는다.

## 공식 사양 비교와 현재 판단

| 후보 | 확인한 지원 범위 | 한국어·품질 관련 판단 | 이번 구현 |
| --- | --- | --- | --- |
| OpenAI omni-moderation-latest | 텍스트·이미지. 음성 직접 분류 미지원. moderation endpoint는 공식 안내상 무료 | 단짠 한국어 정확도 수치는 확인하지 못함. 정상 연애 표현·관용구와 위협의 오탐/누락을 실측해야 함 | 텍스트·이미지 후보 어댑터 |
| Cloudflare Llama Guard 3 8B | 텍스트. 공식 모델 카드의 지원 언어 목록에 한국어 없음 | 기존 공급자라는 이유만으로 한국어 안전 검사의 운영 기본값으로 삼지 않음 | 동일 텍스트 평가를 위한 후보 어댑터 |
| Azure AI Content Safety | 텍스트·이미지 등 전용 API | 공식 학습·검증 언어 목록에 한국어 없음. 다른 언어의 품질은 자체 평가 요구 | 문서 비교만 수행, 어댑터 없음 |

능력 범위상 OpenAI를 우선 평가할 수 있지만 품질 우위나 운영 선정을 확정한 것은
아니다. Cloudflare와의 동일 한국어 평가 결과와 이미지·음성 범위를 함께 판단한다.
OpenAI Moderation의 이미지 전용 입력은 지원하지 않는 분류에서 0을 반환할 수
있으며, 이미지 속 글·모든 유해 콘텐츠를 포괄적으로 검출한다고 가정하지 않는다.
알려져 있거나 의심되는 아동 성착취 자료를 이 API에 보내지 않으며 일반 moderation을
전용 아동 안전 대응의 대체물로 사용하지 않는다.

음성은 별도 전사와 전사 품질 평가가 필요하다. 침묵, 인식 실패, 잡음, 배경음과
의미를 충분히 추출하지 못한 결과를 빈 안전 문장으로 간주하지 않는다. 전사된 말의
검사만으로 원음의 모든 위험을 검사했다고 선언하지 않는다. 전사 비용·보관 조건도
포함해 선정한다.

공식 자료(확인일 2026-10-25):

- [OpenAI Moderation](https://developers.openai.com/api/docs/guides/moderation)
- [OpenAI 음성 전사](https://developers.openai.com/api/docs/guides/speech-to-text)
- [Cloudflare Llama Guard](https://developers.cloudflare.com/workers-ai/models/llama-guard-3-8b/)
- [Meta 모델 카드](https://github.com/meta-llama/PurpleLlama/blob/main/Llama-Guard3/8B/MODEL_CARD.md)
- [Azure 지원 언어·제한](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/language-support)
- [Apple Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
- [Supabase private bucket](https://supabase.com/docs/guides/storage/buckets/fundamentals)

## 비교 평가 도구

`services/ai-api/eval/fixtures/content-safety-ko.ts`의 18개 합성 문장만 사용한다.
실제 사용자 사진·녹음·질문·답변을 평가 자료로 가져오지 않는다. 정상 일상·연애·
한국어 관용구·갈등 표현과 위협·강요·혐오 예시를 포함한다.

라벨은 검토용 초안이다. 이 작은 텍스트 평가를 한국어 전체 품질 보증, 운영 차단
정책 또는 이미지·음성 평가로 확대 해석하지 않는다. 모델의 flag를 곧바로 제품
정책으로 확정하지 않고 정상 표현의 오차단과 피해 신호를 검토한다.

기본 실행은 네트워크 요청 없이 범위만 출력한다.

```sh
cd services/ai-api
npm run eval:content-safety
```

외부 평가를 명시적으로 실행할 때만 다음 전용 환경변수를 사용한다. 값은 저장소,
명령 인자, 보고서와 채팅에 남기지 않는다. 기존 운영 `.env`를 평가 도구가 자동으로
읽지 않는다.

- OpenAI: `CONTENT_SAFETY_OPENAI_API_KEY`
- Cloudflare: `CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID`, `CONTENT_SAFETY_CLOUDFLARE_API_TOKEN`

```sh
npm run eval:content-safety -- --live --provider=openai
npm run eval:content-safety -- --live --provider=cloudflare
```

한 번에 18건을 순서대로 요청하며 자동 재시도하지 않는다. 후보별 오허용·오차단·
판정 불가와 p50/p95 지연 시간을 집계한다. 보고서에는 예시 ID·그룹·기대/실제 판정만
남기고 원문·인증 정보·공급자 오류 본문은 출력하지 않는다. 불일치/판정 불가 시 종료
코드 1이다. 통과가 곧 운영 승인이라는 뜻은 아니다.

## 검증과 후속 완료 조건

- RED: 신규 모듈 없음으로 테스트 실행 실패를 확인한 뒤 테스트 커밋을 먼저 작성.
- 추가 RED: 잘린 OpenAI category map이 승인되는 사례를 재현한 뒤 응답 검증 보완.
- 신규 테스트 49개와 기존 AI 서비스 회귀를 합친 전체 332개 통과.
- 기본 평가 실행: 외부 요청 0, 공급자 미선정, 이미지·음성 미평가 표시 확인.
- 실제 평가 실행은 전용 키 미설정 오류로 시작 전에 중단됨. 공급자 요청은 없음.
- Flutter, 운영 DB, Storage RLS와 실기기 검증을 이번 서버 모듈 단위 테스트 결과로
  대신하지 않는다.

다음 순서로 진행한다.

1. 전용 평가 환경을 준비하고 합성 한국어 비교 실행·라벨 검토.
2. 이미지·음성 평가, 처리 비용·외부 처리자·보관 조건 확인 후 공급자와 정책 확정.
3. 실제 DB/Storage gateway·승인/공개 경계의 SQL RED 테스트와 migration 구현.
4. 기존 앱/위젯의 모든 저장 caller를 연결하고 대기·거절·실패 UX 구현.
5. 직접 RPC·Storage 접근, 편집 경합, 관계 종료, 알림·Realtime·위젯 누출 회귀.
6. 개인정보 안내와 동의를 실제 검사 경로에 맞게 갱신하고 iOS/Android 실기기 확인.
7. 별도의 사용자 승인 후 운영 반영과 신규 TestFlight 배포.
