# v0.3.3 검증 기록

기준일 2026-09-10. v0.3.3 build 9 배포본. 창 1개 미리보기 맞춤 크기, 바탕화면 파일 스택, Spotlight Apps 연결, 네이티브 Dock 메뉴 요청, 확대 창 경계·복원, 파일 썸네일.

- `swift test --arch arm64` **37개 PASS**. TC-A31은 자체 앱 목록 제거로 폐기하고 TC-A32~A38에 복원 상태·정렬·애니메이션 좌표 회귀를 추가했다.
- release 패키지의 **arm64·macOS 26 최소 버전·코드 서명 검증 PASS**. 로컬 ad-hoc 서명이다.
- 이전 소스 `0721e445a67009217c6317345d7358ee34ba5c79`의 [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34339311149)는 PASS였으나, 이번 9월 10일 수정본의 CI 결과로 재사용하지 않는다.
- **TC-M43 PARTIAL PASS (사용자 확인, build 7)**: Apps 클릭으로 Spotlight의 앱 화면이 열린다고 사용자가 확인했다. 시스템 앱 실행 경로는 build 8에서도 동일하다. 자동 UI 도구는 Spotlight AX 조회가 timeout이어서 전체 검색·재개방 행렬을 PASS로 기록하지 않는다.
- **TC-M44 PARTIAL PASS (사용자 확인, build 7)**: 사용자가 확대 후 원래 크기 복원과 Dock 경계가 정상이라고 확인했다. 직전 ‘복원 안 됨’ 답변은 잘못 누른 것으로 정정했다. geometry trace에서 2304×1266 → 2304×1212 경계 보정, 기존 1262×546 크기·원위치 복원을 3회 확인했다. 공개 로그에는 제목·개인 파일명·창 이미지를 포함하지 않는다.
- **TC-M44 복원 애니메이션 NOT RUN (build 8)**: 사용자가 즉시 크기 변경의 어색함을 보고해 CADisplayLink 기반 약 180ms 복원을 추가했다. 좌표 회귀만 자동 검증했으며 실제 전환의 부드러움·동작 줄이기·앱 전환 취소 행렬은 추가 확인 대상이다.
- **TC-M46 PARTIAL / 위치 문제 확인 (build 7~8)**: 사용자가 카카오톡 고유 메뉴가 열리지만 다른 모니터에 뜨는 문제를 확인했다. build 9에서 시스템 Dock 위치와 everyDock 화면이 다르면 호출을 막고 안내하도록 보완했다. 이 제한 처리의 실제 화면 행렬은 NOT RUN이며 앱 고유 메뉴의 다중 모니터 복제 기능은 지원하지 않는다.
- **TC-M42/M47 PARTIAL PASS (build 9)**: Homebrew 설치본에서 바탕화면 파일 목록과 실제 PNG 내용 썸네일, 비율 유지 및 수정일 최신순 안내를 화면으로 확인했다. **다운로드는 폴더 읽기 대기 상태**여서 썸네일·클릭·재개방 행렬을 검증하지 못했다. PDF·미지원 파일·취소·수정일 변경 후 갱신의 전체 행렬도 NOT RUN이다. 폴더 읽기 대기를 화면 기록 권한 거부로 분류하지 않는다.
- TC-M41의 실제 3→2→1 팝업 크기 행렬과 TC-M45의 전체 화면·양옆 Dock·다른 화면 조합은 NOT RUN이다. 자동 좌표 테스트로 실제 AX 동작을 대체하지 않는다.

공개 태그 v0.3.3은 095fb70을 가리키며 [릴리스](https://github.com/hungryZoo/everyDock/releases/tag/v0.3.3)에 ZIP·SHA256SUMS를 게시했다. Homebrew cask 33b2cd2로 갱신했고, 이 Mac에서도 brew upgrade로 0.3.2 → 0.3.3 설치를 완료했다. 이전 릴리스 QA의 사용자 확인과 성능을 이 버전 전체 PASS로 재사용하지 않는다. 원본 진단 로그·창 이미지·사용자 파일은 저장소에 올리지 않는다.

소스 74723bc의 [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34425968227)는 테스트·패키징 검증 PASS. build 8의 최종 번들을 재등록한 뒤 AX·화면 기록 모두 실제 사용 가능 상태를 확인했다. build 9의 메뉴 화면 제한을 포함한 소스 a5dcc9b의 [CI](https://github.com/hungryZoo/everyDock/actions/runs/34426482219)도 테스트·패키징·검증 산출물 업로드 PASS다. 태그의 추가 변경은 릴리스 문구뿐이다.

배포 검증: Homebrew style/audit PASS. 공개 ZIP을 인증 없이 다시 다운로드해 SHA-256 `216fb6e10529cbd5f6be06296b4c094484da20e1ad5b48d2777adeced50c40f0` 일치를 확인했다. Homebrew의 리디렉션 다운로드 지연으로 첫 fetch를 중단한 뒤, 이 검증된 공개 ZIP을 캐시에 넣고 Homebrew 자체 체크섬 검증을 거쳐 업그레이드했다. 설치 앱과 dist 앱의 실행 파일 SHA-256은 모두 `3c7d770a5df0aacdfba5dadce1a02c9f8bb3c441bb950a68cefb35af20afd0eb`이며 codesign strict 검증을 통과했다.

최종 배포본을 기존 손쉬운 사용·화면 기록 항목에 재등록한 뒤 두 실제 접근 검사가 ‘사용 가능’인 것을 확인했다. 디버그 trace 없이 정상 실행 중이다. 전체 디스크 접근 설정은 변경하지 않았다. 테스트용 WindowFixture는 종료했다.

다운로드 대기 추가 진단: 설치 앱을 1초 sample한 결과 FolderContents.load → NSFileManager.contentsOfDirectoryAtURL → DirEnumRead → open/__open에서 백그라운드 작업이 대기했다. 썸네일 생성 이전의 OS 디렉터리 열기 단계이며, 이것만으로 권한 거부인지 파일 시스템 응답 지연인지 단정하지 않는다. 원본 sample은 커밋하지 않았다.
