# 합성 미디어 fixture

2026-10-27 현재: 한국어 OneCore Heami 발화 8개를 WAV/M4A로 생성했다.
manifest schema 2는 기준 24사례, 원본 변형 10개, 손상 코덱 대조군 3개를 포함한다.
앱 형식의 정상 JPEG/WebP/M4A와 손상본을 실제 디코딩했다.
로컬 ASR 대본 일치 1/8, 사람 청취 0/8이다.
[현재 설치/실행 계획](../../../../../docs/release/content-safety-media-live-readiness.md)과
[사람 청취표](../../../../../docs/release/content-safety-speech-review.md)를 먼저 확인한다.
초안 generator를 다시 실행하면 현재 manifest를 덮어쓰므로 실행하지 않는다.

`../content-safety-media-ko.json`은 이미지 12개와 음성 12개 사례의 초안 manifest다.
이미지 PNG/JPEG/WebP, M4A 발화 8개, PCM WAV 무음/잡음 2개와 손상/미지원 대조군을 로컬 생성했다.
실제 사진·실제 사용자 음성·개인정보는 사용하지 않았다. PNG의 한글은 Malgun Gothic으로
렌더링했다. 이는 손글씨나 사진 품질 자료가 아니며 두 글 없는 기하 이미지도 독립적인
사진 표본으로 세지 않는다. 위험 시각물을 생성하지 않았다.

한국어 음성 8개의 referenceText는 합성 입력 대본이다. 실제 발화·부정어·잡음 유무를 사람이 청취한 뒤에만
humanReviewed를 갱신한다. 목소리 복제나 사용자 녹음은 사용하지 않는다.

`humanReviewed: false`인 기대 판정은 검토용 초안이다. 손상/미지원 fixture는 decoder/adapter가
실패해야 하는 대조군이며 온라인 API에 보내지 않는다. hash 검증은 bytes의 무결성만 확인하며
정상적인 디코딩·추출·분류 결과를 입증하지 않는다. silence/noise는 PCM16 mono 16 kHz 2초다.

```powershell
cd services/ai-api
npm.cmd run --silent eval:content-safety-media
npm.cmd run --silent eval:content-safety-media -- --validate-assets
```

재생성은 Windows에서 `powershell -NoProfile -ExecutionPolicy Bypass -File eval/generate-media-fixtures.ps1`.
generator의 UTF-8 BOM을 유지한다. 이 명령은 초안 manifest를 다시 쓰므로 검토된 대본·발화 파일을
추가한 뒤에는 덮어쓰지 않는다. 다른 Windows/font 버전에서는 PNG hash가 달라질 수 있어
배포된 기준 bytes를 그대로 사용하는 편이 비교에 적합하다.

평가 조합 API는 `eval/media-safety-evaluation.ts`에 있다. port의 extraction 반환은
`{ status: 'complete', language: 'ko', text }`이고 audio에는 실제 VAD 근거의
`speechDetected: true`가 추가로 필요하다. 이미지에 한해 확인된 글 없음은
`{ status: 'no_text', text: '' }`로 표시한다. 불명확한 글을 no_text로 바꾸지 않는다.
기대 referenceText는 CER 평가용이며 공급자의 관측 text나 speechDetected를 대신 채우지 않는다.
실제 품질·비용·노출 경계 계획은 `docs/release/content-safety-media-evaluation-plan.md`를 따른다.
