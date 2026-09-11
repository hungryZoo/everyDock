# v0.3.8 검증 기록

기준일 2026-09-11, build 14. 초기 권한·로그인 안내와 메뉴 막대 아이콘 숨김.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`: **45개 PASS**. 기본 실행은 44개 PASS와 Quick Look 통합 1개 SKIP이다. TC-A46/47은 첫 실행·로그인 시작·숨김 수동 시작 분기, 숨김 설정 이전·저장, 고정 목록 보존을 확인한다.
- release 패키징: arm64, macOS 26 최소 버전, strip 후 재서명과 codesign strict **PASS**.
- 기존 사용자의 hasLaunched 상태로 새 앱을 실행했을 때 안내를 강제로 띄우지 않음을 확인했다. 설정에 초기 안내 재열기·메뉴 막대 숨김·Apps 재실행 설명이 표시됨을 확인했다.
- 설정에서 초기 안내를 열고 실제 화면을 확인했다. 창 제어·미리보기 권한 설정, 상태 재확인, 현재 앱 위치, 폴더 안내, 자동 실행 선택, 시작·나중에 설정 버튼이 표시됐다. 기존 로그인 활성 상태가 유지됐다.
- 실제 신규 계정의 권한 승인, 로그인 등록 실패·승인 필요, 로그아웃·로그인은 **NOT RUN**이다. 분기 자동 테스트를 실제 macOS 승인·자동 실행 PASS로 대체하지 않는다.

## 추가 UI 검증

- **TC-M59 PARTIAL PASS**: 저장된 첫 실행 값을 지우지 않고, 한 번의 프로세스에만 UserDefaults 인자 `-everyDock.hasLaunched NO`를 전달해 실제 최초 진입 경로를 실행했다. 안내 창 하나와 자동 실행 선택 표시를 확인했고 ‘시작하기’로 닫혔다. 인자 없는 일반 재실행에서는 안내가 반복되지 않았다. 신규 사용자 계정·미완료 상태의 전체 재실행 행렬은 NOT RUN이다.
- **TC-M61 PARTIAL PASS**: 기존 로그인 on 상태로 안내를 다시 열었을 때 on이 표시됐고 ‘나중에 설정’ 후에도 기존 상태가 유지됐다. 이미 on인 상태에서 ‘시작하기’ 완료도 확인했다. 신규 등록·해제 및 실제 로그인 실행은 수행하지 않았다.
- **TC-M62 PARTIAL PASS**: 숨김 선택을 on으로 바꾸고 설정 창을 닫았다. LaunchServices로 실행 중인 앱을 재실행하자 설정이 열렸으며, 정상 종료 후 새로 실행해도 숨김 on 상태를 유지한 설정 창이 열렸다. 검증 후 원래 off로 복원했다. Apps 검색 UI 전체 경로, 상태 아이콘 픽셀 비교, 실제 로그아웃·로그인은 NOT RUN이다.
- 최종 설치 후 초기 안내를 다시 열어 두었다. 기존 고정 앱·로그인 on·메뉴 아이콘 표시 선택을 보존했다. 권한은 자동 승인하지 않았으며 화면의 ‘확인 전’을 ‘허용됨’으로 기록하지 않는다.

## 공개 배포

- 소스·태그 `b7b66b90ff4e31a0bd4e940c9f49e898bd57832d` / `v0.3.8`.
- [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34567896358): 기본 테스트·패키징·검증 산출물 업로드 **PASS**.
- [공개 릴리스](https://github.com/hungryZoo/everyDock/releases/tag/v0.3.8) ZIP을 인증 없이 내려받아 SHA-256 `c70e4d188857b738350bb8ad41bd21f1480352ce62d95477b426fbac4575f3dd` 일치를 확인했다.
- Homebrew cask `7f1bde1`, style/audit **PASS**. 검증한 공개 ZIP을 캐시에 넣고 Homebrew 자체 체크섬 검증을 거쳐 0.3.7 → 0.3.8 업그레이드 **PASS**.
- 설치 실행 파일 SHA-256 `6bb3ca93ba8d4e9a093f454200e3ea6f7d3ff43a6fea3d9ac319e545c685a688`, codesign strict **PASS**. 공개 파일과 같은 최종 앱을 재실행했다.

사용자 설정·권한 DB·개인 파일은 공개 산출물에 포함하지 않는다.

## Homebrew 제거·재설치 조사와 cask 보완

- 사용자 제거 테스트 이후 확인 당시 앱 번들과 Homebrew 설치 목록에는 everyDock이 없었지만, 앱의 Preferences plist와 `everyDock.hasLaunched = 1`이 남아 있었다. 기존 cask는 quit만 수행하고 zap이 없었으며 일반 제거 시 설정 보존은 이전 README에 명시되어 있었다. macOS 권한 DB는 조회하지 않았다.
- cask `c406db9`에서 opt-in `zap trash`를 추가했다. 설정·캐시·저장된 창 상태만 대상으로 하고, 일반 제거·설치·업그레이드에서는 초기화하지 않는다. 앱 버전·공개 태그·ZIP·체크섬은 변경하지 않았다.
- **TC-R07 PASS (격리 fixture)**: 실제 cask의 세 zap 경로를 프로젝트 `.build/cleanup-fixture`로 치환한 임시 로컬 tap을 만들고, 앱 설치 대신 테스트 marker artifact를 사용했다. 일반 `brew uninstall --cask --force` 후 세 설정 경로와 가짜 복원 journal이 유지됐다. `brew uninstall --cask --zap --force` 후 세 경로는 사라지고 journal은 유지됐다.
- 별도의 UUID 임시 UserDefaults 도메인에 첫 실행 완료 값을 만들고 해당 plist를 같은 zap 경로로 휴지통에 보냈다. 직후 `defaults read`가 키를 찾지 못해 CFPreferences 캐시에서도 첫 실행 완료가 남지 않음을 확인했다. 이 테스트는 실제 app.everydock.mac 도메인을 삭제하지 않았다.
- 임시 tap은 검증 후 제거했다. 실제 사용자 첫 실행 키는 여전히 1이며 사용자 설정·로그인 항목·macOS 권한은 변경하지 않았다. 실제 사용자 앱의 clean install과 OS 권한 재승인 전체 절차는 **NOT RUN**이다.
- cask style/audit **PASS**. Homebrew 기본 문서의 일반 제거와 opt-in zap 구분, 로컬 macOS `tccutil(1)`의 앱별 reset 범위를 확인해 README에 반영했다. macOS 권한·로그인 상태·미복원 journal을 모두 제거했다는 보장은 하지 않는다.
