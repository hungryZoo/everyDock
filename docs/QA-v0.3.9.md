# v0.3.9 검증 기록

기준일 2026-09-11, build 15. 일반 삭제·재설치 초기화와 매 실행 권한 검사.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`: **47개 PASS**, 실제 Quick Look 반복 열기 포함. TC-A48은 임시 UserDefaults 도메인의 첫 실행·옵션·창 상태 키를 지운 뒤 새 인스턴스에서도 값이 없는지 확인했다. TC-A49는 초기 안내 완료·로그인 실행·메뉴 아이콘 숨김 조합에서도 권한 안내가 우선함을 확인했다.
- arm64 release 패키징, macOS 26 최소 버전, strip 후 재서명, codesign strict **PASS**.
- **TC-R08 PASS**: 로컬 임시 tap의 실제 cask를 Homebrew로 1.0 설치 → 1.1 upgrade → reinstall → uninstall 했다. 배포 cask의 preflight 명령 분기는 그대로 두고 앱 대신 임시 marker와 초기화 스크립트를 사용했다. upgrade에서는 설정 marker 보존·초기화 0회, reinstall에서 설정 삭제·초기화 1회, uninstall에서 설정 삭제·누적 2회였다. fixture는 실제 everyDock 설정·권한·로그인 상태를 변경하지 않았다.
- Homebrew는 설치 당시 cask의 제거 규칙을 저장한다. 이전 설치본은 tap 변경만으로 새 제거 동작이 적용되지 않으므로 v0.3.9 업그레이드가 필요하다.
- Homebrew의 `uninstall_preflight` 사용 중단 예정 경고가 있다. 현재 설치된 Homebrew에서는 위 세 동작을 통과했으며, 구조화된 steps에는 현재 명령 분기를 그대로 옮길 수 없어 기존 호환 hook을 사용한다.
- TC-M63의 실제 권한 거부·검사 지연·로그인 시작 전체 행렬과 TC-M64의 실제 앱 제거는 배포 전 시점 **NOT RUN**이다. 단위 검사와 fixture를 실제 macOS 승인/로그인 해제 검증으로 대체하지 않는다.

ZIP SHA-256: `5ce2270b47bca7ff203e22aed2f5cf51fa94514eb67556f5f7da913426d94317`.
