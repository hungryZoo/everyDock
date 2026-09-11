# v0.3.7 검증 기록

기준일 2026-09-11, build 13. Command-드래그 정렬.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64`: **43개 PASS**. TC-A44/45의 슬롯 보정·인접 이동·구분선 저장·미고정 앱 삽입·중복 방지와 기존 회귀 검사를 통과했다. 기본 실행은 42개 PASS와 Quick Look 통합 1개 SKIP이다.
- release 패키징: arm64, macOS 26 최소 버전, strip 후 재서명과 codesign strict **PASS**.
- 최종 ZIP에서 꺼낸 앱을 `/Applications/everyDock.app`에 적용해 실행했다. 사용자 고정 앱·구분선 목록을 유지하며 새 빌드가 실행됨을 확인했다.
- TC-M56 **PARTIAL PASS / 사용자 확인**: 첫 실행 후보에서 사용자가 Command-드래그 이동이 정상이라고 확인했다. 이후 피드백에 따라 잡는 순간 확대 해제와 실행 영역으로 이동 시 고정 해제를 추가했다. 이 보완본의 조작 확인은 별도로 기록한다.
- TC-M57~58 **NOT RUN**: 현재 UI 도구의 drag는 modifier 인자를 제공하지 않아 Command를 누른 채 드래그하는 실제 동작은 자동 검사하지 못했다. 삽입 계산의 자동 검사를 실제 다중 화면·취소·프레임 성능 PASS로 대체하지 않는다.

드래그 중 자동 스크롤과 미고정 실행 앱끼리의 임시 순서 변경은 지원하지 않는다. 미고정 앱은 고정 영역으로 옮겨 순서를 저장할 수 있다. 드래그는 창 제어·화면 녹화 권한을 추가로 사용하지 않는다. 앱 업데이트의 기존 ad-hoc 권한 등록 제약은 유지된다.

## 공개 배포

- 소스·태그: `b6b85952dac49bc4fcd66b9b1321c805356b8e4b` / `v0.3.7`.
- [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34566357635): 테스트·패키징·검증 산출물 업로드 **PASS**.
- [공개 릴리스](https://github.com/hungryZoo/everyDock/releases/tag/v0.3.7) ZIP을 인증 없이 다시 내려받아 SHA-256 `7497aed43d6eff7faeb71c97822e5533a7bd337dc534d48fa9d5f40f29a6be0a` 일치를 확인했다.
- Homebrew cask `e19186b`: style/audit **PASS**. 검증한 공개 ZIP을 캐시에 넣고 Homebrew 자체 체크섬 검증을 거쳐 0.3.6 → 0.3.7 업그레이드 **PASS**.
- 설치 실행 파일 SHA-256 `d596aa0eb447f3a51eadf08b274484116890883adaa7eea5b7089123e7c3464c`, codesign strict **PASS**. 앱을 정상 종료한 뒤 교체하고 재실행했다. 사용자 설정·권한 DB·개인 파일은 배포에 포함하지 않았다.

첫 후보의 사용자 이동 확인과 최종 보완본 검증 범위를 구분한다. 최종본은 확대 해제·고정 해제 조작 확인을 요청한 상태이며, 응답을 받기 전에는 실기기 PASS로 기록하지 않는다.
