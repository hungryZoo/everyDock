# v0.3.6 검증 기록

기준일 2026-09-11. build 12. 고정 영역 구분선과 폴더 팝업 수명 관리.

- `EVERYDOCK_RUN_QL_TEST=1 swift test --arch arm64` 최종 소스 **41개 PASS**. 기본 실행은 40개와 명시적 통합 검사 1개 skip이다. 구분선 설정 마이그레이션·저장·이동, 고정 폭 계산, 이전 팝업 종료/등장과 재열기의 경쟁 조건을 검증했다.
- **TC-A43 PASS**: 일회용 PNG로 실제 Quick Look 썸네일을 생성하고 중앙 픽셀 색상까지 대조했다. 같은 폴더를 10회 다시 여는 동안 캐시 이미지 객체가 유지되고 이전 팝업의 종료가 현재 세션을 취소하지 않음을 확인했다. CI에서는 환경에 의존하는 이 검사를 기본 비활성화한다.
- **TC-M53 PARTIAL PASS**: 설치 후보에서 Safari 뒤 구분선 추가, 설정 목록에 표시, Safari 앞으로 이동, 재실행 후 순서 유지, 설정에서 삭제를 실제 UI로 확인했다. 검증용 구분선은 삭제해 기존 앱 순서를 유지했다. 2pt 앱 간격의 정확한 우클릭 히트와 Dock 선 자체 우클릭의 전체 행렬은 NOT RUN이다.
- **TC-M54 PARTIAL PASS**: 아래 Dock에서 고정 앱 → 실행 앱 → 폴더 순서와 두 자동 경계, 임의 구분선의 고정 폭 표시를 확인했다. 좌우 Dock·다중 모니터·좁은 화면 전체 행렬은 NOT RUN이다.
- **TC-M55 BLOCKED / macOS 인증 대기**: 실제 바탕화면 폴더는 디렉터리 응답 대기 상태여서 개인 폴더의 썸네일 개폐 검증을 완료하지 못했다. 새 서명에 기존 권한을 재등록하는 과정에서 시스템 설정이 Touch ID/암호를 요구했고 사용자에게 요청했다. Quick Look의 제어된 PNG 통합 검사와 이 미완료 실사용 검증을 구분한다. 미지원 파일·변경 파일·8초 timeout 전체 행렬은 NOT RUN이다.
- 최종 release 패키지 arm64·macOS 26 최소 버전·codesign strict PASS. 공개 배포·Homebrew 결과는 아래와 같다.

폴더별 디렉터리 읽기는 한 요청으로 병합하며 느린 OS 파일 시스템 호출 자체를 강제 종료하지 않는다. QL 요청의 8초 제한은 후속 썸네일 슬롯 정체를 막는 장치다. 원본 파일명·창 이미지·권한 DB는 커밋하지 않는다.

소스·태그 `v0.3.6`은 `99d0f41fe9b304f11dc227d223a0feead985c150`이다. [GitHub CI](https://github.com/hungryZoo/everyDock/actions/runs/34564028808)의 기본 테스트·패키징·검증 산출물 업로드 PASS. [공개 릴리스](https://github.com/hungryZoo/everyDock/releases/tag/v0.3.6)의 ZIP을 인증 없이 다운로드해 SHA-256 `50d42550a4fa2b27d8c91db9d946e5f20ebc0f0fd1ce9a50dfeaf8dfc7804837` 일치를 확인했다.

Homebrew cask `1d96a29`로 갱신했으며 style/audit PASS다. 검증한 공개 ZIP을 Homebrew 캐시에 넣고 자체 체크섬 검증을 거쳐 0.3.5 → 0.3.6 업그레이드를 완료했다. 설치 앱과 dist 실행 파일 SHA-256은 모두 `8e1df176fcabc886028a3fb5a26eba2e581857840408448b0187a4030d36437e`이며 codesign strict PASS다.

최종 번들은 설치됐으나 macOS Touch ID/암호 인증이 남아 **권한 재등록과 개인 폴더의 실사용 검증은 미완료**다. 앱은 재등록을 위해 정상 종료한 상태다. 권한 DB나 전체 디스크 접근 설정은 변경하지 않았다. 최초 설치 후보의 구분선 UI 검사 이후 썸네일 캐시 이미지를 중복 대입하는 루프를 제거했고, 최종 소스는 41개 로컬 검사와 CI를 다시 통과했다.
