# 입력창 공통화와 AI 본문 정렬

## 변경

- 캐릭터의 정렬 기준을 AI 아이콘 포함 전체 열에서 본문 중심으로 변경했다. 공통 CharacterSpeechRow의 기본 배치는 유지하며 AI 질문·요약 호출부에서만 상단 부가 영역을 지정한다.
- 15px 아이콘과 본문 사이 8px 간격, 44×44 터치 영역, AI 안내·신고 연결을 유지한다. 터치 영역을 Transform이나 부모 밖으로 이동하지 않는다.
- AppInputStyle을 신설하고 앱 내 TextField 9곳과 TextFormField 1곳을 공통 스타일로 전환했다. 공통 AppAnswerInput을 쓰는 답변·AI 질문·월간 회고에도 적용된다.
- 입력창은 밝은 회색 배경, 반경 12, 가로 16/세로 14 여백, 17px 본문, 포커스·오류 테두리를 사용한다. AppTheme.light에도 기본 입력 장식과 선택 색상을 적용했다.
- 카드 편집은 선택한 글자색을 유지하며 밝은/어두운 입력 배경 중 실제 대비가 높은 쪽을 선택한다. 앱 전체 다크 모드를 활성화하는 변경은 아니다.
- 컨트롤러, 입력 제한과 포맷터, 한글 조합 처리, 줄 수, 검증, 저장 및 취소 연결은 유지했다.

## 근거

- [Apple Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)
- [Apple Text views](https://developer.apple.com/design/human-interface-guidelines/text-views)

짧은 입력과 긴 글의 구분, 입력 목적 안내, 적절한 크기와 간격을 참고했다. 구체적인 색상·치수는 앱의 설계 선택이며 네이티브 입력 위젯으로 교체한 것은 아니다.

## 검증

- 전체 Flutter 테스트: 1,339개 통과, 기존 제외 1개.
- 색상 대비 보완 후 집중 테스트: 60개 통과.
- Flutter analyze: No issues found.
- 코드 리뷰: 대비 보완 후 추가 결함 없음.
- 변경 파일 git diff --check 통과.
- 로그: `.codex-temp/apple-input-and-body-alignment-tests.log`, `.codex-temp/apple-input-contrast-regression.log`.
- 자동 검증: 작은 화면·확대 글자·긴 본문에서 캐릭터와 본문 중심 일치, 짧은 문장에서 전체 터치 영역이 행 안에 포함되고 아이콘 밖 여유 영역을 눌러도 안내 열림, 카드 편집·답변·닉네임·일정 등의 기존 저장 동작.

## 기기 상태

- 사용자 요청으로 Galaxy S24(SM_S921N)에 profile 1.0.0(2026101805)을 `adb install -r`로 설치했다. 기존 앱 데이터는 유지했다.
- APK 빌드 성공, 설치 Success, 앱 실행 Status ok 및 설치 버전 번호를 확인했다. 사용자 시각 확인은 별도다.
- 빌드 로그: `.codex-temp/apple-input-and-alignment-profile-build.log`.

## 대표 입력창 Cupertino 재검토

사용자가 설치된 입력창 외형에 불만을 표해, 대표 입력창을 먼저 구현·확인한 뒤 나머지로 확대하기로 했다.

- 공통 AppAnswerInput은 실제 Flutter CupertinoTextField 기반으로 전환했다. 답변·회고·집중 질문은 테두리 없는 writing 영역, AI 질문 전송창은 별도 composer 표현으로 구분한다.
- 닉네임은 기본 CupertinoTextField의 경계를 사용한다. 지우기는 Cupertino 아이콘과 기존 onClear 콜백, 44px 터치 영역을 사용한다.
- 기존 컨트롤러·포커스·글자 제한·최대 길이 초과 허용 여부·줄바꿈·저장·취소 동작을 유지한다. 앱의 Pretendard와 브랜드 커서 색은 유지한다.
- 일정·초대 코드·녹음 제목·신고·카드 편집의 직접 Material 입력창은 대표안 확인 전까지 추가 전환하지 않았다.
- 관련 회귀 테스트 314개 통과, Flutter analyze 이상 없음, 코드 리뷰 추가 결함 없음.
- 비교 이미지는 실제 프로덕션 입력 위젯으로 렌더링했다. `.codex-temp/cupertino-input-comparison.png`, 렌더러 `.codex-temp/cupertino_input_preview_test.dart`. 이전 Material 외형과 Cupertino 수정안을 같은 내용으로 배치한 컴포넌트 비교이며, 실제 앱 전체 화면 캡처는 아니다.
- 공식 근거: [Flutter CupertinoTextField](https://api.flutter.dev/flutter/cupertino/CupertinoTextField-class.html). UIKit 뷰를 직접 삽입한 것이 아니라 Flutter의 iOS 입력 구현이다.
- 검증 로그: `.codex-temp/cupertino-input-regression-final.log`, `.codex-temp/cupertino-input-preview.log`.
- 사용자 요청으로 대표안을 profile 1.0.0(2026101806)으로 빌드해 Galaxy S24에 `adb install -r`로 재설치했다. 기존 데이터는 유지했다.
- 설치 Success, 앱 실행 Status ok 및 versionCode=2026101806을 확인했다. 실기기 한글 조합 입력과 시각 확인은 별도다.
- 빌드 로그: `.codex-temp/cupertino-input-profile-build.log`.

## 무채색 포커스·AI 안내·문단 중앙 배치

- 사용자 요청에 따라 시스템 블루 대신 진한 회색(`#171717`) 커서·선택 핸들·포커스 테두리와 옅은 회색 선택 배경을 공통 입력 스타일에 적용했다. 카드 편집의 어두운 입력 배경에서는 흰색 커서를 사용하며 사용자가 선택한 글자색과 저장 색상은 유지한다.
- AI 반짝임은 장식으로 유지하고 옆에 별도 정보 버튼을 배치했다. 44×44 터치 영역에서 기존 AI 안내·신고 시트를 열며, 화면에 `AI 생성` 문구는 추가하지 않는다.
- 홈과 공통 캐릭터 행의 문단은 내부 왼쪽 정렬을 유지하면서 할당된 메시지 영역 안에서 중앙에 배치한다. 캐릭터와 실제 본문의 세로 중심 정렬도 유지한다.
- AI 표기 영역의 최소 너비보다 짧은 본문은 호출 목적에 따라 정렬한다. 캐릭터 문단은 중앙, start 질문 제목은 표기와 본문 시작선을 맞춘다.
- 전체 Flutter 테스트 1,343개 통과, 기존 제외 1개. 마지막 짧은 제목 정렬 보완 후 관련 테스트 81개 통과. 최종 Flutter analyze 이상 없음, 코드 리뷰 추가 결함 없음.
- 검증 로그: `.codex-temp/neutral-focus-info-centering-full-final.log`, `.codex-temp/neutral-focus-info-final-alignment.log`.
- 사용자 요청으로 Galaxy S24에 profile 1.0.0(2026101807)을 ARM64 APK로 재설치했다. `adb install -r`의 Success, 앱 실행 Status ok와 versionCode=2026101807을 확인했다. 기존 앱 데이터는 유지했다.
- 전체 아키텍처 빌드는 x86_64용 OpenCV Python 탐색 설정 때문에 실패했다. 이번 기기 설치에는 Galaxy S24의 ARM64 대상으로 빌드했으며 성공했다. 로그: `.codex-temp/neutral-focus-info-profile-build.log`, `.codex-temp/neutral-focus-info-profile-arm64-build.log`.

## AI 아이콘 조화와 상대 답변 간격 조사

- 사용자 승인으로 정보 아이콘을 반짝임과 같은 Material Rounded 계열의 `info_rounded`로 변경했다. 13px 크기와 muted 80% 색상으로 보조 계층을 표현하며 바깥 15px 상자·44px 터치 영역·안내 및 신고 연결은 유지한다.
- AI 표시 관련 테스트와 답변 배치 진단 23개 통과. 로그: `.codex-temp/ai-icon-answer-report-layout.log`.
- 상대 답변은 공통 `_AnswerSectionTitle`에 조건부 IconButton이 들어가 제목 행의 높이를 키운다. 앱 테마의 실제 터치 영역은 48px이며, 기본 글자 크기에서 본문 시작 위치가 boxed는 26px, plain은 28px 더 내려가는 것을 측정했다. 질문 상세·캘린더 상세·월간 회고가 같은 컴포넌트를 사용한다.
- 상대 답변 간격은 확인 요청 범위에서 원인만 조사했다. 제목 행과 신고 동작의 배치를 분리하는 방향을 제안하며 해당 생산 코드는 변경하지 않았다.
- 사용자 요청으로 Galaxy S24에 profile 1.0.0(2026101808)을 ARM64 APK로 재설치했다. 설치 Success, 앱 실행 Status ok와 versionCode=2026101808을 확인했고 기존 데이터는 유지했다. 빌드 로그: `.codex-temp/ai-info-rounded-profile-build.log`.

## 2026-10-19 상대 답변 신고 버튼 배치

- 사용자 승인에 따라 공통 제목 행의 신고 버튼을 제거하고, 답변 본문 오른쪽 보조 동작으로 이동했다. 일반 boxed 답변은 박스 안, 캘린더·회고의 plain 답변은 본문 오른쪽에 배치한다.
- `_AnswerBodyWithReport`가 본문과 버튼의 가로 배치를 공유한다. 본문은 위쪽에서 시작하고 버튼과 8px 간격을 두어 겹침을 막는다. 제목·본문 간격은 신고 버튼이 없는 답변과 동일하다.
- 신고 버튼의 기존 실제 터치 영역 48×48, 아이콘·툴팁·키, 공개 조건과 신고 대상 콜백은 유지한다. 신고가 없는 답변은 기존 본문 그대로 표시한다.
- 폭 240/360, 글자 배율 1/2, 짧은 답변의 버튼 가장자리 터치와 일반 질문의 신고 전송을 포함한 관련 테스트 89개 통과. Flutter analyze 이상 없음, 코드 리뷰 추가 결함 없음.
- 검증 로그: `.codex-temp/answer-report-layout-final.log`. 기존 편집 화면 테스트에서 입력창 탭 경고가 출력되지만 해당 테스트는 통과했으며 이번 변경 대상은 아니다.
- profile 1.0.0(2026101901) ARM64 APK 빌드 성공 후 사용자 기기 연결을 받아 Galaxy S24에 `adb install -r`로 재설치했다. 설치 Success, 앱 실행 Status ok와 versionCode=2026101901을 확인했고 기존 앱 데이터는 유지했다. 빌드 로그: `.codex-temp/answer-report-body-profile-build.log`.

## 2026-10-19 카드 없는 날짜 상세 여백

- `CalendarStoryLoopDetail`의 32px 간격을 카드 목록과 같은 조건부 블록으로 옮겼다. 카드가 없으면 질문부터 바로 표시하며, 카드가 있으면 기존 카드 아래 32px 간격을 유지한다.
- 실제 캘린더 호출은 `showDateHeader: false`이며 바깥 '우리 기록' 제목 아래 기본 18px 간격을 그대로 사용한다. 별도 카드 없는 날 레이아웃은 추가하지 않았다.
- 캘린더 상세 최소 높이·스크롤·스와이프, 질문·답변·신고 동작과 로딩·빈 상태는 변경하지 않았다.
- 수정 전 글자 배율 1/1.5에서 질문이 내용 상단보다 정확히 32px 내려가는 것을 재현했다. 수정 후 카드가 있는 날의 32px 간격과 카드 없는 날의 상단 시작을 포함해 캘린더 테스트 155개 통과. Flutter analyze 이상 없음, 코드 리뷰 추가 결함 없음.
- 검증 로그: `.codex-temp/calendar-cardless-spacing-before.log`, `.codex-temp/calendar-cardless-spacing-final.log`.
- 사용자 요청에 따라 이번 변경은 실기기에 설치하지 않았다. 마지막 설치 버전은 1.0.0(2026101901)로, 신고 버튼 이동까지 반영된 버전이다. 사용자는 작업 완료 후 컴퓨터 종료를 명시적으로 승인했다.
- 이후 사용자 설치 요청에 따라 profile 1.0.0(2026101902) ARM64 APK를 빌드하고 Galaxy S24에 `adb install -r`로 재설치했다. 설치 Success, 앱 실행 Status ok와 versionCode=2026101902를 확인했고 기존 데이터는 유지했다. 빌드 로그: `.codex-temp/calendar-cardless-spacing-profile-build.log`.

## 2026-10-19 캘린더 경로 보호와 AI 질문 제목 행

- 실기기에서 캘린더 분기의 저장된 URI와 fullPath가 `/ai`로 바뀐 상태를 VM 조회로 확인했다. 사용자는 달을 넘기며 테스트하던 중 발생했다고 설명했다. 크래시나 ANR은 확인되지 않았다.
- 날짜 선택·월 이동 호출에서 현재 최상위 경로가 해당 캘린더 화면의 경로인지 먼저 확인한다. 탭 이동 뒤 늦게 실행되는 캘린더 콜백이 활성 경로를 바꾸는 경우를 수정 전 테스트로 재현했고, 수정 후 경로 유지와 캘린더 재진입을 검증했다. 원래 실기기 오염을 만든 전체 조작 순서까지 유일하게 재현한 것은 아니다.
- 날짜 변경은 해당 화면 URI의 `date`만 교체한다. `/monthly/record`와 다른 query, push 스택을 유지해 회고 초안과 원래 캘린더 날짜로 돌아가는 동작을 보존한다.
- 긴 상세에서 짧은 상세로 월을 넘길 때 이전 화면이 새 화면 높이에 강제로 맞춰져 overflow가 발생했다. 공통 `AppHorizontalPageTransition`에서 이전 화면의 실측 높이와 GlobalKey를 유지한다. 기존 전환 시간·방향·클리핑·전환 중 터치 제한은 유지한다.
- 캘린더의 AI 안내는 ‘우리 기록’ 제목 옆으로 옮기고 질문 바로 위에 있던 별도 표시 행을 제거했다. 제목과 보이는 아이콘의 세로 중심을 맞추며 기본 18px 본문 간격, 카드가 있을 때 카드 아래 32px 간격을 유지한다.
- 공통 AI 표시에 선택 가능한 정렬만 추가했다. 다른 화면의 기본 배치, 안내·신고 연결, 44px 터치 영역과 AI 질문의 접근성 설명은 유지한다.
- 수정 범위는 캘린더 화면·상세, 공통 가로 화면 전환, AI 표시, 질문 제목의 접근성 옵션과 관련 테스트다. DB·저장 데이터는 변경하지 않는다.
- 관련 테스트 초기 실행은 234개 통과·신고 테스트 1개 실패였다. 이동된 안내 버튼을 화면으로 스크롤한 뒤 다음 프레임을 기다리도록 테스트를 고쳤고, 캘린더 상세 22개 모두 통과했다. Flutter analyze 이상 없음, 최종 코드 리뷰 추가 결함 없음.
- 전체 Flutter 회귀 테스트 1,367개 통과, 기존 제외 1개. 로그: `.codex-temp/calendar-navigation-heading-full.log`. 기기용 ARM64 profile APK 빌드 성공. 로그: `.codex-temp/calendar-navigation-heading-profile-build.log`.
- Galaxy S24에 profile 1.0.0(2026101903)을 `adb install -r`로 재설치했다. 설치 Success·앱 실행 Status ok·versionCode를 확인했고 기존 앱 데이터는 유지했다.
- 실제 기기에서 다음 달 이동 → AI → 캘린더, 이어서 이전 달 → AI → 캘린더 → 다음 달 → 홈 → 캘린더를 3회 반복했다. 최종 VM 조회에서 각 분기의 저장 URI와 fullPath가 `/home`, `/calendar`, `/ai`에 대응함을 확인했다. 로그: `.codex-temp/calendar-navigation-after-roundtrips.log`.
- 카드 없는 9월 22일 상세에서 ‘우리 기록’과 AI 표시가 같은 행이고 질문이 그 아래 시작하는 실제 화면을 확인했다. 캡처: `.codex-temp/calendar-ai-heading-device.png`. 이번 앱 프로세스 로그에서 FATAL EXCEPTION·Unhandled Exception·RenderFlex overflow·Flutter EXCEPTION CAUGHT 표식은 0개였다.

## 2026-10-19 기본 일정 손그림 밑줄

- 사용자가 제공한 손그림을 기준으로 기본 기념일·생일의 날짜 아래에 코랄색 지그재그를 추가했다. 선 구간의 길이·높이·굵기와 꺾이는 각도가 서로 다른 채워진 Path를 사용한다. 고정된 도형을 재사용하므로 다시 열거나 월을 이동해도 모양이 바뀌지 않는다.
- 새 `CalendarImportantDateUnderline`은 22×5 logical pixel 장식 위젯이다. 이미지 다운로드·추가 데이터 조회·DB 변경 없이 그리며 터치와 접근성 읽기 대상에서는 제외한다.
- `CalendarMonthStoryCell`에서 기존 `defaultEventLabel`로 표시 여부를 결정한다. 기본 일정이 있는 날에만 한 개를 표시하며, 현재 resolver·생일/기념일 계산·텍스트 라벨과 날짜의 기존 원형 표시를 유지한다. 다른 달의 흐린 날짜는 기존 호출부에서 기본 일정 label을 전달하지 않아 밑줄도 표시되지 않는다.
- 숫자·라벨의 기존 위치는 유지하고, 기본 일정이 있는 날짜의 콘텐츠 앞에만 6px 여유를 추가해 밑줄과 카드/일정 그림의 겹침을 막는다. 월 그리드 행 높이·선택·스크롤·탭 경로·미디어 로딩은 변경하지 않는다.
- 캘린더 및 셸 경로 회귀 테스트 203개 통과, Flutter analyze 이상 없음, Flutter 코드 리뷰 추가 결함 없음. 로그: `.codex-temp/calendar-hand-drawn-underline-regression.log`, `.codex-temp/calendar-hand-drawn-underline-analyze.log`.
- 일반 기념일·선택 날짜·오늘 생일·일반 날짜를 실제 Flutter 위젯으로 확대 렌더링해 시각 확인했다. 이미지: `.codex-temp/calendar-hand-drawn-underline-preview.png`. 렌더러는 `.codex-temp/calendar_underline_preview_test.dart`이며 생성형 이미지나 실기기 캡처가 아니다. 이번 작업에서는 기기에 재설치하지 않았다.
- 이후 사용자 요청에 따라 ARM64 profile 1.0.0(2026101904)을 Galaxy S24에 `adb install -r`로 재설치했다. 설치 Success·앱 실행 Status ok·versionCode=2026101904를 확인했고 기존 데이터는 유지했다. 실제 캘린더의 10월 8일 ‘100일’ 날짜 아래에 지그재그가 표시되는 것도 확인했다. 빌드 로그: `.codex-temp/calendar-hand-drawn-underline-profile-build.log`, 기기 캡처: `.codex-temp/calendar-hand-drawn-underline-installed.png`.
