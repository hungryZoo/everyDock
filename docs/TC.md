# TC — Test Cases

| 항목 | 내용 |
|---|---|
| 문서 버전·기준일 | 1.12 / 2026-09-11 |
| 대상 | everyDock v0.3.10, Apple Silicon, macOS 26+ |
| 요구사항 | [SRS](SRS.md), [추적표](README.md) |
| 기존 실행 근거 | [QA.md](../QA.md), Swift Testing 실행 결과 |

## 1. 실행 원칙과 환경

아래 ID별 자동·수동·성능·개인정보·배포 검사를 관리한다. PASS는 해당 절차와 환경에서만 유효하다. PARTIAL/BLOCKED/NOT RUN은 전체 통과로 집계하지 않는다.

| 환경 | 구성 |
|---|---|
| E1 기본 | Apple Silicon, macOS 26+, 화면 2대, release 앱, 앱 5~20개 |
| E2 화면 | 화면 3대, 음수 X/Y, 혼합 Retina 배율, 아래·왼쪽·오른쪽 |
| E3 권한 | AX/화면 기록 각각 허용·거부·철회·업데이트 후 재등록 |
| E4 파일 | 별도 테스트 사용자, Desktop/Downloads/Trash의 테스트 파일만 |
| E5 배포 | 새 checkout, Xcode 26+, Homebrew, 기존 everyDock cask 없는 상태 |

실행 기록에는 OS 버전·칩·화면 구성·앱 버전·commit·권한·결과·실패 재현을 남긴다. 창 제목, 계정 경로, 실제 문서 내용은 공개 스크린샷과 로그에서 제거한다. 파일 테스트는 `everyDock-TC-날짜-UUID` 이름의 폴더와 더미 파일을 사용한다. **비우기는 휴지통에 테스트 파일만 있는 별도 사용자에서 수행한다.** 실제 사용자 휴지통 전체를 테스트용으로 삭제하지 않는다.

## 2. 자동 테스트

실행: `swift test --arch arm64`. 현재 37개 PASS(2026-09-10). 이름은 실제 Swift Testing 함수와 일치한다.

| ID | 함수·소스 | 검증 입력과 기대 결과 | 연결 |
|---|---|---|---|
| TC-A01 | `positionsOnDisplaysWithNegativeOrigins` / DockLayoutTests | 음수 원점, 3개 edge → 계산 frame이 영역 안에 있음 | NFR-01, FR-01의 보조 검증 |
| TC-A02 | `overflowingDockFitsScreen` / DockLayoutTests | 800×600, 항목 100 → 계산 크기가 여백 포함 영역 이내 | NFR-01, FR-03의 보조 검증 |
| TC-A03 | `bottomUsesUsableAreaAboveNativeDock` / DockLayoutTests | visibleFrame y=90, inset=10 → 계산 minY=100 | FR-02의 보조 검증 |
| TC-A04 | `preferencesRoundTripAndNormalize` / DockLayoutTests | icon=900, inset=-5, 중복 bundle → 범위 보정·중복 제거·JSON 왕복 | FR-16, FR-17 |
| TC-A05 | `magnificationIsContinuousAndAffectsNeighbors` / DockBehaviorTests | 중심·이웃·멀리 떨어진 ±거리 → 범위·대칭·주변 확대 | FR-04 |
| TC-A06 | `oldPreferencesMigrateWithoutLosingPins` / DockBehaviorTests | 구버전 JSON → 핀·위치 유지, 누락 필드 기본값 | FR-17 |
| TC-A07 | `recoveryRestoresAbsentValuesButPreservesUserEdits` / DockBehaviorTests | bool·absent·수동 변경 number → 원래 값 복원, 사용자 수정 유지 | FR-09, NFR-05 |
| TC-A08 | `utilityTilesAreIncludedInDockWidth` / DockMetricsTests | 39pt, 앱 0 → 길이147/두께51; 앱 추가 길이+41 | FR-03 |
| TC-A09 | `nativeMagnificationIsNotClampedToTwoTimes` / DockMetricsTests | 2.6667배 JSON → 2배로 잘리지 않고 유지 | FR-03 |
| TC-A10 | `genieSettingParticipatesInSafeRecovery` / DockMetricsTests | scale→genie snapshot → scale 복원, 사용자 변경은 유지 | FR-08, FR-09 |
| TC-A11 | `permissionDenialIsNotAWindowCapabilityError` / RegressionTests | AX 거부·타임아웃·창 없음·미지원·무효 객체를 서로 다른 실패로 분류 | FR-06, FR-18 |
| TC-A12 | `onlyScreenCaptureUserDeclinedMeansPermissionDenied` / RegressionTests | SCK domain+userDeclined만 거부, 다른 domain/오류/취소는 제외 | FR-14, FR-18 |
| TC-A13 | `animationProgressDependsOnTimeNotRefreshRate` / RegressionTests | 60/120Hz·불규칙 프레임 간격, 총 0.5초 → 같은 확대 진행률 | FR-04, NFR-02 |
| TC-A14 | `panelAlignmentIsStableAcrossFractionalAndNegativeCoordinates` / RegressionTests | 음수·소수 좌표, 1×/2× → 픽셀 정렬의 멱등성 및 중심 오차 한계 | FR-01, FR-03 |
| TC-A15 | `iconControlCancelsReleaseOutsideAndTracksDragBackInside` / DockControlTests | 아이콘 밖에서 놓기→취소, 드래그 후 안에서 놓기→한 번 실행, tracking 해제 | FR-04 |
| TC-A16 | `iconControlSupportsAccessibilityPressWithoutMouseTracking` / DockControlTests | 접근성 Press→한 번 실행, 마우스 tracking 없음 | FR-04, NFR-06 |
| TC-A17 | `iconControlSupportsSpaceAndReturn` / DockControlTests | Space/Return 각각 한 번 실행 | FR-04, NFR-06 |
| TC-A18 | `captureMetadataNeverAddsGhostWindows` / WindowMatchingTests | AX 1개 + SC 3개·제목 변경 → 카드 매핑 1개, AX 빈 목록 → 0개 | FR-14 |
| TC-A19 | `sameTitleWindowsKeepSeparateOneToOneImages` / WindowMatchingTests | 동명 창·역순 SC 목록 → 서로 다른 1:1 이미지 | FR-14 |
| TC-A20 | `missingMinimizedAndMovedWindowsDoNotBorrowAnotherImage` / WindowMatchingTests | 누락·이동 창 → 타 창 이미지 연결 안 함 | FR-14 |
| TC-A21 | `menuPlacementUsesIconEdgeAndClampsNegativeScreens` / WindowMatchingTests | 3개 edge·음수 좌표·화면 모서리 → 아이콘 기준 간격과 화면 경계 | FR-21 |
| TC-A22 | `tooltipCentersTextVerticallyAtDifferentHeights` / DockControlTests | 한글/영문 3개·26/32/40pt → 레이블 세로 중심 일치 | FR-21 |
| TC-A23 | `closeAllStopsAtSaveConfirmation` / WindowCloseTests | 두 번째 창 확인 대기 → 세 번째 요청 없음 | FR-20 |
| TC-A24 | `closeAllSkipsAlreadyClosedButStopsAtErrors` / WindowCloseTests | 닫힌 창 건너뛰고 미지원 오류에서 중단 | FR-20 |
| TC-A25 | `closeAllCompletesOnlyItsInitialSnapshot` / WindowCloseTests | 시작 목록 각 항목 한 번 처리 | FR-20 |
| TC-A26 | `previewFitsOneTwoAndManyWindows` / WorkAreaTests | 0/1/2/9개 → 열 수·너비·스크롤 높이 | FR-14 |
| TC-A27 | `bottomZoomReservesOnlyRestingDockAndIsIdempotent` / WorkAreaTests | 음수 원점, 화면 채운 창 → Dock 위 경계, 재보정 없음 | FR-23 |
| TC-A28 | `workAreaPreservesNormalMinimizedAndFullScreenWindows` / WorkAreaTests | 일반·최소화·전체 화면 → 변경 없음 | FR-23 |
| TC-A29 | `sideDockReservesCorrectEdgeOnNegativeDisplays` / WorkAreaTests | 음수 X/Y, 양옆 Dock → 해당 경계 보정 | FR-23 |
| TC-A30 | `appsLauncherIsNotTreatedAsRegularWindowApplication` / ApplicationCatalogTests | Apps/Launchpad만 특별 경로, Finder·nil 제외 | FR-22 |
| TC-A31 | RETIRED (2026-09-10) | 자체 설치 앱 목록 제거로 해당 구현·테스트 폐기. ID는 재사용하지 않음 | FR-22 |

TC-A01~A03은 레거시 `DockLayout` 함수 테스트다. 실제 NSPanel, 다중 화면, WindowServer 및 새 DockMetrics 배치를 대신 검증하지 않는다. TC-A05도 실제 모니터 프레임레이트나 시각적으로 완벽한 연속성을 증명하지 않는다.

## 3. 화면·앱 기능 테스트

| ID / 우선순위 | 사전조건 | 절차 | 기대 결과 | 요구 / 현재 결과 |
|---|---|---|---|---|
| TC-M01 / P0 | E1, 두 화면 표시 켬 | 실행 후 두 화면 확인, 각 화면 Finder 클릭 | 화면마다 Dock 1개, 실행/활성 상태 공유 | FR-01 / PARTIAL: 2대 감지·렌더링 관찰, 각 화면 클릭 회차 추가 필요 |
| TC-M02 / P0 | E2 | 보조 화면을 주 화면 왼쪽·위에 놓고 각 edge 변경 | 패널·최대 확대가 화면 안에 있고 클릭 위치 일치 | FR-01~03 / NOT RUN |
| TC-M03 / P0 | E1 | 케이블 분리/연결 5회, 잠자기/복귀 3회 | 남은 화면 정상, 재연결 패널 중복 없음, 설정 보존 | FR-01 / NOT RUN |
| TC-M04 / P1 | E1 | 개별 Spaces 켬/끔, 전체 화면 옵션 켬/끔, Stage Manager 전환 | 옵션과 OS 허용 범위대로 표시, 종료·Spaces 전환 방해 없음 | FR-02 / NOT RUN |
| TC-M05 / P0 | E1 | 일시 숨김→복원, 화면 전부 해제→메뉴에서 재선택 | 패널 숨김·복구, 메뉴 접근 유지, 기본 Dock 복원 | FR-02, FR-08 / NOT RUN |
| TC-M06 / P0 | native 39/104 및 연동 켬 | 기본 Dock 크기·확대 변경, 연동 해제해 수동 크기 변경 | 연동값 반영, 수동 설정 독립 보존, 과밀 목록 스크롤 | FR-03 / PARTIAL: 39→104와 유틸리티 렌더링 관찰 |
| TC-M07 / P0 | E1 | 아이콘 가로질러 이동·정지·이탈·클릭, 확대 상단 빈 공간 클릭 | 이웃 확대·밀림, 진동·잔상 없음, 빈 공간은 아래 앱 클릭 | FR-04 / PARTIAL: 최종 NSControl 버전에서 사용자 ‘이제 부드러움’ 확인, 입력 A15~17 PASS; 전체 표시 FPS 행렬 미실행 |
| TC-M08 / P0 | 미실행 앱 하나 | 실행 클릭 후 launch 상태, 외부 실행/종료, 활성 앱 전환 관찰 | 즉시 요청 반응, 상태 반영, 포커스만으로 순서 안 바뀜 | FR-05, FR-07 / PARTIAL: v0.2 Music 요청·반영 기록, 외부 실행·종료 행렬 추가 필요 |
| TC-M09 / P0 | AX 허용, genie, 문서 창 | 앱 활성화→Dock 재클릭, 10회 반복 | 실제 창 최소화, 시스템 애니메이션. 앱 숨김과 구분 | FR-06 / PARTIAL: 재등록 후 API 성공·사용자 최소화 정상 확인; 10회 반복 미실행 |
| TC-M10 / P0 | AX 허용, 최소화 창 2개 | Dock 클릭, 이후 프리뷰에서 개별 창 선택 | 앱 클릭은 최소화 창 복원, 개별 카드는 대상 창 복원 | FR-06, FR-15 / PARTIAL: AX 접근 성공, 다중 최소화 창·개별 복원 행렬 미실행 |
| TC-M11 / P0 | AX 거부, 활성 문서 창 | 재클릭 최소화 시도, 다른 앱 실행·설정·종료 | 권한 안내, 창 숨겨지지 않음, 다른 조작 가능 | FR-06, FR-18 / NOT RUN |

## 4. 기본 Dock 복원 테스트

기존 설정의 값뿐 아니라 **키가 원래 없었는지**도 기록한다. 시스템 설정을 사용자 테스트 계정에서만 변경한다. 종료 직후 Dock 재시작이 끝난 상태에서 비교한다.

| ID / 우선순위 | 사전조건 | 절차 | 기대 결과 | 요구 / 현재 결과 |
|---|---|---|---|---|
| TC-M12 / P0 | 관리 끔, 원래 4키 기록 | 관리 켬→값/journal 확인→관리 끔→정상 종료 | 백업 후 적용, 4키 및 부재 상태 원복, journal 정리 | FR-08 / PARTIAL: v0.2 3키 적용·복원 관찰, v0.3 mineffect는 A10만 |
| TC-M13 / P0 | 관리 켬, watchdog 실행 | 주 PID만 SIGTERM, 별도 회차 SIGKILL, 5초 관찰 | watchdog 생존·원래 Dock 복원·journal 정리 | FR-09, NFR-03 / PARTIAL: v0.2 SIGTERM 확인, SIGKILL 미실행 |
| TC-M14 / P0 | 관리 켬 | 일부 키를 사용자 설정에서 변경한 뒤 종료 | everyDock 적용값인 키만 복원, 수동 변경값 유지 | FR-09, NFR-05 / NOT RUN: 모델은 A07/A10 PASS |
| TC-M15 / P0 | E4, 남은 유효 journal / 별도 손상 journal | 두 프로세스 종료 상황 후 관리 재시작; 손상 기록으로 재시도 | 유효 기록 복구, 손상 파일로 다른 설정 덮어쓰지 않음, 오류·기록 보존 | FR-09 / NOT RUN |

## 5. 유틸리티·파일 테스트

| ID / 우선순위 | 사전조건 | 절차 | 기대 결과 | 요구 / 현재 결과 |
|---|---|---|---|---|
| TC-M16 / P1 | Desktop 접근 허용/거부, 다른 앱 표시 | 바탕화면 클릭→파일 목록→닫기, 다시 열기·파일 클릭·Finder 열기 | 앱 숨김 없이 바탕화면 파일 팝업 표시, 접근/빈 상태 구분 | FR-10 / v0.3.3에서 절차 변경, QA-v0.3.3 참조 |
| TC-M17 / P1 | Downloads 접근 거부/대기 | 팝업 열고 2초 대기, 닫고 재개방 | 안내·Finder 버튼, UI 응답, 중복 디렉터리 요청 없음 | FR-11 / PARTIAL: 팝업·대기 안내 관찰, 최종 중복 요청 구현은 코드 확인 |
| TC-M18 / P1 | E4, Downloads 접근 허용 | 빈 폴더, 파일 90개, 수정일 변경, 항목 클릭 | 빈 상태/최근80개/정렬/열기 정상 | FR-11 / BLOCKED: 현재 폴더 접근 응답 대기 |
| TC-M19 / P1 | E4, 빈/찬 휴지통 | 아이콘 클릭, 외부에서 테스트 파일 이동 후 아이콘 확인 | Finder에 사용자 휴지통 표시, 아이콘 갱신 | FR-12 / NOT RUN |
| TC-M20 / P0 | 휴지통에 파일 있어도 삭제 실행 금지 | 우클릭→비우기 확인→취소, 별도 회차 Return 취소 | 대상·영구 삭제 안내, 취소 뒤 삭제 0건, Return은 취소 | FR-12, NFR-05 / PARTIAL: 대화상자·취소 관찰, 명시적 Return 기본값 수정 후 미실행 |
| TC-M21 / P0 | E4, 휴지통에 더미 파일만 | 파일 드롭→Finder에서 복구 확인→재드롭→확인 후 비우기 | NSWorkspace 휴지통 이동, 복구 가능, 승인한 테스트 파일만 제거 | FR-12, FR-13 / NOT RUN |
| TC-M22 / P0 | E4, source/target 더미 파일과 SHA-256 | Desktop/Downloads 드롭, 동명·동일 경로·읽기전용·여러 파일 오류 반복 | 원본·기존 target 해시 보존, 오류 명시, 부분 성공을 전체 취소로 표시 안 함 | FR-13, NFR-05 / NOT RUN |

TC-M21은 외장 볼륨 파일은 제외한 기본 회차와 외장 휴지통이 비우기 대상에서 제외되는 별도 회차로 나눈다. 복원과 비교가 끝난 테스트 파일만 정리한다.

## 6. 미리보기·설정 테스트

| ID / 우선순위 | 사전조건 | 절차 | 기대 결과 | 요구 / 현재 결과 |
|---|---|---|---|---|
| TC-M23 / P1 | 실행 앱, 화면 기록 거부 | 0.55초 호버, 미실행 앱 호버, 팝업으로 이동·이탈 | 실행 앱에 권한 안내 팝업, 미실행 앱은 없음, 이동 유지·이탈 닫힘 | FR-14, FR-15 / PARTIAL: 권한 안내 팝업 관찰 |
| TC-M24 / P1 | E3 모두 허용, 창 1/8/9개 | 프리뷰 열고 창 내용 변경, 2초 갱신 관찰 | 해당 PID의 창 이미지, 캡처 최대8개, 보호된 창 대체 표시 | FR-14 / PARTIAL: 사용자 미리보기 정상 확인, 1/8/9개·보호된 창 행렬 미실행 |
| TC-M25 / P1 | AX 허용, 이미지 권한 거부, 최소화 창 | 프리뷰 열기, 동명 창·제목 없는 창 포함 | 제목/대체 아이콘·최소화 상태, 창 없음 구분 | FR-14 / NOT RUN: 제목 대체·동명 창 행렬 미실행 |
| TC-M26 / P1 | E3 허용, 다른 화면·동명 창 | 지정 카드 선택, 선택 직전 창 닫기 | 카드의 AX 객체에 맞는 창 선택, 사라졌으면 앱 활성화 | FR-15 / NOT RUN: 권한 복구 완료, 다른 화면·동명 창 선택 행렬 미실행 |
| TC-M27 / P1 | E3 허용 | 앱 빠르게 왕복, 프리뷰 끄기, 화면 분리, 60초 후 재조회 | stale 결과 없음, 취소 작업 재표시 안 함, 캐시 상한, 해제 패널 팝업 없음 | FR-14, FR-15 / NOT RUN |
| TC-M28 / P0 | E1, 테스트 앱 핀 | 가져오기·추가·드롭·중복·순서·해제·앱 위치 이동 | 중복 없음, 모든 화면 순서 동일, bundle ID 재탐색·삭제 가능 | FR-16 / PARTIAL: 최초 가져오기 관찰 |
| TC-M29 / P0 | 기존 설정 백업, 구버전 fixture | 재실행·설정 변경·누락키/경계값 fixture 복원 | 기존 선택 유지, 범위 정규화, 손상 데이터 대응 | FR-17 / PARTIAL: A04/A06, 화면 설정 관찰; 손상 회차 미실행 |
| TC-M30 / P1 | 설치 경로 앱, 별도 테스트 계정 | 로그인 실행 켬/끔, 로그아웃/인, 승인 대기 | 실제 등록 상태 일치, 켬에서 한 번 실행, 끔에서 실행 안 함 | FR-17 / NOT RUN |
| TC-M31 / P0 | E1, 앱 실행 중 | 동일 bundle 앱 두 번째 실행 | 패널·감시 프로세스 중복 없음 | FR-17 / NOT RUN |
| TC-M32 / P0 | E3 | 권한 거부→승인→철회→재실행·업데이트 재등록 | 상태 표시와 사용 가능 기능 일치, 무한 요청·정지 없음 | FR-18 / NOT RUN |
| TC-M33 / P1 | E1/E2, VoiceOver | 라이트/다크, 투명도/동작 줄이기, 키보드·읽기 탐색 | 레이블·실행 상태 읽힘, 이동 효과 축소, 잘림·조작 불가 없음 | NFR-06 / NOT RUN |

## 7. 성능·개인정보

표준 성능 케이스는 아직 전체 PASS가 아니다. v0.3.1의 제한된 실제 측정은 [QA-v0.3.1](QA-v0.3.1.md)에 분리한다. 코드 구조나 타이머 설정만 보고 수치 목표를 통과 처리하지 않는다.

| ID | 절차 | 기대 결과 | 요구 |
|---|---|---|---|
| TC-P01 | 앱20개·2화면, 워밍업1분 후 유휴5분 CPU/RSS 측정 | 평균 CPU≤2%, RSS≤200MiB(주+감시 프로세스) | NFR-02 |
| TC-P02 | Instruments로 포인터 왕복30초, 프리뷰30회 개폐 | 확대 프레임 P95≤16.7ms, 유휴 후 메모리 지속 증가 없음 | NFR-02 |
| TC-P03 | 외부 앱 실행/종료20회와 화면 재연결5회 시간 측정 | 앱 상태 95%≤1초, 화면 회복 목표2초, AX 지연이 애니메이션을 막지 않음 | FR-01, FR-07, NFR-02 |
| TC-P04 | 앱 프로세스 네트워크·파일 쓰기를 관찰하며 프리뷰 사용 | 원격 전송·이미지 저장 없음, 최초 실제 API 검사는 OS 승인 흐름 사용, 거부 후 자동 재요청 없음 | NFR-04 |

## 8. 배포 테스트

v0.3.0의 TC-R01~R04는 아래 실행 기록 기준 PASS이며, TC-R05~R06은 NOT RUN이다. 앱 설치 시험은 별도 appdir를 사용해 사용자의 기존 앱을 덮어쓰지 않는다.

| ID | 절차 | 기대 결과 | 요구 |
|---|---|---|---|
| TC-R01 | `swift test --arch arm64`, `./scripts/package-release.sh`, lipo·codesign·plist 검사 | 테스트 PASS, arm64, macOS26, 번들버전=ZIP버전, 서명 유효 | FR-19, NFR-01, NFR-07 |
| TC-R02 | 로그아웃한 공개 URL로 repo·docs·릴리스 조회, 태그 commit 비교 | 공개 소스·4문서 접근, 태그와 릴리스 소스 일치, 비밀·개인 파일 없음 | FR-19, NFR-08 |
| TC-R03 | Release ZIP 재다운로드, SHA-256 비교, 추출·서명 확인 | published checksum=cask checksum=다운로드 파일 hash | FR-19, NFR-07 |
| TC-R04 | cask style/audit, `brew info`, `brew fetch --cask hungryZoo/tap/everydock` | cask 구문·아키텍처·OS 제약·다운로드 검증 성공 | FR-19 |
| TC-R05 | E5에서 별도 appdir 설치 후 시작·권한 승인; 다음 버전 업그레이드 | 설치·실행 성공, 설정 유지, 필요 권한 재등록 안내 | FR-18, FR-19 |
| TC-R06 | 정상 종료→`brew uninstall --cask everydock`, 재설치 | 앱 제거, 기본 Dock 복원, v0.3.9 이상은 설정 초기화·로그인 등록 해제, 미복원 journal 보존 | FR-09, FR-19, NFR-05 |

### 배포 실행 기록

- 실행일: 2026-09-07. 공개 릴리스 v0.3.0, 소스 commit `cf109a8196ebb7a40cdbd96185aec8f814c6b3b3`.
- TC-R01 **PASS**: 로컬 `swift test --arch arm64` 10개 통과. 패키징 후 ZIP 추출본의 arm64·버전0.3.0·최소OS26.0·codesign strict 검증 통과. [GitHub macOS 26 arm64 CI](https://github.com/hungryZoo/everyDock/actions/runs/34125196383)에서 테스트·패키징·아티팩트 업로드 성공.
- TC-R02 **PASS**: 저장소 visibility PUBLIC, MRD·PRD·SRS·TC를 인증 없는 raw URL로 조회. 태그 v0.3.0이 위 commit을 참조함을 확인. 공개 대상 31개 파일을 명시적으로 stage하고 개인 경로·토큰·개인 키 패턴과 제외 목록 점검.
- TC-R03 **PASS**: 공개 [릴리스 ZIP](https://github.com/hungryZoo/everyDock/releases/tag/v0.3.0) 재다운로드 후 SHA256SUMS·cask·GitHub asset digest 일치. SHA-256: `cff503aada7daed5f07f253d369f6725abfcfcd33bb83422d0b83b8bb9d71e84`. 다운로드한 번들 서명·arm64 재검증.
- TC-R04 **PASS**: Homebrew 6.0.21에서 `brew style`, 일반 `brew audit --cask`, `brew info --cask`, `brew fetch --cask hungryZoo/tap/everydock` 모두 exit 0. 공개 tap commit `993dc78`. info에서 arm64와 macOS>=26 확인. online/strict 공증 검사는 이 PASS 범위에 포함하지 않음.
- TC-R05~R06 **NOT RUN**: 실제 cask 설치·첫 실행 승인·다음 버전 업그레이드·제거/재설치는 수행하지 않음. 실행 중인 개발 앱과 기존 설치 경로를 덮어쓰지 않았음.
- 서명 검증은 ad-hoc 번들의 무결성 검사이며 Apple 공증 통과를 의미하지 않음. 바이너리는 GitHub prerelease로 공개됨.

## 9. 결함 기록과 종료 조건

결함은 TC ID, 기대/실제, 재현 횟수, OS·화면·권한·commit, 개인정보를 제거한 근거를 포함한다. 파일 손실·설정 미복원·실행 불가·중복 패널은 P0로 분류한다. 애니메이션 품질·폴더 스택·미리보기 문제는 사용자 작업 차단 정도에 따라 P1/P2로 분류한다.

공개 베타는 TC-R01~R04와 명시한 기본 관찰을 근거로 배포하며 미검증 경로를 릴리스에 표시한다. 안정 버전은 P0 수동·파일 보존·권한 허용 경로·성능·설치 업그레이드/제거·공증 검증이 모두 끝나야 한다. 수동 TC가 남아 있는 현재 결과를 ‘전체 테스트 통과’라고 표현하지 않는다.

## 10. v0.3.1 회귀 절차

- TC-M09/M10/M23/M24/M32: 시스템 설정에서 켜짐과 실제 API 성공을 각각 확인한다. 재빌드 전 승인 항목만 남은 경우 실제 거부 안내·현재 앱 위치·명시적 재검사를 확인하고, 최종 번들 재등록 후 최소화/복원/썸네일/카드 선택을 반복한다. 사용자의 OS 승인 전 전체 PASS로 처리하지 않는다.
- TC-M09: AXFocusedWindow가 없는 앱에서 AXMainWindow/첫 일반 창 선택을 검사한다. 최소화 미지원·응답 지연을 권한 부족으로 표시하면 실패다.
- TC-M07/P02: 60/120Hz 화면별로 왕복·정지·이탈 후 유휴를 측정한다. 선택적으로 `EVERYDOCK_TRACE_FRAMES=1` 실행 로그에서 callback 간격과 렌더 함수 소요시간을 수집한다. 이 값은 화면에 실제 표시된 프레임레이트나 WindowServer/GPU 시간을 증명하지 않는다. Instruments의 실제 프레임 측정은 별도다.
- TC-M08/P03: 앱 실행 알림 직후 상태와 5초 보완 조회를 구분한다. 재확인 타이머까지 기다려야 아이콘이 반영되면 실패다.
- TC-M19: 휴지통 변화 중 확대를 계속해 디렉터리 조회가 UI를 막지 않는지 확인한다.

실행 결과: [QA-v0.3.1](QA-v0.3.1.md). v0.3.0 배포 실행 기록은 과거 버전의 근거로 보존한다.

v0.3.1 최종 회귀: NSButton의 셀 레이아웃 제거 후 17개 자동 테스트 PASS. 사용자는 미리보기·최소화 정상 동작을 확인했고, 추가 렌더러 교체 후 확대가 부드럽다고 확인했다. 실제 표시 프레임·모든 창 유형·전체 수동 행렬까지 PASS로 확장하지 않는다.

v0.3.1의 TC-R01~R04는 2026-09-08 PASS. 최종 소스 CI·공개 ZIP 재다운로드 SHA-256·Homebrew style/audit/info/fetch 근거는 [최종 QA의 공개 배포 검증](QA-v0.3.1.md#공개-배포-검증--2026-09-08)을 따른다. TC-R05~R06은 NOT RUN을 유지한다.

## 11. v0.3.2 창 관리 회귀

| ID | 절차 | 기대 결과 | 결과 |
|---|---|---|---|
| TC-M34 | 각 Dock edge에서 아이콘 우클릭·Control-클릭·ShowMenu, 메뉴 탐색·Escape | 아이콘 안쪽 메뉴, 확대 정지, 메뉴 뒤 호버 정상 | 실기기 범위 QA-v0.3.2 참조 |
| TC-M35 | 창 1개, 동명 3개, 제목 변경, 최소화·닫기 후 프리뷰 갱신 | 실제 일반 창당 카드 1개, 유령 SC 창 미추가 | 실기기 범위 QA-v0.3.2 참조 |
| TC-M36 | Finder 일반 창을 모두 닫은 상태에서 Dock 클릭 | Finder 다시 열기, 바탕화면 최소화 시도 없음 | 실기기 범위 QA-v0.3.2 참조 |
| TC-M37 | 한글/영문 앱 이름 호버·라이트/다크·1×/2× | 상하 여백 균등, 잘림 없음 | A22 PASS; 전체 시각 행렬 NOT RUN |
| TC-M38 | 테스트 창 3개에서 카드 ×, 모든 창 닫기; Finder에서도 반복 | 개별 대상만 닫힘, 전체 닫기는 앱 종료 안 함, 개수 갱신 | 실기기 범위 QA-v0.3.2 참조 |
| TC-M39 | 테스트 문서 수정 후 모든 창 닫기, 저장 확인에서 취소; 닫는 중 새 창 생성 | 확인 우회 없음, 이후 창 및 새 창 보존 | A23~25 및 fixture 저장 확인·취소 PASS; 실제 문서 행렬 NOT RUN |
| TC-M40 | 메뉴로 미리보기 열기→외부 클릭→같은 앱 호버, × 후 다른 앱 호버 | 재개방 정상, 닫기/선택 혼동 없음, 이전 작업 재표시 없음 | 실기기 범위 QA-v0.3.2 참조 |

자동 테스트는 매칭/배치/닫기 순서의 회귀를 검증하며 실제 AX 앱 호환성과 저장 대화상자 전체를 대신하지 않는다. 사용자 실제 문서를 닫는 시험은 수행하지 않는다.

v0.3.2 배포 회귀: TC-R01~R04 PASS, TC-R05는 실제 Homebrew 0.3.1→0.3.2 업그레이드·재실행·기존 설정·실제 AX/SCK 재검사까지 PARTIAL PASS, 신규 사용자 설치는 미실행이다. TC-R06은 NOT RUN. [최종 실행·배포 근거](QA-v0.3.2.md)를 따른다.

## 12. v0.3.3 회귀

| ID | 절차 | 기대 결과 | 상태 |
|---|---|---|---|
| TC-M41 | fixture 3개→2개→1개, 마지막 닫기·재개방 | 1개는 여분 열 없음, 폭과 높이 갱신, 닫기 버튼 유지 | QA-v0.3.3 참조 |
| TC-M42 | 바탕화면·다운로드 반복 개폐, 접근 허용/거부·빈 폴더·파일 클릭 | 각 폴더 컨텐츠·올바른 안내·중복 읽기 없음, 다른 앱 숨김 없음 | QA-v0.3.3 참조 |
| TC-M43 | Apps 클릭·Spotlight 앱 검색·닫기·다시 열기 | 시스템 Spotlight 앱 화면, 불필요한 AX 최소화 없음 | QA-v0.3.3 참조 |
| TC-M44 | fixture 타이틀 더블클릭 확대/복원 3회, 3개 edge·2개 화면 | 정지 Dock과 겹치지 않음, 일반 크기로 복원, 보정 루프 없음 | QA-v0.3.3 참조 |
| TC-M45 | 창 전체 화면·최소화·일반 resize·화면 숨김·앱 종료·AX 거부 | 제외 상태 유지, 관찰 정리, 지원하지 않는 앱 무한 재시도 없음 | QA-v0.3.3 참조 |

FR-10의 이전 바탕화면 숨김/복원 결과는 과거 버전 QA에 보존하며 새 파일 팝업 PASS로 재사용하지 않는다.

## 13. 2026-09-10 보완 회귀

| ID | 테스트 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-A32 | `correctedZoomRestoresOriginalForThreeCycles` / WindowZoomStateTests | 보정 후 원래 좌표·크기로 3회 복원, 자체 resize 반복 없음 | FR-23 |
| TC-A33 | `nativeRestoreAndManualResizeUpdateTheSavedFrame` / WindowZoomStateTests | 앱 자체 복원 허용, 수동 이동 뒤 새 기준 사용 | FR-23 |
| TC-A34 | `observerReattachmentPreservesRestoreAndUnknownHistoryIsNotInvented` / WindowZoomStateTests | 앱 전환 후 유지, 사전 이력 없으면 복원 크기 추측 안 함 | FR-23 |
| TC-A35 | `sideZoomRestoresPositionAndSizeWithoutMovingToDisconnectedDisplay` / WindowZoomStateTests | 왼쪽 Dock 보정·복원, 다른 화면의 과거 위치로 이동 안 함 | FR-23 |
| TC-A36 | `newestModifiedFilesSortFirstWithStableNameTies` / WindowZoomStateTests | 수정일 최신순, 같은 날짜는 자연스러운 파일명 순 | FR-10/FR-11/FR-25 |
| TC-M46 | 카카오톡 우클릭·Control-클릭·접근성 메뉴 요청, 기본 Dock 항목 없는 앱 | 현재 아이콘 옆 앱 메뉴, 없는 항목은 같은 메뉴에서 안내; 설정 창 열지 않음 | FR-24 |
| TC-M47 | 바탕화면·다운로드의 이미지/PDF/미지원 파일, 수정 후 재개방·빠른 개폐 | 비율 유지 썸네일·아이콘 fallback, 최대 3개 병렬, 취소 결과 무시, 최신순 | FR-25 |

TC-M44는 창의 확대/복원 3회와 경계의 추가 4pt 제거를 함께 확인한다. 창이 이미 확대된 채 everyDock을 시작한 경우 원래 크기 복원은 제외한다. 자동 좌표 테스트로 실제 앱의 AX 동작을 PASS 처리하지 않는다.

| TC-A37 | `restoreAnimationHasExactEndpointsAndMonotonicGeometry` / WindowZoomStateTests | 시작·종료 좌표 정확, 중간 크기·위치가 역행하지 않음 | FR-23 |

TC-M44 추가: 복원 전환 중 점프·멈춤, 동작 줄이기, 앱 전환 취소를 확인한다. TC-A37은 실제 프레임 간격이나 AX 응답 속도 PASS를 의미하지 않는다.

| TC-A38 (폐기) | v0.3.3 같은 화면 제한 테스트 | v0.3.4에서 제한 제거. ID 재사용하지 않음 | FR-24 |

TC-M46 추가: v0.3.3의 다른 화면 요청 차단은 폐기했다. 아래 TC-M48에서 현재 화면 표시와 실제 명령 전달을 별도로 검증한다.

## 14. v0.3.4 앱 고유 메뉴 회귀

| ID | 테스트 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-A39 | `nativeMenuSelectionRejectsChangedCommands` / NativeMenuIdentityTests | 인덱스·제목·식별자·하위 메뉴 여부 변경 시 일치 거부 | FR-24 |
| TC-M48 | WindowFixture의 앱 메뉴를 각 모니터에서 열고 Mark Test Window 선택 | 로컬 아이콘 옆 표시, 실제 fixture 제목 변경, 설정 창 열리지 않음 | FR-21/FR-24 |
| TC-M49 | fixture 비활성 항목·하위 메뉴·이전 메뉴·Escape·외부 클릭 | 비활성 명령 실행 안 함, 하위 명령 전달, 닫기 후 다른 입력 정상 | FR-24 |
| TC-M50 | 메뉴를 읽은 뒤 대상 앱 종료·내용 변경·AX 거부·시간 초과 | 잘못된 명령 실행 안 함, 오류 구분, 로컬 일반 메뉴 사용 가능 | FR-24 |

실기기 수행 범위와 미검증 조합은 [QA-v0.3.4](QA-v0.3.4.md)를 따른다.

## 15. v0.3.5 통합 메뉴 회귀

| ID | 테스트 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-M51 | 실행 중인 fixture·카카오톡 우클릭 한 번 | 앱 제공 항목과 everyDock 열기·모든 창 닫기·고정 항목 함께 표시, 별도 진입 항목 없음 | FR-21/FR-24 |
| TC-M52 | 통합 메뉴 명령·하위 메뉴·기본 기능, 실행 안 한 앱·조회 실패·Control-클릭·접근성 요청 | 기존 실행 경로 유지, 비활성 유지, 실패해도 기본 기능 사용 가능, 모든 진입 동작 동일 | FR-24 |

실제 수행 범위는 [QA-v0.3.5](QA-v0.3.5.md)를 따른다.

## 16. v0.3.6 구분선·폴더 반복 열기 회귀

| ID | 테스트 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-A40 | `separatorsMigratePersistAndMoveAlongsidePins` | 기존 설정 마이그레이션, UUID·순서 저장, 동일 구분선 중복 제거 | FR-26 |
| TC-A41 | `separatorGeometryUsesFixedWidthAndTwoSectionBoundaries` | 구분선 폭 고정, 실행·폴더 경계 포함 길이 | FR-26 |
| TC-A43 | `quickLookThumbnailSurvivesTenReopens` (명시적 Quick Look 통합 실행) | 실제 PNG 내용 썸네일 생성·10회 재열기 캐시 유지 | FR-25 |
| TC-A42 | `latePopoverCloseCannotCancelReopenedFolder` | 이전 종료/등장 무시, 열린 동안 중복 조회 1개, 재조회 중 기존 그리드 유지 | FR-25 |
| TC-M53 | 고정 앱 사이 우클릭 삽입·앱 앞/뒤 추가·구분선 삭제·설정 순서 변경·재실행 | 위치·설정 일치, 순서·UUID 유지 | FR-26 |
| TC-M54 | 고정/실행/폴더 영역, 좌우 Dock·좁은 화면·화면 2개, 앱 실행·종료 | 영역 순서 유지, 자동 경계 갱신, 선 확대·미리보기 없음 | FR-26 |
| TC-M55 | 바탕화면/다운로드 10회 개폐·빠른 교차·변경 파일·느린/실패 QL | 기존 이미지 유지, 이전 닫힘 영향 없음, 최대 3개와 8초 슬롯 해제, 최신순 유지 | FR-25 |

실제 결과는 [QA-v0.3.6](QA-v0.3.6.md)에 기록하며 자동 테스트를 전체 실기기 행렬 PASS로 대체하지 않는다.

## 17. v0.3.7 Command-드래그 회귀

| ID | 테스트 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-A44 | `commandDragInsertionPreservesOrderAndAdjacentSlots` | 앞/뒤 이동, 구분선 UUID·순서 저장, 인접 슬롯 no-op | FR-27 |
| TC-A45 | `commandDragPinsRunningAppWithoutDuplicates` | 미고정 앱 삽입, 빈 목록·경계 보정·bundle 중복 방지 | FR-27 |
| TC-M56 | Command로 잡을 때 축소, 앱·구분선 앞/뒤 이동, 설정 확인·재시작 | 삽입선 위치에 저장, 모든 모니터·설정·재실행 순서 일치 | FR-27 |
| TC-M57 | Command-클릭, 4pt 미만 이동, Escape, Dock 밖·폴더 영역 드롭, 일반 클릭·Control-클릭 | 취소 시 실행·최소화·고정 해제 없음, 기존 클릭·메뉴 정상 | FR-27 |
| TC-M58 | 미고정 앱→고정 영역, 고정 앱→실행 영역 해제, 구분선 해제 거부, 다른 모니터·좌우 Dock·오버플로·드래그 중 대상 앱 종료 | 중복 없는 고정, 방향 일치, 취소 후 입력 복구, 사라진 앱 거부 | FR-27 |

자동 테스트는 실제 NSDraggingSession과 프레임 성능 검증을 대신하지 않는다. 수행 결과는 [QA-v0.3.7](QA-v0.3.7.md)를 따른다.

## 18. v0.3.8 초기 안내·메뉴 막대 회귀

| ID | 테스트 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-A46 | `initialSetupAndHiddenMenuLaunchesHaveReachableWindows` | 첫 실행 안내, 숨김 수동 실행 설정, 기존 로그인 실행 백그라운드 | FR-28/FR-29 |
| TC-A47 | `menuIconVisibilityMigratesAndPersistsWithoutChangingPins` | 이전 설정 기본 표시, 숨김 저장·복원, 고정 순서 보존 | FR-29 |
| TC-M59 | 신규 설치 첫 실행·안내 창 닫기·재실행·나중에 설정·기존 설치 업그레이드 | 창 하나, 완료 전 재표시, 완료 후에도 권한 설정이 필요하면 안내, 기존 설정 유지 | FR-28 |
| TC-M60 | 안내의 권한 요청·상태 재확인·현재 앱 위치·거부·API 오류 | 올바른 시스템 페이지와 앱, 실제 상태 분류, 자동 승인 없음 | FR-28 |
| TC-M61 | 자동 실행 선택/해제 후 시작, 등록 실패·승인 대기·나중에 설정·안내 재열기 | 선택대로 등록, 실패/승인 필요 표시, 나중에는 변경 안 함, 기존 선택 유지 | FR-28 |
| TC-M62 | 아이콘 숨김/표시, 설정 닫고 Apps에서 재실행, 종료 후 수동 실행, 로그아웃·로그인 | 즉시 숨김·복구, 설정 재진입, 설정 저장, 권한 정상인 자동 로그인 실행은 창 없음 | FR-29 |

실제 권한 DB·로그인 상태를 자동 테스트에서 변경하지 않는다. 결과는 [QA-v0.3.8](QA-v0.3.8.md)에 기록한다.

## 19. Homebrew 설정 초기화 제거

| ID | 절차 | 기대 결과 | 요구사항 |
|---|---|---|---|
| TC-R07 | cask의 zap 경로를 임시 fixture로 바꿔 일반 uninstall 후 --zap --force, 임시 UserDefaults 첫 실행 키 조회 | 일반 제거는 보존, zap은 세 경로 제거, journal 보존, 첫 실행 키 캐시도 사라짐 | FR-30 |

기존 TC-A46은 첫 실행 기록이 없는 경우 안내 창 선택을 검증한다. TC-R07은 실제 사용자의 권한 초기화·로그인 해제를 수행하거나 그 결과를 보장하지 않는다. cask만 변경하며 공개된 v0.3.8 앱·태그·릴리스 자산은 변경하지 않는다. 실제 수행 범위는 [QA-v0.3.8](QA-v0.3.8.md)를 따른다.

## 20. v0.3.9 삭제 초기화·매 실행 권한 확인 (이전 TC-R07의 일반 삭제 보존 조건 대체)

| ID | 검증 | 기대 결과 | 연결 |
|---|---|---|---|
| TC-A48 | uninstallClearsEntirePreferenceDomainAndFirstRunHistory | 임시 도메인의 옵션·최초 실행·창 상태 제거, 새 UserDefaults 조회도 없음 | FR-30 |
| TC-A49 | missingPermissionsAlwaysReopenGuidanceEvenAfterOnboarding | 안내 완료 기록·로그인 시작·아이콘 숨김과 무관하게 권한 안내 우선 | FR-28/29 |
| TC-R08 | 실제 Homebrew에 임시 artifact cask 설치→업그레이드→재설치→일반 제거 | 업그레이드 보존, 재설치/삭제 초기화 도우미 호출, 실제 사용자 데이터 무변경 | FR-30 |
| TC-M63 | 권한 정상/거부/오류/3초 지연, 프로세스 시작·앱 재열기·나중에 설정 | 실제 상태 검사, 필요한 안내 하나, 같은 검사로 닫은 창 재표시 없음 | FR-28/29 |
| TC-M64 | 배포 앱 일반 제거→설치 | 실행 앱 종료, 기본 Dock 복원, 로그인 해제, 옵션·첫 실행 초기화; OS 승인은 별도 | FR-30 |

자동 fixture는 실제 사용자의 로그인 등록과 권한을 바꾸지 않는다. 수행 범위 및 남은 수동 검증은 [QA-v0.3.9](QA-v0.3.9.md)에 기록한다.

## 21. v0.3.10 권한 요청 회귀

| ID | 검증 | 기대 결과 | 연결 |
|---|---|---|---|
| TC-A50 | backgroundCaptureNeverRequestsMissingPermission | 미허용 자동 조회 10회 API 0회, 명시 요청 1회, 거부 후 자동 재시도 0회 | FR-14/28 |
| TC-A51 | denialAndRevocationStopBackgroundCaptureEvenWithStaleHints | 권한 철회 차단, 실제 거부 후 긍정 힌트에도 자동 재요청 없음, 버튼 재시도만 허용 | FR-14/28 |
| TC-M65 | 신규 실행·앱 재열기·호버 반복·화면 권한 버튼·거부·재시도 | 버튼 전 시스템 요청 없음, 초기 안내는 권한 두 종류와 자동 실행, 하단 중복 영역 없음 | FR-14/28 |

TC-M60의 초기 안내 하단 버튼 조건은 TC-M65가 대체한다. TC-M63의 자동 검사는 화면 캡처 API를 호출하지 않는 상태 검사로 변경한다. 실제 수행 결과는 [QA-v0.3.10](QA-v0.3.10.md)에 기록한다.
