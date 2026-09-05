# Mac Codex용 iOS 작업 프롬프트

아래 코드 블록 전체를 Mac에서 이 저장소를 연 Codex의 첫 메시지로 사용한다.
경로의 `<vinscent-repository>`만 실제 저장소 경로로 바꾼다.

```text
당신은 단짠 Flutter 앱의 iOS 검증과 수정 작업을 이어받는다.

저장소: https://github.com/TTOCHIwas/vinscent-app.git
브랜치: main
마지막 TestFlight 성공 기준 commit:
8c96489fa1f3684786a486f44fa08d6ce325fe71

목표:
최신 main을 Mac에서 받아 마지막 TestFlight 성공 이후 변경분이 iOS 앱,
위젯, 로그인, 푸시, 기기 캘린더에서 정상 동작하는지 검증한다. 발견한 문제는
근원 원인을 추적해 테스트 우선으로 수정한다. 최종적으로 다음 TestFlight
릴리스 후보를 만들 수 있는 깨끗한 commit 상태까지 준비한다.

먼저 Codex에 제공된 저장소 작업 지침을 확인하고 다음 파일을 반드시 읽는다:
- docs/release/ios-mac-handoff.md
- docs/release/ci-validation.md
- docs/release/ios-privacy-declaration.md
- apps/mobile/ios/WIDGET_SETUP.md
- .github/workflows/ios-release.yml
- scripts/verify_ios_local.sh
- scripts/check_ios_release_mac.sh

작업 규칙:
1. 파일과 caller를 모두 수집한 뒤 caller -> 실제 method -> platform bridge ->
   오류 발생점 순서로 추적한다. 추측으로 수정하지 않는다.
2. 기존 Android 동작과 공통 Flutter UX를 보존한다.
3. 버그나 기능 변경은 재현 테스트를 먼저 추가해 RED를 확인하고, 테스트
   commit과 구현 commit을 분리한다.
4. commit은 `type: 짧은 한글 결과` 형식으로 한 의도씩 남긴다.
5. 기존 사용자 변경이나 무관한 파일을 되돌리지 않는다.
6. `.env`, `.p8`, `.p12`, `.mobileprovision`, 인증서 내용과 토큰을 읽어서
   출력하거나 Git에 추가하지 않는다.
7. 사용자의 명시적 승인 전에는 push, ios-release workflow, TestFlight 업로드를
   실행하지 않는다.
8. Xcode 프로젝트 파일을 수정할 때 Runner와 VinscentWidgets target 영향을
   함께 확인한다.

실행 순서:
1. 저장소에서 `git switch main`, `git pull --ff-only origin main`,
   `git status --short`, `git rev-parse HEAD`를 실행한다.
2. `git log --oneline
   8c96489fa1f3684786a486f44fa08d6ce325fe71..HEAD`로 검증 범위를 확인한다.
3. Flutter 3.41.9, Xcode 26 이상, iPhoneOS SDK 26 이상, CocoaPods가 준비됐는지
   확인한다.
4. `apps/mobile/.env`와
   `apps/mobile/ios/Flutter/Kakao.generated.xcconfig`가 존재하는지만 확인한다.
   값은 출력하지 않는다. 누락되면 사용자에게 준비를 요청한다.
5. 저장소 루트에서 `./scripts/verify_ios_local.sh`를 실행한다.
6. 실패하면 실패 로그와 관련 파일을 모두 수집하고 근원 원인을 수정한다.
   성공하기 전에는 UI 검증으로 넘어가지 않는다.
7. `apps/mobile/ios/Runner.xcworkspace`의 Runner scheme을 작은 iPhone과 큰
   iPhone 시뮬레이터에서 실행한다. 기본 글자와 큰 글자, portrait와 선언된
   landscape 방향, 홈 인디케이터 Safe Area를 확인한다.
8. 캘린더 전환·오늘 표시·인접 월 프리페치, 그림 편집 도구, 공통 확인창,
   업데이트 인디케이터를 시각적으로 확인한다.
9. 실제 iPhone에서 Apple·카카오 로그인, 계정 삭제, FCM, 기기 캘린더
   생성·수정·삭제·매년 반복, 위젯과 녹음, 카메라·사진·위치·마이크 권한을
   확인한다.
10. EventKit 네이티브 버그가 있으면 RunnerTests를 예제 상태로 둔 채 임시
    우회하지 않는다. 재현 가능한 XCTest 또는 테스트 가능한 경계를 먼저 만든
    뒤 수정한다.
11. 수정과 검증이 끝나고 모든 변경이 커밋된 깨끗한 상태에서
    `./scripts/check_ios_release_mac.sh "$(git rev-parse HEAD)"`를 실행한다.
12. push나 배포 없이 결과를 사용자에게 보고하고 승인을 기다린다.

필수 검증 결과 보고 형식:
- 현재 HEAD SHA
- 마지막 TestFlight 기준 이후 변경 범위 요약
- Xcode, iPhoneOS SDK, Flutter, CocoaPods 버전
- verify_ios_local.sh 결과
- iOS 시뮬레이터별 결과
- 실제 iPhone별 결과
- 추가한 테스트와 commit 목록
- 미해결 문제와 출시 차단 여부
- check_ios_release_mac.sh 결과

중요:
자동 테스트 통과만으로 Apple 로그인, APNs, EventKit, WidgetKit 녹음을 완료로
판정하지 않는다. 반대로 실기기에서 한 번 동작했다는 이유로 테스트 실패를
무시하지 않는다. 둘 다 통과해야 iOS 릴리스 준비 완료로 보고한다.
```
