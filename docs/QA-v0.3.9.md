# v0.3.9 검증 기록

기준일 2026-09-11, build 15. 일반 삭제·재설치 초기화와 매 실행 권한 검사.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`: **47개 PASS**, 실제 Quick Look 반복 열기 포함. TC-A48은 임시 UserDefaults 도메인의 첫 실행·옵션·창 상태 키를 지운 뒤 새 인스턴스에서도 값이 없는지 확인했다. TC-A49는 초기 안내 완료·로그인 실행·메뉴 아이콘 숨김 조합에서도 권한 안내가 우선함을 확인했다.
- arm64 release 패키징, macOS 26 최소 버전, strip 후 재서명, codesign strict **PASS**.
- **TC-R08 PASS**: 로컬 임시 tap의 실제 cask를 Homebrew로 1.0 설치 → 1.1 upgrade → reinstall → uninstall 했다. 배포 cask의 preflight 명령 분기는 그대로 두고 앱 대신 임시 marker와 초기화 스크립트를 사용했다. upgrade에서는 설정 marker 보존·초기화 0회, reinstall에서 설정 삭제·초기화 1회, uninstall에서 설정 삭제·누적 2회였다. fixture는 실제 everyDock 설정·권한·로그인 상태를 변경하지 않았다.
- Homebrew는 설치 당시 cask의 제거 규칙을 저장한다. 이전 설치본은 tap 변경만으로 새 제거 동작이 적용되지 않으므로 v0.3.9 업그레이드가 필요하다.
- Homebrew의 `uninstall_preflight` 사용 중단 예정 경고가 있다. 현재 설치된 Homebrew에서는 위 세 동작을 통과했으며, 구조화된 steps에는 현재 명령 분기를 그대로 옮길 수 없어 기존 호환 hook을 사용한다.
- TC-M63의 실제 권한 거부·검사 지연·로그인 시작 전체 행렬과 TC-M64의 실제 앱 제거는 배포 전 시점 **NOT RUN**이다. 단위 검사와 fixture를 실제 macOS 승인/로그인 해제 검증으로 대체하지 않는다.

ZIP SHA-256: `5ce2270b47bca7ff203e22aed2f5cf51fa94514eb67556f5f7da913426d94317`.

## 공개 배포 및 실제 앱 검증

- 소스·태그 `5e19d4d1b2329cde5394b639f0dd9f0a19925538` / `v0.3.9`. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34570429300) 테스트·패키징 **PASS**.
- 공개 ZIP을 인증 없이 내려받아 위 SHA-256 일치를 확인했다. Homebrew tap `3f7f90b`, style/audit **PASS**. Cask/InstallSteps 예외는 직렬화 시점이 아닌 실제 실행 시점의 uninstall/reinstall/upgrade 구분에 한정한다.
- 실제 Homebrew **0.3.8 → 0.3.9 upgrade PASS**. 정상 종료 전후가 아닌 upgrade 직전/직후 설정 plist의 SHA-256이 동일했다.
- 실제 **일반 uninstall → install PASS**. 앱 번들 제거와 `defaults read app.everydock.mac` 도메인 부재, 첫 실행 키 부재, 앱 캐시·Saved Application State 부재, 완료된 복원 journal 부재를 확인했다. 권한 DB는 수정하지 않았다.
- **TC-M63 PARTIAL PASS**: hasLaunched=1인 기존 설치 상태에서 새 배포본을 시작하자 손쉬운 사용과 화면 녹화의 실제 거부를 표시한 안내 창 하나가 열렸다. 나중에 설정으로 닫혔고, LaunchServices로 실행 중 앱을 다시 열자 안내가 다시 나타났다. 권한 정상/3초 지연/로그인 실행의 전체 수동 행렬은 NOT RUN이다.
- ad-hoc 배포본 실행 시 macOS 실행 차단을 확인했고 시스템 설정의 ‘그래도 열기’를 통해 최초 실행을 확인했다. 재설치 뒤 초기 안내 UI 및 로그인 해제 표시는 자동 UI 도구의 실행 연결 시간 초과로 미확인이다. 사용자가 직접 확인하겠다고 요청하여 추가 UI 검증을 중단했다. 현재 설치본은 Homebrew v0.3.9이며 실행 파일 SHA-256은 `a409bd13b8621ee91ed649de20a7aa1a9c6a963789be384d5a870ad897f50715`이다.
