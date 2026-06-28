# vinscent mobile

Flutter 모바일 앱 프로젝트다.

## 로컬 실행 규칙

- `apps/mobile` 안에서는 항상 `.\flutterw.cmd`를 사용한다.
- `D:\vinscent\.toolchains\flutter\bin\flutter.bat`를 직접 호출하지 않는다.
- Pub cache 경로가 섞였는지 확인할 때는 루트 검증 스크립트를 실행한다.

## 기본 명령어

```bash
cd apps/mobile
.\flutterw.cmd pub get
.\flutterw.cmd analyze
..\..\scripts\verify_flutter_cache.cmd
```

앱 실행 예시:

```bash
cd apps/mobile
.\flutterw.cmd run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

상세 개발 환경 설명은 [docs/development-setup.md](../../docs/development-setup.md)를 따른다.
