# 카드·그림 로딩 개선 및 다음 작업 인계

## 진행 상태

- 사용자 요청: 느린 응답 동안 카드 프레임·그림자를 먼저 표시하지 않고 원형 스피너를 표시한다. 첫 이미지 디코딩 후 완성된 카드 전체가 작게 시작해 살짝 튀며 자리잡도록 한다. 홈·캘린더·상세·회고·녹음 그림·캐릭터에 같은 원칙을 적용한다.
- 이전 종료 지시로 기기 설치와 실기기 검증을 보류했다. 이후 사용자가 기기를 연결하고 작업 재개를 요청해 설치와 검증을 재개했다.
- 변경은 로컬 작업 트리에 저장했다. 커밋·푸시·운영 DB 변경·스토어 배포는 하지 않았다. 이전 월간 회고 UI 변경도 작업 트리에 함께 있으며 되돌리지 않았다.

## 근거와 해석 범위

### 수정 전 통제 테스트

- 실제 StoryCardPreviewSurface에 이미지 HTTP 응답을 지연시키면 프레임과 그림자가 먼저 표시되고 스피너는 없었다.
- 동일 URL을 서로 다른 디코딩 크기로 표시하면 기존 Image.network 경로에서 GET 두 번이 발생했다. 고정 디코딩 크기에서는 한 번이었다. 합성 이미지로 수행한 재현이며 운영 빈도·속도 개선율의 측정은 아니다.
- 녹음 슬롯 모델은 그림 URL이 준비돼도 오디오 URL 서명을 기다렸다. 오디오 파일 자체를 내려받는다는 의미는 아니다.
- FutureBuilder가 같은 상태에서 future만 교체될 때는 이전 결과를 보존했다. 회고의 future 재생성만으로 이미지 번쩍임을 단정하지 않았다.

### 수정 전 실기기 요청 관측

Galaxy S24(R3CX30C6CAP), 기존 설치 debug 1.0.0(2026101702)에서 HTTP 수집을 켠 뒤 사용자가 홈 → 캘린더 → 날짜 상세 → 회고 → 홈을 둘러봤다.

- story-cards 실제 GET: 33회, 고유 전체 URL 18개, 알려진 Content-Length 합 44,866,629bytes(약 44.9MB).
- story-cards 서명 POST: 2회. 서명 URL을 사용하는 이미지 GET과 서명 생성 POST를 구분했다.
- 카드 GET 응답 완료 시간 범위: 약 283~5,419ms. 단일 수동 탐색 관측이며 화면별 재현 횟수와 체류시간을 통제한 벤치마크가 아니다.
- 월간 summary RPC 3회는 인접 월 준비 경로와 함께 검토했다. 인접 월의 모든 이미지 다운로드를 의미하지 않는다.
- 수정 전 debug 관측이므로 profile 렌더링 성능·p50/p90·변경 후 개선율로 사용하지 않는다.
- URI 쿼리, 인증 헤더, 사진, 질문·답변 본문은 저장하지 않았다. 임시 도구는 메모리에서 원본 응답을 분류하고 RPC/버킷별 집계만 파일로 남겼다.

임시 근거: `.codex-temp/media-device-baseline-network.json`, `.codex-temp/media-loading-controlled-audit.log`.

## 반영한 변경

- `app_media_reveal.dart`: 첫 디코딩 프레임 전 18px 원형 스피너. 준비 후 420ms, scale 0.88 → 1 easeOutBack. 동기 캐시와 동작 줄이기 설정에서는 애니메이션을 건너뛴다. 일반 재빌드에는 재생하지 않는다.
- `app_sized_network_image.dart`: 이미지 최초 준비 상태와 장식 표시를 연결한다. gapless 교체는 기존 완성 프레임을 유지한다. 표시·디코딩 크기와 실패 fallback 계약을 유지한다.
- `app_network_image.dart`, `image_bytes_cache.dart`: URL별 진행 중 다운로드와 압축된 원본 bytes를 공유한다. 디코딩은 기존처럼 표시 크기에 맞춘다. URL 쿼리를 제거한 키를 사용하지 않는다.
- 메모리 캐시 상한 32MiB, 단일 항목 6MiB, 수명 5분, 최근 사용 순서로 제거. 디스크에 저장하지 않는다. 실패 future와 깨진 이미지 bytes는 재사용하지 않는다. clear 이전 요청이 늦게 끝나도 새 캐시에 다시 저장하지 않는다.
- `app.dart`: 로그아웃 및 커플 접근 범위 변경 시 새 bytes 캐시를 정리한다. 이 정리가 진행 중 HTTP 취소나 Flutter 디코딩 캐시 전체의 즉시 삭제를 보장하는 것은 아니다.
- 카드 공통 surface와 캘린더 월 카드: 장식과 그림을 함께 공개한다. 캘린더 확대/축소 고정 디코딩 키와 탭 영역은 유지한다.
- 회고 카드: 서명 URL 대기 때도 프레임을 미리 표시하지 않는다. 갱신 중 기존 카드 URL을 보존하고 새로 추가된 카드만 대기 상태로 둔다.
- 캐릭터·녹음 홈 그림·녹음 목록 그림: 공통 이미지 처리로 전환, 표시 크기에 맞춘 디코딩 적용. 편집기의 로컬 그림 갱신에는 등장 효과를 추가하지 않았다.
- CurrentCoupleRecordingReader 선택 기능과 기존 Supabase reader 확장: 홈 위젯은 현재 녹음 RPC 한 번과 해당 오디오 서명만 요청한다. 저장 슬롯 목록·주의 상태·슬롯 오디오/그림 서명을 요청하지 않는다. 기존 저장소 구현은 overview fallback을 유지한다.

## 유지한 동작

카드 상세 열기, 녹음 재생·드래그·알림 표시, 카드 비율, 날짜별 카드 선정, 회고 저장·질문 고정·기간 제한, 기존 인증/RPC 접근 검사, 인접 월 준비, OS 위젯 오프라인 오디오 저장은 유지했다.

## 검증과 빌드 메모

- 코드 리뷰에서 gapless 교체와 기존 URL map에 없는 새 카드의 대기 처리 회귀를 지적받아 수정했다. 최종 읽기 리뷰에서 추가 결함은 발견되지 않았다.
- 통제 회귀: 첫 프레임 전 장식 없음, 스피너 표시, 등장 후 작은 크기·overshoot·정착, 탭 유지, 두 디코딩 크기 GET 공유, 동기 캐시 재진입, gapless URL 교체, 동작 줄이기, LRU/TTL/실패/clear 경계, 현재 녹음 전용 RPC 및 위젯 실패 보존을 검증한다.
- 최종 정적 분석/관련 전체 테스트 결과는 아래 최종 결과 절에 기록한다. 중간 실패 로그를 최종 성공으로 오인하지 않는다.
- profile APK 빌드는 OpenCV 네이티브 hook의 CMake Python 탐색에서 실패했다. pyenv의 실행 불가능한 `python3` shim을 찾고, 이후 `find_package(... OFF)` 오류가 발생했다. 두 번 시도 후 설치 단계로 진행하지 않았다. Flutter 코드 컴파일 성공이나 기기 성능 검증 완료로 보고하지 않는다.
- 재개 시 `PYTHON3_EXECUTABLE` 환경 변수를 실제 Python 실행 파일로 지정하는 방안을 검증한다. OpenCVDetectPython.cmake가 이 환경 변수를 읽는 코드까지 확인했다. 실제 경로: `C:/Users/cofl1/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`. PATH에 Python 폴더만 추가하면 `python3` 이름으로 shim을 계속 찾으므로 충분하지 않았다. 패키지 소스와 pubspec은 변경하지 않았다.

## 다음 작업

1. 이 파일과 로컬 diff를 읽고 기존 월간 회고 UI 변경을 보존한다.
2. profile 빌드 환경을 해결하고 APK를 만든다. 기기 설치는 다음 세션에서 사용자 요청 범위에 맞춰 진행한다. 데이터 삭제나 uninstall은 하지 않는다.
3. 동일 탐색 시나리오를 통제한 profile 실기기 측정으로 전송량·GET 중복·첫 프레임 시점·프레임 지연을 확인한다. 기존 단일 debug 관측과 단순 백분율 비교를 하지 않는다.
4. 느린 응답·캐시 재진입·서명 갱신·실패·뒤로가기에서 카드 장식과 이미지가 함께 나타나는지 시각 검증한다. 회고 사진 더미·캘린더 작은 카드의 과도한 동시 스피너/등장도 확인한다.
5. 첫 다운로드 자체의 무거운 카드 미리보기는 남아 있다. 800px급 원본 PNG를 작은 카드에도 사용하는 구조다. 썸네일 파생 이미지/인코딩 변경은 서버 호환성과 실측을 확인한 후 별도 범위로 정한다.
6. 현재 녹음·슬롯 그림의 오디오 서명 의존을 분리하는 모델 변경, recording signed URL 공통 캐시, 회고 URL future 생성 빈도, 비가시 영역 로딩은 추가 측정 후 판단한다. 이번에 임의로 제거하지 않았다.

## 재개 명령 환경

작업 디렉터리: `D:/vinscent/apps/mobile`

```powershell
$env:PUB_CACHE='D:\vinscent\.toolchains\pub-cache'
$env:JAVA_HOME='C:\Program Files\Microsoft\jdk-21.0.9.10-hotspot'
$env:PATH=$env:JAVA_HOME+'\bin;C:\Users\cofl1\AppData\Local\Android\Sdk\cmake\3.22.1\bin;'+$env:PATH
```

Flutter: `D:/vinscent/.toolchains/flutter/bin/flutter.bat`

환경 값은 출력하지 않고 빌드에 `--dart-define-from-file=.env`로 전달한다. build number 예비값은 `2026101801`; 이 버전은 아직 설치하지 않았다.

## 이전 작업 종료 시점 결과

- Flutter analyze: No issues found.
- 관련 자동 테스트: 714개 통과. 홈·캘린더·상세·캐릭터·녹음·회고와 공통 미디어/캐시 경로를 포함한다.
- git diff --check: 통과.
- 최종 코드 리뷰: 추가 결함 없음.
- 로그: `.codex-temp/media-loading-final-regression.log`, `.codex-temp/media-loading-analyze-final.log`.
- profile APK 빌드 실패. 실기기 설치와 변경 후 기기 측정은 미수행이다.
- 종료 전 HTTP 진단 수집을 끄려 했으나 기존 VM 서비스 연결이 거부되어 해제 여부를 확인하지 못했다. 재개 시 앱을 재시작해 임시 진단 상태를 초기화하고 측정한다.

## 재개 및 실기기 검증

- 기기: Galaxy S24(SM_S921N), Android 16 / API 36.
- `PYTHON3_EXECUTABLE` 환경 변수를 실제 Python 실행 파일로 지정한 뒤 profile 빌드 성공. 패키지 소스나 앱 의존성 변경은 없었다.
- 빌드: `--profile --target-platform android-arm64 --build-number=2026101801 --dart-define-from-file=.env`.
- 1.0.0(2026101801) profile APK를 `adb install -r`로 설치했다. 기존 앱 데이터는 삭제하지 않았다. 앱을 재시작해 이전 임시 진단 상태를 초기화했다.
- APK 빌드 로그: `.codex-temp/media-loading-profile-resume-build.log`.
- 진단 도구 `.codex-temp/media_profile_session.dart`는 SDK의 HTTP profile과 `Flutter.Frame` 이벤트만 사용한다. 앱 계측 코드는 추가하지 않았다. 원본 URL·인증 헤더·본문을 저장하지 않고 RPC·버킷별 집계만 저장한다.
- 사용자에게 동일 화면 순서 두 번 탐색을 요청했다. 결과는 수집 후 아래에 기록한다. 단일 탐색 관측으로 정식 출시 성능 게이트나 개선율을 판정하지 않는다.

### profile 2026101801 관측

- 사용자 탐색 완료, 122.179초 수집. 원본 증빙: `.codex-temp/media-device-profile-1801-a1.json`.
- story-cards GET 40회 / 고유 전체 URL 37개, 알려진 Content-Length 합 47,263,998bytes. HTTP 오류와 관측 종료 시 미완료 요청은 0개였다.
- 같은 전체 URL 재다운로드가 3회 남아 있다. 메모리 예산 초과에 따른 제거·다른 다운로드 소비자·접근 범위 갱신 등의 원인을 이 집계만으로 특정하지 않는다. URL별 캐시 적중/제거 이유와 호출자를 추가로 연결해야 한다.
- 수정 전 1회 탐색과 수정 후 2회 탐색은 범위와 빌드 모드가 달라 단순 전송량·개선율 비교를 하지 않는다. 이번 탐색에는 수정 전보다 많은 URL이 포함됐다.
- Flutter.Frame 1,742개. build p50/p90/max = 1.236/4.255/58.820ms, raster = 2.672/4.206/182.345ms, elapsed = 5.386/11.347/197.236ms.
- 16.67ms 초과 build 10개 / raster 11개. 이 수치는 고정 60Hz 참조선 기준이며 가변 주사율 기기의 실제 missed-frame 수를 뜻하지 않는다. 긴 프레임의 화면·원인은 별도 timeline 분석이 필요하다.
- SDK HTTP 진단 수집은 결과 저장 후 정상적으로 비활성화하고 진단 버퍼를 비웠다.

### 사용자 피드백: 캘린더 날짜별 스피너

- 사용자가 탐색 완료 후 같은 날짜에서 스피너가 겹친다고 보고했다. 날짜마다 하나로 표시하도록 추가 지시했다.
- 원인: 카드마다 공통 이미지 스피너를 표시하고, 같은 날짜의 일정 그림도 별도 스피너를 표시했다.
- `AppMediaLoadingGroup`을 날짜 셀 단위로 적용했다. 카드와 일정 그림의 대기 상태를 합쳐 날짜 헤더 아래 콘텐츠 영역에 스피너 하나를 표시한다. 셀 내부 개별 이미지 스피너는 숨기고 다른 화면의 스피너는 유지한다.
- 각 미디어가 준비되면 기존 등장 효과로 나타난다. 날짜 스피너는 해당 날짜의 대기 항목이 모두 준비되거나 실패·제거되면 사라진다. 스피너는 탭을 가로채지 않는다.
- 무효 URL 전환, 위젯 제거, 그룹 dispose와 동기 캐시 응답도 pending 집계에서 정리한다.
- 실제 지연 이미지 응답으로 카드 2장+일정 그림이 있는 날짜 2개를 compact/expanded 각각 검증했다. 날짜별 하나 / 전체 두 개이며 완료 뒤 모두 사라진다. pending URL 무효화·위젯 제거 테스트도 추가했다.
- 관련 회귀 테스트 260개 통과. 로그: `.codex-temp/calendar-loading-group-regression.log`.
- 코드 리뷰 지적 2건(loadingBuilder 위치, 무효 URL pending 해제)을 수정했고 최종 읽기 리뷰에서 추가 결함은 발견되지 않았다.
- 최종 Flutter analyze: No issues found. profile 1.0.0(2026101802) 빌드 성공 및 Galaxy S24 재설치·실행 완료. 사용자 기록은 유지했다.
- 최종 로그: `.codex-temp/calendar-loading-group-analyze-final.log`, `.codex-temp/calendar-loading-group-profile-build.log`.
- 진단용 ADB 포트 전달을 제거했다. 새 앱 실행에는 HTTP 수집을 켜지 않았다.
- 1802의 날짜별 스피너는 지연 응답 자동 테스트로 검증했다. 재설치 이후 사용자의 추가 시각 확인과 동일 조건 반복 성능 측정은 아직 수행하지 않았다.

### 추가 수정: 부분 완료 사진과 스피너 중첩

- 사용자 추가 피드백: 사진 두 장 중 한 장이 먼저 표시되고 다른 한 장의 날짜 스피너가 겹친다. 스피너 외형도 Apple 스타일로 개선하도록 요청했다.
- 원인: 대기 상태만 날짜별로 합쳤고 이미지 공개 조건은 각 이미지의 첫 프레임만 확인했다.
- 날짜 그룹의 스피너 상태와 공개 가능 상태를 같은 postframe에서 확정한다. 초기 동기 캐시 응답도 해당 프레임의 모든 자식이 등록된 뒤 판단한다.
- 한 날짜의 사진·일정 그림이 모두 준비되거나 실패 처리된 뒤 미디어를 함께 공개한다. 일부만 준비됐을 때는 사진·카드 프레임·그림자 없이 날짜 인디케이터 하나만 표시한다. 날짜 텍스트와 다른 날짜의 콘텐츠, 화면 조작은 유지한다.
- 실패·무효 URL fallback도 같은 공개 조건을 사용한다. 한 항목 실패로 날짜 전체가 계속 대기하지 않도록 pending 해제를 유지한다.
- 공통 AppLoadingIndicator를 Flutter CupertinoActivityIndicator로 교체했다. 중립 회색, 기본 반경 10 / 작은 영역 반경 8을 사용한다. 색상·크기는 앱의 설계 선택이며 Apple이 이 수치를 의무화한 것은 아니다.
- Apple HIG는 소요 시간을 알 수 없는 작업에 indeterminate activity indicator를 사용하고, 일정한 위치에 표시하며 작업 완료 후 사라지도록 안내한다. 날짜별 미디어 동시 공개는 해당 UI에 맞춘 설계 판단이다.
- 공식 근거: [Apple Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators), [Apple Loading](https://developer.apple.com/design/human-interface-guidelines/loading), [Flutter CupertinoActivityIndicator](https://api.flutter.dev/flutter/cupertino/CupertinoActivityIndicator-class.html). Apple 공식 Markdown 원문도 직접 확인했다.
- 서로 다른 완료 시점 및 첫 사진만 캐시된 재진입을 실제 CalendarMonthStoryCell의 compact/expanded 상태에서 재현했다. 두 번째 사진 대기 중 RawImage 0개·인디케이터 1개, 완료 후 RawImage 2개·인디케이터 0개를 검증했다.
- 집중 테스트 22개와 Flutter analyze 통과, 코드 리뷰 추가 결함 없음. 전체 회귀 테스트와 기기용 빌드 결과는 완료 후 아래에 기록한다.
- 최종 전체 Flutter 테스트 1,335개 통과 / 기존 제외 1개. 최종 Flutter analyze: No issues found.
- 그룹 밖 실패·무효 URL placeholder는 기존처럼 장식 surface를 직접 반환해, 기본 카드에 불필요한 Transform이 생기지 않도록 보존했다. 설정 작업 행의 직접 Material 진행 표시는 별도 동작이며 해당 기존 테스트 계약도 유지했다.
- 증빙: `.codex-temp/apple-media-loading-full-test-final.log`, `.codex-temp/apple-media-loading-analyze-final.log`.
- profile 1.0.0(2026101803) 빌드 성공 및 Galaxy S24 재설치·실행 완료. 기존 기록은 유지했다. 빌드 로그: `.codex-temp/apple-media-loading-profile-build.log`.
- 사진 비대칭 완료 및 캐시 재진입은 자동 테스트로 검증했고, 재설치 이후 사용자 시각 확인은 별도다.
