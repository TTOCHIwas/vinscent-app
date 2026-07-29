# 모바일 성능 검증 기준

이 문서는 단짠 Android·iOS 출시 후보의 성능을 같은 조건으로 반복 측정하고
회귀 여부를 판단하기 위한 기준이다. 디버그 빌드는 Flutter 디버깅 오버헤드가
포함되므로 앱 크기와 프레임 성능의 판정 자료로 사용하지 않는다.

## 1. 출시 게이트

다음 항목을 Android와 iOS 실기기에서 모두 확인한다.

| 영역 | 출시 조건 |
|---|---|
| 시작 | 앱을 강제 종료한 뒤 다시 실행하는 cold start에서 검은 화면, 무한 로딩, watchdog 종료가 없음 |
| Android 시작 시간 | TTID가 cold 5초, warm 2초, hot 1.5초 이상인 과도한 시작 시간에 해당하지 않음 |
| 상호작용 | 탭·텍스트 입력 같은 단발 상호작용에서 사용자가 인지할 멈춤이 없음 |
| 애니메이션 | 캘린더 전환, 카드 상세 오버레이, 하단 시트, 플로팅 독에서 반복적인 missed frame이 없음 |
| 메모리 | 카드 이미지·그림·캘린더를 반복 탐색한 뒤 메모리가 계속 증가하지 않으며 OS 강제 종료가 없음 |
| 백그라운드 | 녹음, 알림, 위젯 동기화 이후 앱 복귀가 정상이고 비정상적인 배터리·네트워크 반복 작업이 없음 |
| 안정성 | 검증 세션 동안 crash와 ANR이 0건임 |
| 크기 | Release App Bundle의 크기 분석 보고서를 보관하고 이전 출시 후보보다 설명되지 않은 증가가 없음 |

Android의 시작 시간 값은 Android vitals가 과도한 시작으로 분류하는
상한선이다. 목표값을 임의로 더 낮게 고정하기보다 동일 기기에서 이전 출시
후보와 p50·p90을 비교한다.

Apple 기준에 따라 단발 사용자 입력에 반응하는 동기 메인 스레드 작업은
100ms 미만, 연속 제스처와 애니메이션 작업은 한 화면 갱신 주기 안에
완료되는지를 Instruments와 Flutter DevTools에서 확인한다.

## 2. 기기 범위

최소한 다음 조합을 한 출시 후보에서 검증한다.

| 플랫폼 | 필수 기기 |
|---|---|
| Android | 지원 최저 API 23 기기 또는 에뮬레이터 |
| Android | 실제 주 사용 중급 사양 휴대전화 |
| Android | 최근 Android 버전 휴대전화 또는 태블릿 |
| iOS | Runner 최저 지원 iOS 13 기기 또는 시뮬레이터 |
| iOS | 위젯 최저 지원 iOS 18 이상 실제 iPhone |
| iOS | 큰 글자와 넓은 화면 검증용 iPad 또는 큰 화면 시뮬레이터 |

시뮬레이터 결과만으로 메모리, 녹음, 카메라, 알림, 위젯 성능을 승인하지
않는다.

## 3. 측정 시나리오

각 시나리오는 profile 또는 release 빌드에서 첫 실행 1회를 버리고 최소
10회 반복한다. 기기, OS, 앱 버전, 커밋 SHA, 네트워크 상태를 함께 기록한다.

1. 로그아웃 상태 cold start 후 로그인 화면 표시
2. 로그인 유지 상태 cold start 후 홈의 카드·캐릭터·질문 표시
3. 홈과 캘린더·AI 탭 왕복
4. 캘린더 월간·전체·주간 상태 전환과 날짜 좌우 이동
5. 카드 카메라 실행, 촬영, 그리기, 저장, 상세 보기
6. 캐릭터 녹음·재생과 녹음 슬롯 배치
7. 키보드를 여닫으며 질문 답변과 AI 직접 질문 작성
8. 큰 글자 설정에서 홈, 캘린더 상세, AI, 설정 탐색
9. 백그라운드·종료 상태 알림 진입과 위젯 갱신
10. 네트워크 지연·단절 후 재시도와 앱 복귀

## 4. Android 측정

실기기에서 profile 모드로 실행한다.

```powershell
cd apps/mobile
.\flutterw.cmd run --profile -d <DEVICE_ID>
```

동일한 설치 빌드의 cold start를 반복 측정할 때는 앱을 실행하는 장기
프로세스 대신 다음 종료형 도구를 사용한다.

```powershell
cd apps/mobile
..\..\.toolchains\flutter\bin\dart.bat run `
  tool/measure_android_cold_start.dart `
  --device <DEVICE_ID> `
  --output build/release-evidence/android-cold-start.json
```

도구는 `am force-stop` 뒤 `am start -W`를 실행한다. 첫 1회는 버리고
기본 10회를 측정한 뒤 p50·p90과 기기·OS·설치 버전·target SDK·commit SHA를
JSON에 기록하고 종료한다. 각 `adb`·`git` 명령은 20초를 넘기면 실패하며,
기존 증빙 파일은 덮어쓰지 않는다. 이 결과는 Android vitals와 실제 화면
표시 시점 측정을 보조하며, Play의 현장 지표를 대체하지 않는다.

시작 시간을 측정할 때 앱을 강제 종료하고 Logcat의 `Displayed` 값을
기록한다. Android 12 이상에서는 `am start -W` 결과도 함께 보조 자료로
남길 수 있다.

```powershell
adb shell am force-stop com.vinscent.vinscent
adb shell am start -W com.vinscent.vinscent/.MainActivity
```

Flutter DevTools Performance view에서 UI·Raster frame, shader compilation,
메모리 추이를 기록한다. Play 내부 테스트가 시작되면 Android vitals의
crash, ANR, startup, slow rendering, partial wake lock 알림을 활성화한다.

Release App Bundle의 Dart·asset 크기 분석은 다음 명령으로 생성한다.

```powershell
cd apps/mobile
.\flutterw.cmd build appbundle --release --analyze-size
```

2026-07-29 로컬 기준점:

- AAB 업로드 파일: `60,232,588` bytes
- AAB 내부 base 모듈 압축분: `37,737,674` bytes
- base assets 압축분: `5,933,803` bytes
- 번들 폰트 압축분: 약 `4.5` MB
- `BUNDLE-METADATA` 압축분: `22,219,753` bytes

이 값은 Play가 기기별로 생성하는 실제 다운로드 크기가 아니다. 최종
다운로드 크기는 Play Console App Bundle Explorer에서 확인한다.

## 5. iOS 측정

Mac에서 profile 또는 release 빌드를 실제 iPhone에 설치한 뒤 Xcode
Instruments의 App Launch, Time Profiler, Allocations를 사용한다.

- Xcode Organizer에서 launch time의 p50·p90을 이전 빌드와 비교한다.
- Hangs와 Hitches 보고서에서 캘린더·키보드·카드 편집 흐름을 확인한다.
- Runner와 위젯을 각각 실행해 메모리와 extension 종료 여부를 확인한다.
- TestFlight 외부 테스트 전 실제 iPhone에서 녹음·알림·위젯을 반복한다.

## 6. 결과 기록

출시 후보마다 다음 표를 복사해 측정 결과와 보고서 경로를 남긴다.

| 항목 | 기기·OS | p50 | p90 | 이상 건수 | 증빙 |
|---|---|---:|---:|---:|---|
| Cold start |  |  |  |  |  |
| Warm start |  |  |  |  |  |
| Hot start |  |  |  |  |  |
| 캘린더 전환 |  |  |  |  |  |
| 카드 편집 |  |  |  |  |  |
| AI 입력 |  |  |  |  |  |
| 메모리 반복 탐색 |  |  |  |  |  |

측정 없이 성능 최적화 커밋을 만들지 않는다. 임계치를 넘거나 이전 후보보다
악화된 시나리오를 재현한 뒤, 한 원인과 한 수정 단위로 다시 측정한다.

## 7. 공식 자료

- Flutter Performance view:
  https://docs.flutter.dev/tools/devtools/performance
- Flutter 앱 크기 측정:
  https://docs.flutter.dev/perf/app-size
- Android 앱 시작 시간:
  https://developer.android.com/topic/performance/vitals/launch-time
- Android vitals:
  https://developer.android.com/topic/performance/vitals
- Apple 앱 시작 시간:
  https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time
- Apple 앱 반응성:
  https://developer.apple.com/documentation/xcode/improving-app-responsiveness
