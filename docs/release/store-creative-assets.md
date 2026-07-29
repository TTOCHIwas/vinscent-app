# 스토어 그래픽 자산 제작 기준

이 문서는 단짠 `1.0.0`의 Google Play와 App Store 그래픽 자산을 같은
출시 후보에서 만들고 검증하기 위한 기준이다. 모든 캡처는 스토어에 제출할
commit과 런타임 설정으로 빌드한 앱에서 생성한다.

## 1. 공통 원칙

- 실제 사용자 데이터가 아닌 심사용 두 계정의 준비된 데이터만 사용한다.
- 이메일, 연결 코드, 푸시 토큰, 위치와 실제 상대방의 사진·목소리를
  노출하지 않는다.
- 디버그 배너, overflow 표시, 로딩 실패, 키보드, 시스템 권한 팝업이 없는
  안정된 상태에서 캡처한다.
- 휴대전화 캡처를 늘여 태블릿 이미지로 만들거나 다른 기기 프레임에
  합성하지 않는다.
- 첫 세 장에는 홈, 카드 만들기, 질문과 답변을 배치해 핵심 경험을 먼저
  보여준다.
- 화면에 없는 기능이나 유료화되지 않은 기능을 그래픽 문구로 약속하지
  않는다.
- 원본 PNG와 최종 제출 파일, 촬영 기기·OS·commit SHA를 함께 보관한다.

## 2. 촬영 장면

| 순서 | 파일 식별자 | 준비 상태 | 확인할 내용 |
|---:|---|---|---|
| 1 | `home` | 두 카드와 직접 그린 캐릭터가 있는 홈 | 질문, 카드, 캐릭터, 플로팅 독이 잘리지 않음 |
| 2 | `card-editor` | 사진을 촬영한 카드 편집 화면 | 그림·텍스트·짧은 글 도구가 실제 배치와 일치 |
| 3 | `question-answer` | 두 사람이 답변을 남긴 질문 | 질문, 두 답변과 캐릭터 한마디의 관계가 명확 |
| 4 | `calendar` | 카드·일정 그림·기념일이 있는 달 | 확장 셀과 날짜 상세가 실제 데이터를 정확히 표현 |
| 5 | `recording-library` | 제목·그림·녹음이 있는 슬롯 | 항목 선택 재생과 슬롯 그림이 식별 가능 |
| 6 | `ai` | 동의와 기억 검토를 마친 상태 | 직접 질문, 답변, AI 생성 표시가 보임 |
| 7 | `widgets` | 캐릭터·카드 위젯이 배치된 홈 화면 | 앱과 위젯의 실제 스타일이 일치 |
| 8 | `settings` | 설정 첫 화면 또는 안전 설정 | 알림, 신고·차단, 연결 해제·계정 삭제 경로가 명확 |

파일명은
`{platform}-{device-class}-{order}-{identifier}-{version}-{commit}.png`
형식으로 남긴다. 예:
`android-phone-01-home-1.0.0-a1b2c3d.png`.

제출 원본은 다음 경로에 보관한다.

| 자산 | 경로 |
|---|---|
| Play feature graphic | `store-assets/google-play/feature-graphic.png` 또는 `.jpg` |
| Play 휴대전화 | `store-assets/google-play/phone/` |
| Play 태블릿 | `store-assets/google-play/tablet/` |
| App Store iPhone 6.9형 | `store-assets/app-store/iphone-6.9/` |
| App Store iPad 13형 | `store-assets/app-store/ipad-13/` |

각 스크린샷 파일의 `platform-device-class`는 차례로
`android-phone`, `android-tablet`, `ios-iphone-6.9`,
`ios-ipad-13`을 사용한다. 제출 직전에는 다음 유한 명령으로 장수, 파일명,
해상도, 형식과 알파 채널을 검증한다. 자산이 아직 준비되지 않은 동안에는
누락된 그룹을 실패로 보고하는 것이 정상이다.

```powershell
cd apps/mobile
..\..\.toolchains\flutter\bin\dart.bat run tool/verify_store_assets.dart
```

## 3. Google Play

### 앱 아이콘

- 512×512px
- 32-bit PNG
- 최대 1,024KB
- 런처 아이콘을 단순 확대하지 않고
  `apps/mobile/assets/icons/app_icon.svg`에서 출력한다.
- Play 아이콘은 기기 런처의 adaptive icon과 별개인 스토어 자산이다.

제출 파일은 `store-assets/google-play/app-icon-512.png`에 보관한다.
검증된 iOS 1024px 출력물에서 다시 생성할 때는 다음 유한 명령을 사용한다.

```powershell
cd apps/mobile
..\..\.toolchains\flutter\bin\dart.bat run tool/generate_play_store_icon.dart
```

### Feature graphic

- 1024×500px JPEG 또는 24-bit PNG
- 알파 채널 없음
- 아이콘을 크게 반복하기보다 카드, 직접 그린 캐릭터와 캘린더가 함께
  보이는 실제 제품 경험을 중심에 둔다.
- 가장자리 잘림을 고려해 앱 이름과 핵심 피사체는 중앙 안전 영역에 둔다.
- 순수 흰색·검은색 배경만 사용하지 않고 앱의 흰 화면과
  `#DC6957` 포인트가 자연스럽게 이어지게 한다.
- 순위, 가격, 할인, 다운로드 유도 문구와 시효가 있는 표현을 넣지 않는다.
- Play Console에 140자 이하 대체 텍스트를 함께 입력한다.

### Screenshot

- 기기 유형을 합쳐 최소 2장, 휴대전화는 8장 모두 준비한다.
- JPEG 또는 24-bit PNG, 알파 채널 없음
- 각 변 320~3,840px, 긴 변은 짧은 변의 두 배를 넘지 않음
- 추천 노출 기준을 위해 휴대전화 원본은 세로 9:16, 최소
  1,080×1,920px로 촬영한다.
- 태블릿은 실제 대화면 기기에서 최소 4장을 촬영한다. Play Console의
  대화면 자산에는 1,080~7,680px 범위와 세로 9:16 또는 가로 16:9
  규격을 사용한다.
- 추가 홍보 문구 없이 실제 앱 UI를 우선 사용하고 각 이미지에 140자 이하
  대체 텍스트를 입력한다.

## 4. App Store

### iPhone

- 한 기기 크기와 언어마다 1~10장을 등록할 수 있다.
- 첫 출시에서는 6.9형 세로 원본 8장을 준비한다.
- 허용 크기 중 실제 테스트 기기에 맞는 하나를 사용한다:
  1260×2736, 1290×2796 또는 1320×2868px.
- JPEG, JPG 또는 PNG를 사용할 수 있으며 알파 채널과 투명도는 허용되지
  않는다.

### iPad

Runner는 iPhone과 iPad를 모두 지원하므로 13형 iPad 화면이 필수다.

- 실제 기기에 따라 세로 2064×2752 또는 2048×2732px
- 8개 장면 중 레이아웃 차이가 큰 홈, 캘린더, AI, 설정을 우선 캡처하고
  최종 제출에는 같은 8개 순서를 유지한다.
- 휴대전화 이미지를 확대하거나 태블릿 프레임에 합성하지 않는다.
- 알파 채널과 투명도는 허용되지 않는다.

UI와 기능이 같은 경우 App Store Connect가 고해상도 이미지를 작은
디스플레이에 맞게 축소할 수 있으므로 모든 구형 기기 크기를 별도로 만들지
않는다.

## 5. 제출 전 검증

- [ ] 모든 파일이 현재 출시 후보 commit에서 만들어짐
- [ ] 파일명, 촬영 기기, OS, 앱 version·build 기록
- [ ] Play 아이콘 512×512px, 최대 1,024KB
- [ ] Play feature graphic 1024×500px, 알파 없음
- [ ] Play 휴대전화 8장과 태블릿 최소 4장 규격 확인
- [ ] App Store iPhone 6.9형 8장 규격 확인
- [ ] App Store iPad 13형 8장 규격 확인
- [ ] 스크린샷과 feature graphic에 알파 없음
- [ ] 실사용자 개인정보와 비밀값 없음
- [ ] 디버그 배너, overflow, 오류·로딩 상태 없음
- [ ] 스토어 설명의 기능과 각 화면이 일치
- [ ] Play 이미지별 대체 텍스트 작성
- [ ] `verify_store_assets.dart` 통과

## 6. 공식 자료

- Google Play preview assets:
  https://support.google.com/googleplay/android-developer/answer/9866151
- App Store screenshot specifications:
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App Store screenshot upload:
  https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
