# v0.3.4 검증 기록

기준일 2026-09-10. v0.3.4 build 10. 앱 고유 메뉴의 로컬 표시·명령 전달. 이전 버전의 같은 모니터 제한과 설정 창 경고를 제거했다.

- `swift test`: 37개 PASS. TC-A38은 폐기하고 TC-A39로 인덱스·제목·식별자·하위 메뉴 여부가 변경된 명령의 일치 거부를 검증했다.
- **TC-M46/TC-M48 PARTIAL PASS**: 카카오톡 앱 제공 메뉴가 everyDock의 로컬 메뉴로 표시됨을 확인했다. 사용자가 기본 Dock이 없는 모니터에서도 현재 아이콘 옆에 정상 표시된다고 확인했다. 모든 화면 배치·양옆 Dock 조합까지 PASS로 확대하지 않는다.
- **TC-M48 명령 전달 PASS**: 직접 만든 WindowFixture의 `Mark Test Window`를 로컬 메뉴에서 선택한 뒤 실제 fixture 창 제목이 `Dock menu command received`로 바뀌는 것을 확인했다. 사용자 앱의 메시지 전송·로그아웃·종료 명령은 실행하지 않았다.
- **TC-M49 PARTIAL PASS**: fixture 비활성 항목이 비활성으로 표시됐다. `Nested Test Menu…`에서 하위 명령과 이전 메뉴 항목이 표시됐고, 하위 명령을 실행한 뒤 fixture 창 제목이 `Nested Dock menu command received`로 바뀌었다. 카카오톡 메뉴에서 Escape로 닫힌 뒤 일반 Dock 입력이 가능한 것을 확인했다. 이전 메뉴 재진입·외부 클릭·모든 체크 표시 조합은 NOT RUN이다.
- **TC-M50 PARTIAL PASS**: 초기 통합 검사에서 아직 생성되지 않은 시스템 메뉴를 읽지 못했을 때 설정 창 대신 일반 everyDock 메뉴 안에 안내가 표시됐다. 최대 20회, 20ms 간격의 백그라운드 대기를 추가한 뒤 메뉴 읽기와 실행을 확인했다. 실행 중 실제 메뉴 변경·앱 종료·권한 거부·응답 지연의 전체 오류 주입 행렬은 NOT RUN이다.
- release 패키지 arm64·macOS 26 최소 버전·codesign strict 검증 PASS. ad-hoc 서명이다.

원래 시스템 메뉴가 조회·명령 전달 중 잠시 나타날 수 있다. 앱이 제공하는 접근성 메뉴를 읽는 방식으로, 네이티브 메뉴의 모든 시각 효과·키보드 보조키 변형을 그대로 복제하지는 않는다. 기본 Dock에 해당 항목이 없거나 메뉴를 읽을 수 없는 앱은 일반 everyDock 메뉴를 사용한다. 진단은 opt-in `EVERYDOCK_TRACE_WINDOWS=1`에서 메뉴 단계·개수·결과 코드만 기록한다. 개인 메뉴 제목·화면 이미지·권한 DB는 저장소에 올리지 않는다.

공개 배포·Homebrew 설치 결과는 완료 후 갱신한다. 현재 검증은 동일한 ZIP에서 추출한 /Applications 설치 후보로 수행했다.
