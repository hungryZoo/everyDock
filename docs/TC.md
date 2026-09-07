# TC — Test Cases

| 항목 | 내용 |
|---|---|
| 문서 버전·기준일 | 1.0 / 2026-09-07 |
| 대상 | everyDock v0.3.0, Apple Silicon, macOS 26+ |
| 요구사항 | [SRS](SRS.md), [추적표](README.md) |
| 기존 실행 근거 | [QA.md](../QA.md), Swift Testing 실행 결과 |

## 1. 실행 원칙과 환경

자동 테스트 10개, 기능 수동 케이스 33개, 성능·개인정보 케이스 4개, 배포 케이스 6개를 관리한다. PASS는 해당 절차와 환경에서만 유효하다. PARTIAL/BLOCKED/NOT RUN은 전체 통과로 집계하지 않는다.

| 환경 | 구성 |
|---|---|
| E1 기본 | Apple Silicon, macOS 26+, 화면 2대, release 앱, 앱 5~20개 |
| E2 화면 | 화면 3대, 음수 X/Y, 혼합 Retina 배율, 아래·왼쪽·오른쪽 |
| E3 권한 | AX/화면 기록 각각 허용·거부·철회·업데이트 후 재등록 |
| E4 파일 | 별도 테스트 사용자, Desktop/Downloads/Trash의 테스트 파일만 |
| E5 배포 | 새 checkout, Xcode 26+, Homebrew, 기존 everyDock cask 없는 상태 |

실행 기록에는 OS 버전·칩·화면 구성·앱 버전·commit·권한·결과·실패 재현을 남긴다. 창 제목, 계정 경로, 실제 문서 내용은 공개 스크린샷과 로그에서 제거한다. 파일 테스트는 `everyDock-TC-날짜-UUID` 이름의 폴더와 더미 파일을 사용한다. **비우기는 휴지통에 테스트 파일만 있는 별도 사용자에서 수행한다.** 실제 사용자 휴지통 전체를 테스트용으로 삭제하지 않는다.

## 2. 자동 테스트

실행: `swift test --arch arm64`. 현재 모두 PASS(2026-09-07). 이름은 실제 Swift Testing 함수와 일치한다.

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
| TC-M07 / P0 | E1 | 아이콘 가로질러 이동·정지·이탈·클릭, 확대 상단 빈 공간 클릭 | 이웃 확대·밀림, 진동·잔상 없음, 빈 공간은 아래 앱 클릭 | FR-04 / PARTIAL: 확대·이웃 이동 관찰, 전체 입력 행렬 미실행 |
| TC-M08 / P0 | 미실행 앱 하나 | 실행 클릭 후 launch 상태, 외부 실행/종료, 활성 앱 전환 관찰 | 즉시 요청 반응, 상태 반영, 포커스만으로 순서 안 바뀜 | FR-05, FR-07 / PARTIAL: v0.2 Music 요청·반영 기록, 외부 실행·종료 행렬 추가 필요 |
| TC-M09 / P0 | AX 허용, genie, 문서 창 | 앱 활성화→Dock 재클릭, 10회 반복 | 실제 창 최소화, 시스템 애니메이션. 앱 숨김과 구분 | FR-06 / BLOCKED: 현재 앱 AX 미허용 |
| TC-M10 / P0 | AX 허용, 최소화 창 2개 | Dock 클릭, 이후 프리뷰에서 개별 창 선택 | 앱 클릭은 최소화 창 복원, 개별 카드는 대상 창 복원 | FR-06, FR-15 / BLOCKED: AX 미허용 |
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
| TC-M16 / P1 | 앱 여러 개 표시, 일부는 미리 숨김 | 바탕화면 클릭→창 다시 보기→정상 종료 회차 | 표시하던 앱과 이전 활성 앱 복원. 원래 숨긴 앱은 유지 | FR-10 / PARTIAL: 모든 표시 앱·이전 활성 앱 복원 PASS, 사전 숨김·종료 회차 미실행 |
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
| TC-M24 / P1 | E3 모두 허용, 창 1/8/9개 | 프리뷰 열고 창 내용 변경, 2초 갱신 관찰 | 해당 PID의 창 이미지, 캡처 최대8개, 보호된 창 대체 표시 | FR-14 / BLOCKED: 화면 기록 미허용 |
| TC-M25 / P1 | AX 허용, 이미지 권한 거부, 최소화 창 | 프리뷰 열기, 동명 창·제목 없는 창 포함 | 제목/대체 아이콘·최소화 상태, 창 없음 구분 | FR-14 / BLOCKED: AX 미허용 |
| TC-M26 / P1 | E3 허용, 다른 화면·동명 창 | 지정 카드 선택, 선택 직전 창 닫기 | 제목+geometry에 맞는 창 선택, 사라졌으면 앱 활성화 | FR-15 / BLOCKED: 권한 미허용 |
| TC-M27 / P1 | E3 허용 | 앱 빠르게 왕복, 프리뷰 끄기, 화면 분리, 60초 후 재조회 | stale 결과 없음, 취소 작업 재표시 안 함, 캐시 상한, 해제 패널 팝업 없음 | FR-14, FR-15 / NOT RUN |
| TC-M28 / P0 | E1, 테스트 앱 핀 | 가져오기·추가·드롭·중복·순서·해제·앱 위치 이동 | 중복 없음, 모든 화면 순서 동일, bundle ID 재탐색·삭제 가능 | FR-16 / PARTIAL: 최초 가져오기 관찰 |
| TC-M29 / P0 | 기존 설정 백업, 구버전 fixture | 재실행·설정 변경·누락키/경계값 fixture 복원 | 기존 선택 유지, 범위 정규화, 손상 데이터 대응 | FR-17 / PARTIAL: A04/A06, 화면 설정 관찰; 손상 회차 미실행 |
| TC-M30 / P1 | 설치 경로 앱, 별도 테스트 계정 | 로그인 실행 켬/끔, 로그아웃/인, 승인 대기 | 실제 등록 상태 일치, 켬에서 한 번 실행, 끔에서 실행 안 함 | FR-17 / NOT RUN |
| TC-M31 / P0 | E1, 앱 실행 중 | 동일 bundle 앱 두 번째 실행 | 패널·감시 프로세스 중복 없음 | FR-17 / NOT RUN |
| TC-M32 / P0 | E3 | 권한 거부→승인→철회→재실행·업데이트 재등록 | 상태 표시와 사용 가능 기능 일치, 무한 요청·정지 없음 | FR-18 / NOT RUN |
| TC-M33 / P1 | E1/E2, VoiceOver | 라이트/다크, 투명도/동작 줄이기, 키보드·읽기 탐색 | 레이블·실행 상태 읽힘, 이동 효과 축소, 잘림·조작 불가 없음 | NFR-06 / NOT RUN |

## 7. 성능·개인정보

현재 전부 NOT RUN. 코드 구조나 타이머 설정만 보고 수치 목표를 통과 처리하지 않는다.

| ID | 절차 | 기대 결과 | 요구 |
|---|---|---|---|
| TC-P01 | 앱20개·2화면, 워밍업1분 후 유휴5분 CPU/RSS 측정 | 평균 CPU≤2%, RSS≤200MiB(주+감시 프로세스) | NFR-02 |
| TC-P02 | Instruments로 포인터 왕복30초, 프리뷰30회 개폐 | 확대 프레임 P95≤16.7ms, 유휴 후 메모리 지속 증가 없음 | NFR-02 |
| TC-P03 | 외부 앱 실행/종료20회와 화면 재연결5회 시간 측정 | 앱 상태 95%≤1초, 화면 회복 목표2초, AX 지연이 애니메이션을 막지 않음 | FR-01, FR-07, NFR-02 |
| TC-P04 | 앱 프로세스 네트워크·파일 쓰기를 관찰하며 프리뷰 사용 | 원격 전송·이미지 저장 없음, 승인 전 캡처 없음 | NFR-04 |

## 8. 배포 테스트

TC-R01~R04는 아래 실행 기록 기준 PASS이며, TC-R05~R06은 NOT RUN이다. 앱 설치 시험은 별도 appdir를 사용해 사용자의 기존 앱을 덮어쓰지 않는다.

| ID | 절차 | 기대 결과 | 요구 |
|---|---|---|---|
| TC-R01 | `swift test --arch arm64`, `./scripts/package-release.sh`, lipo·codesign·plist 검사 | 테스트 PASS, arm64, macOS26, 번들버전=ZIP버전, 서명 유효 | FR-19, NFR-01, NFR-07 |
| TC-R02 | 로그아웃한 공개 URL로 repo·docs·릴리스 조회, 태그 commit 비교 | 공개 소스·4문서 접근, 태그와 릴리스 소스 일치, 비밀·개인 파일 없음 | FR-19, NFR-08 |
| TC-R03 | Release ZIP 재다운로드, SHA-256 비교, 추출·서명 확인 | published checksum=cask checksum=다운로드 파일 hash | FR-19, NFR-07 |
| TC-R04 | cask style/audit, `brew info`, `brew fetch --cask hungryZoo/tap/everydock` | cask 구문·아키텍처·OS 제약·다운로드 검증 성공 | FR-19 |
| TC-R05 | E5에서 별도 appdir 설치 후 시작·권한 승인; 다음 버전 업그레이드 | 설치·실행 성공, 설정 유지, 필요 권한 재등록 안내 | FR-18, FR-19 |
| TC-R06 | 정상 종료→`brew uninstall --cask everydock`, 재설치 | 앱 제거, 기본 Dock 복원, 설정/journal 임의 삭제 없음 | FR-09, FR-19, NFR-05 |

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
