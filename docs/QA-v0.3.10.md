# v0.3.10 검증 기록

2026-09-11, build 16. 화면 기록 권한의 자동 요청 방지와 초기 안내 간소화.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`: **49개 PASS**, Quick Look 통합 포함.
- **TC-A50 PASS**: 실제 AppPermissions에 무권한 preflight와 호출 횟수를 기록하는 콘텐츠 제공자를 주입했다. 자동 조회 10회에서 캡처 API 0회, 명시 요청에서 1회, 거부 후 자동 조회 10회에서 추가 0회였다. macOS 권한 DB나 실제 화면 요청을 사용하지 않았다.
- **TC-A51 PASS**: preflight 철회 시 차단, 실제 거부 이후 긍정 힌트에도 자동 요청 차단, 명시적 버튼 요청은 재시도 가능함을 확인했다.
- 시작·재열기·일반 상태 재확인의 recheck 기본 경로는 CGPreflightScreenCaptureAccess만 사용하고 ScreenCaptureKit 호출 전에 반환한다. AppModel의 화면 권한 버튼만 requestCapturePermission=true로 호출한다. 창 이미지 API 직전에도 상태를 검사한다.
- 초기 안내에서 하단 재확인/앱 위치/재등록/폴더 설명 Section을 제거했다. 기본 높이 620, 최소 520으로 축소했다. 해당 도움말은 일반 설정과 README에 유지한다.
- arm64 패키징·macOS 26 최소 버전·codesign strict **PASS**.
- **TC-M65 NOT RUN**: 실제 신규 권한 상태에서 OS 대화상자가 나타나지 않는지와 초기 안내의 화면 배치는 사용자가 확인한다. 자동 테스트를 OS UI 검증 PASS로 기록하지 않는다.

ZIP SHA-256: `e39ab40fa37cf433ab657c918ca8169b2a6f18bf93f26b3b13f7ce475401d35b`.
