# v0.3.5 검증 기록

기준일 2026-09-10. v0.3.5 build 11. 우클릭 통합 메뉴.

- 앱 고유 메뉴를 따로 선택하는 단계를 제거했다. 읽은 앱 메뉴 다음에 everyDock 기본 기능을 같은 메뉴에 표시한다.
- 실행 중인 앱은 백그라운드 조회 완료 후 표시한다. 실행하지 않은 앱은 조회 없이 기본 메뉴를 표시한다. 읽기 실패도 기본 기능을 유지한다.
- `swift test --arch arm64`: 37개 PASS. release 패키지 arm64·macOS 26 최소 버전·codesign strict PASS.
- **TC-M51 PASS (현재 화면)**: WindowFixture 우클릭 한 번으로 앱 제공 명령·비활성 항목·하위 메뉴와 everyDock 열기·열린 창 보기·모든 창 닫기·고정·Finder 열기가 함께 표시됐다. 카카오톡도 앱 제공 항목과 everyDock 항목이 동시에 표시되고 별도 진입 항목이 없는 것을 확인했다.
- **TC-M52 PARTIAL PASS**: 통합 메뉴의 `Mark Test Window` 선택 후 실제 fixture 제목이 `Dock menu command received`로 바뀌었다. everyDock의 모든 창 닫기 선택 후 화면에 보이는 fixture 일반 창이 0개인 것을 CG 창 목록으로 확인했다. 종료된 창의 AX 조회는 timeout이므로 AX 전체 닫힘 행렬까지 PASS로 확대하지 않는다. 실행하지 않은 Safari는 열기·고정 해제·순서 이동·Finder 열기 기본 메뉴가 표시됐다. Escape 닫기 후 재진입을 확인했다.
- 이번 빌드에서 Control-클릭·접근성 요청·오류 주입·하위 메뉴 실행·다중 모니터 전체 행렬은 NOT RUN이다. 해당 진입은 동일 메서드로 연결하지만 코드 확인을 실기기 PASS로 대체하지 않는다.
- 동일한 패키지를 /Applications에 설치하고 권한 등록을 갱신해 검사했다. 공개 배포·Homebrew 설치 결과는 아래와 같다.

메뉴 항목·명령 전달·하위 메뉴를 읽는 구현은 v0.3.4와 동일하다. 원래 시스템 메뉴가 조회·전달 중 잠시 나타나는 제한은 유지한다. 개인 메뉴 내용·창 이미지를 커밋하지 않는다.

소스 및 태그 `v0.3.5`의 커밋은 `256e128e01a4adc6568b77c8c38dd9aed76dc2d7`이다. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34436225914)의 테스트·패키징·검증 산출물 업로드 PASS. [공개 릴리스](https://github.com/hungryZoo/everyDock/releases/tag/v0.3.5)의 ZIP을 인증 없이 다시 다운로드해 SHA-256 `46c6caecd7e9c99b26caaee9e67897f95c26b0b7535db4e8dbafc947de58a8dd` 일치를 확인했다.

Homebrew cask `9d99a07`로 갱신했으며 style/audit PASS다. 검증한 공개 ZIP을 Homebrew 다운로드 캐시에 넣고 Homebrew 자체 체크섬 검증을 거쳐 0.3.4 → 0.3.5 업그레이드를 완료했다. `brew list --cask --versions everydock`에서 0.3.5를 확인했다. 설치 앱과 dist 실행 파일 SHA-256은 모두 `51b81ce56f043ea1f289e1a45ca7a5ba4b7c464ea56f3667d1e370c8d9861e79`이며 설치 앱 codesign strict PASS다.

설치 후 실제 접근 검사에서 손쉬운 사용·화면 기록 모두 ‘사용 가능’을 확인했다. 검증용 fixture는 종료했고 everyDock은 정상 실행 중이다. 권한 DB·전체 디스크 접근 설정은 변경하지 않았다.
