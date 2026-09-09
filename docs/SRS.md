# SRS — Software Requirements Specification

| 항목 | 내용 |
|---|---|
| 문서 버전·기준일 | 1.3 / 2026-09-09 |
| 제품 기준 | everyDock v0.3.3 |
| 상위 문서 | [PRD](PRD.md) |
| 검증 명세 | [TC](TC.md) |

‘해야 한다’는 요구사항이다. 구현과 실제 검증 완료는 별개이며 상태는 TC를 따른다. 수치가 ‘목표’인 경우 현재 성능을 주장하지 않는다.

## 1. 시스템 경계와 의존성

- 지원 실행 환경: arm64 Apple Silicon, macOS 26.0 이상. Intel 코드는 컴파일 단계에서 차단한다.
- 개발 환경: Swift 6.2 이상, Xcode 26 이상과 macOS 26 SDK. 외부 Swift 패키지 없음.
- 앱 식별자: `app.everydock.mac`. 메뉴 막대의 accessory 앱이며 일반 앱 Dock 타일을 만들지 않는다.
- UI: AppKit `NSPanel`, `NSGlassEffectView`, SwiftUI 설정·팝업.
- OS 연동: `NSWorkspace`, `NSScreen`, Accessibility API, ScreenCaptureKit, `SMAppService`.
- 기본 Dock: `com.apple.dock` 환경설정 및 Dock 재시작. 해당 저장 형식은 공개 호환성 계약이 아니다.
- 네트워크: 실행 앱은 서버·계정·분석 SDK를 사용하지 않는다. GitHub/Homebrew 다운로드는 배포 단계다.
- 시스템 보안·권한을 자동 승인하거나 Gatekeeper/SIP를 해제하지 않는다.

## 2. 구성 요소

| 구성 | 책임 | 주요 소스 |
|---|---|---|
| AppDelegate | 앱 수명, 중복 실행 차단, 메뉴 막대·설정 창 | `EveryDockApp.swift` |
| AppModel | 설정 저장, 앱 목록, 실행 요청·상태, 권한 상태 | `AppModel.swift` |
| DockCoordinator | 화면 UUID별 패널 생성·배치·종료, 포인터 좌표 변환 | `DockPanel.swift` |
| AppPermissions | 실제 AX/SCK 결과 기반 3상태, 재검사·진단 | `AppPermissions.swift`, `OperationFailure.swift` |
| ApplicationSnapshot | 앱 속성 백그라운드 조회·이벤트 병합 | `ApplicationSnapshot.swift` |
| DockSurface | 아이콘·점·구분선·확대·바운스·히트 테스트 | `DockSurface.swift` |
| NativeDockStyle | 시스템 아이콘/확대 크기 읽기 | `NativeDockStyle.swift` |
| WindowActions | 백그라운드 AX 최소화·복원·창 목록·전면 표시·개별/일괄 닫기 | `WindowActions.swift` |
| NativeDockManager | 복원 기록·파일 잠금·Dock 설정·감시 자식 프로세스 | `NativeDockManager.swift` |
| DockUtilities | 바탕화면, 폴더 목록, 복사·휴지통, 확인 대화상자 | `DockUtilities.swift` |
| WindowPreview | 창 캡처·캐시·호버/메뉴 팝업·선택·닫기 | `WindowPreview.swift` |
| DockCore | 설정, 치수·모션, 복원 값 모델 | `Sources/DockCore` |

모든 UI 변경은 MainActor에서 실행한다. AX와 디렉터리 읽기는 분리된 작업으로 수행한다. `NSRunningApplication` KVO 대상 객체는 강하게 보관하고, 객체를 해제하기 전에 관찰을 무효화해야 한다.

## 3. 기능 요구사항

### FR-01 화면 패널 관리 — P-01 / P0

선택된 `NSScreen`마다 안정적인 디스플레이 식별자를 키로 패널을 하나만 유지해야 한다. 화면 변경·Spaces 변경·시스템 및 화면 깨어남을 관찰하고, 연결 해제된 패널과 미리보기·타이머를 정리한다. 음수 원점과 포인트 좌표를 지원해야 한다. 5초 주기(허용 오차 1초)의 geometry 확인은 이벤트 누락을 보완한다. 화면 배율로 픽셀 정렬한 요청 frame을 기억하고, 동일 요청은 WindowServer의 반올림 결과와 무관하게 다시 적용하지 않는다.

### FR-02 표시·위치 제어 — P-01 / P0

아래·왼쪽·오른쪽과 화면별 표시, 전체 일시 숨기기를 지원해야 한다. 모든 화면을 해제해도 메뉴 막대의 설정으로 복구할 수 있어야 한다. 전체 화면 표시 옵션은 창 collection behavior에 반영하되 OS 보안 공간 표시를 보장하지 않는다. 기본 Dock 관리 중이 아니면 `visibleFrame`을 기준으로 배치한다.

### FR-03 공통 치수와 시스템 크기 — P-02 / P0

크기 연동 시 native `tilesize`를 16~96pt, `largesize`를 기본 크기 이상~128pt 범위에서 읽는다. magnification 설정이 꺼져 있으면 배율 1, 켜져 있으면 큰 크기/기본 크기를 적용한다. 읽기 실패 시 기본값을 사용한다.

| 항목 | v0.3 구현 치수 |
|---|---|
| 아이콘 간격 | 2pt |
| 바깥 축 방향 패딩 | 7pt |
| 아이콘 기준선 | 8pt |
| 상단 기본 여백 | 4pt |
| 유틸리티 앞 구분 공간 | 12pt |
| 기본 바 두께 | 아이콘 크기 + 12pt |
| 연동 모드 화면 가장자리 간격 | 3pt |

길이는 `(앱 수 + 3) × (아이콘 크기 + 2) - 2 + 14 + 12`다. 이는 everyDock의 구현 기준으로, Apple 내부 치수를 측정한 공식 값이 아니다. 아이콘은 셀 없는 NSControl의 bounds에 맞춘 CALayer에 표시한다. NSButtonCell의 크기별 레이아웃을 실행하지 않는다. 드래그 후 바깥에서 놓으면 클릭 취소, 안으로 돌아와 놓으면 실행하며 Space/Return 및 접근성 Press를 지원한다. 누르는 동안 패널의 마우스 입력을 유지한다. NSImage가 변경될 때만 CGImage를 만들며 확대 중 재래스터화하지 않는다. 표시 점·구분선도 재사용 레이어다. 좁은 화면에서는 크기를 줄이고 목록 스크롤을 제공한다.

### FR-04 모션과 입력 — P-02 / P0

포인터 거리에 따른 연속 cosine 감쇠로 중심과 이웃 아이콘을 확대해야 한다. NSView에 연결한 CADisplayLink를 변화 중에만 실행하고 안정되면 해제한다. 화면 최대 주사율(60/120Hz 등)을 요청하되 실제 전달은 OS가 결정한다. 보간은 `1-exp(-20×경과초)`로 계산하여 주사율·일시 지연에 따라 동작 속도가 달라지지 않아야 한다. 아이콘·유리 배경의 geometry 변경은 암묵적 레이어 애니메이션을 비활성화한 하나의 트랜잭션에서 처리한다. 실행 바운스와 클릭 반응을 제공하고, 동작 줄이기 시 이동 효과를 줄인다. 포인터 진단 환경값은 시작 시 한 번만 읽고, 마우스 통과 설정은 값이 바뀔 때만 WindowServer에 전달한다. 이벤트 좌표와 실제 포인터 좌표를 올바르게 변환하고 투명 애니메이션 공간의 클릭은 아래 앱으로 통과시킨다.

### FR-05 앱 실행·활성화 — P-02 / P0

고정 또는 실행 앱을 클릭하면 NSWorkspace로 실행/활성화해야 한다. 실행 요청 즉시 pending 상태를 추가하며, 요청 실패는 오류로 알린다. 종료되거나 없는 앱의 상태를 활성 상태로 표시하지 않는다. 앱별 진행 중 클릭을 중복 수행하지 않는다.

### FR-06 최소화·복원 — P-02 / P0

AXWindow 중 standard/dialog/system dialog 및 subrole이 없으나 창 버튼이 있는 창만 취급하고 CFEqual로 같은 객체를 중복 제거한다. 활성 앱 재클릭 옵션이 켜져 있으면 이 목록에 속한 AX focused window, main window, 최소화되지 않은 첫 창 순으로 대상을 찾고 minimize button에 Press를 요청하고, 지원하지 않으면 minimized 속성을 설정한다. 최소화 창 복원 시 minimized=false 및 raise를 요청한다. 현재 구현은 앱 클릭 복원 시 앱의 최소화 창들을 복원하며, 개별 창 선택은 FR-15를 사용한다.

사전 AX 신뢰 검사가 false여도 실제 요청을 차단하지 않는다. 실제 apiDisabled만 권한 거부로, noValue는 창 없음, unsupported 계열은 미지원, cannotComplete는 응답 지연으로 분류한다. 앱 숨김으로 위장하지 않는다. AX messaging timeout은 개별 메시지당 0.5초이며 전체 요청의 시간 상한을 뜻하지 않는다. 모든 AX 메시지는 UI 스레드 밖에서 호출한다. 시스템이 요술램프 효과와 도착 위치를 결정하며 everyDock별 도착점 지정은 범위 밖이다.

유효한 창이 없으면 오류 설정 창 대신 앱의 다시 열기를 요청한다. Finder의 바탕화면·도우미 창은 대상에서 제외한다.

### FR-07 앱 상태 일관성 — P-02 / P0

실행·종료·활성화·숨김 알림과 KVO를 주 경로로 사용하고 5초 재확인(허용 오차 1초)으로 보완해야 한다. 전체 NSRunningApplication 속성 조회는 백그라운드 snapshot 작업 하나로 병합한다. UI에는 변경된 앱 목록만 적용하고, 권한·설정 창 상태 변화는 Dock 전체 재동기화를 유발하지 않는다. pending 요청은 최대 45초 보관한다. 앱 목록·순서·실행/활성/숨김/launching 상태가 같으면 목록을 재발행하지 않는다. 포커스 변화만으로 앱 순서가 바뀌면 안 된다.

### FR-08 기본 Dock 설정 관리 — P-03 / P0

사용자가 관리를 켜면 아래 키의 값과 존재 여부를 백업한 뒤 적용해야 한다. 감시 프로세스를 시작하지 못하면 시스템 값을 바꾸지 않는다. 끄기·일시 숨기기·표시 화면 0개·정상 종료는 복원을 요청한다.

| 키 | 적용값 |
|---|---|
| `autohide` | true |
| `autohide-delay` | 3600 |
| `autohide-time-modifier` | 0 |
| `mineffect` | `genie` |

Dock 재시작은 해당 bundle ID 프로세스에 한정한다. Dock의 시스템 기능을 비활성화하지 않는다.

### FR-09 복원 내구성 — P-03 / P0

원자적 JSON journal과 프로세스 간 파일 잠금을 사용해야 한다. 감시 프로세스는 `kqueue`로 주 프로세스 종료를 감지하며 불가 시 확인 루프를 사용한다. 복원 시 현재 값이 everyDock 적용값과 같은 키만 원래 값으로 바꾸고, 사용자가 변경한 키는 유지한다. 원래 없던 키는 제거한다. 성공 후 journal을 제거하고, 실패 기록은 다음 관리 시작의 재시도 대상으로 남긴다.

### FR-10 바탕화면 파일 스택 — P-04 / P1

v0.3.3에서 사용자 요구에 따라 앱 숨김/복원을 제거하고 바탕화면 폴더의 임시 파일 팝업으로 변경한다. 다운로드와 같은 FolderStack을 사용하며 폴더 이름·아이콘·빈 상태·오류 안내를 구분한다. 최근 수정일 순 최대 80개, 숨김 파일 제외, 파일 클릭과 Finder 열기를 지원한다. 폴더별 요청은 하나로 병합하고 디렉터리·파일 아이콘 읽기는 백그라운드에서 처리한다. 바탕화면 버튼으로 앱의 숨김 상태를 바꾸지 않는다.

### FR-11 다운로드 파일 스택 — P-04 / P1

사용자의 Downloads 폴더에서 숨김 항목을 제외하고 수정일 역순 최대 80개를 4열로 표시해야 한다. 클릭하면 기본 앱으로 열며 Finder 열기를 제공한다. 로딩·비어 있음·실패·접근 응답 대기 상태를 구분한다. 2초 이상 대기하면 접근 안내를 표시한다. 팝업을 반복 개방해도 진행 중 디렉터리 요청은 폴더별 하나만 유지한다.

### FR-12 휴지통 — P-04 / P1

현재 사용자 `~/.Trash`를 열고 내용 변화에 따라 빈/찬 아이콘을 갱신해야 한다. 폴더 아이콘은 캐시하며 휴지통 디렉터리 조회는 백그라운드 작업 하나로 병합한다. 렌더링 함수에서 디렉터리를 읽지 않는다. 비우기는 대상 범위·영구 삭제·취소 불가를 알리고 명시적 확인 후 수행한다. 취소가 기본 키 응답이어야 하며 취소는 아무 항목도 삭제하지 않는다. 외장 드라이브의 휴지통은 포함하지 않는다. 읽기·삭제 실패는 오류로 표시한다.

### FR-13 파일 드롭 — P-04 / P1

file URL 드롭만 처리한다. 바탕화면·다운로드에는 원본을 유지한 복사를, 휴지통에는 `NSWorkspace.recycle`을 사용한다. 원본과 목적지가 같으면 중복 처리하지 않고 기존 이름을 덮어쓰지 않는다. 실패를 알리며, 다중 항목 작업의 부분 성공은 가능하다. 트랜잭션처럼 모두 취소된다고 안내하면 안 된다.

### FR-14 호버 창 미리보기 — P-05 / P1

실행 앱에 대해 설정 지연 후 앱 PID의 AX 일반 창 목록을 기준으로 카드와 개수를 결정해야 한다. SC 목록을 추가 카드로 합치지 않는다. 같은 PID·layer 0의 캡처 창을 위치와 크기 차이 각 8pt 이내에서 점수순으로 1:1 연결하고 제목 일치는 보조 점수로만 사용한다. 동명 창은 독립 AX 객체로 유지한다. 첫 8개 카드까지 이미지를 캡처하고 나머지도 제목으로 선택·닫기를 제공한다. AX 조회가 실패하면 정확한 목록을 읽지 못했다는 안내를 표시한다. 이미지 크기는 최대 440×330 픽셀 설정이며 오디오·포인터는 캡처하지 않는다.

팝업이 열린 동안 약 2초 간격 갱신한다. 캐시는 최근 32개, 조회 시 60초 넘은 항목을 정리하는 메모리 캐시다. 앱 종료 시 소멸한다. CGPreflight 결과가 false라는 이유로 캡처를 차단하지 않는다. 최초 사용 및 명시적 재확인은 SCShareableContent로 실제 접근을 검사하고, 여러 패널의 동시 요청은 하나로 합친다(목록 캐시 1초). 실제 SCStreamErrorDomain의 userDeclined(-3801)만 권한 거부로 분류한다. 거부 후에는 자동 재요청하지 않고 사용자의 재확인 또는 OS 허용 힌트를 기다린다. 다른 API 오류·빈 창·보호된 창은 각각 오류 또는 제목/대체 이미지로 대응한다. 공개 API가 제공하지 않는 창 캡처를 우회하지 않는다.

미리보기 카드가 1개면 1열·222pt, 2개 이상이면 2열·424pt로 배치한다. 썸네일은 190×118pt, 열 간격 12pt, 외곽 패딩 16pt다. 빈 상태는 300pt다. 갱신 후 hosting view의 fittingSize를 NSPopover.contentSize에 반영하고 스크롤 높이는 최대 340pt다.

### FR-15 미리보기 수명·창 선택 — P-05 / P1

아이콘에서 팝업으로 포인터를 옮길 때 약 260ms의 닫힘 유예를 제공하고 팝업 안에서는 유지한다. 대상 변경·클릭·화면 제거·기능 끄기 때 이전 지연·갱신 작업을 취소한다. 카드에 보관한 PID+AX 객체를 현재 앱 창 목록과 CFEqual로 재검증한 뒤 최소화를 해제·raise한다. 제목이나 geometry로 조작 대상을 추측하지 않는다. 사라진 창은 앱 활성화로 대응한다. 팝업이 실제 표시 중일 때만 포인터가 팝업 위에 있는지 검사하며 닫힘 delegate에서도 대상과 작업을 초기화한다. ‘열린 창 보기…’는 호버 설정과 무관하게 즉시 열고 외부 클릭으로 닫을 때까지 유지한다.

### FR-16 고정 앱 — P-06 / P0

초기 기본 Dock 가져오기, 수동 가져오기, 파일 선택 및 `.app` 드롭, 고정/해제·순서 이동을 제공해야 한다. 경로 또는 bundle ID 중복을 제거한다. 경로가 바뀌면 bundle ID로 재탐색하고 실패한 핀도 사용자가 제거할 수 있도록 유지한다.

### FR-17 설정·로그인·중복 실행 — P-06 / P0

설정을 변경할 때 저장하고 화면에 적용해야 한다. 같은 bundle ID의 두 번째 앱은 패널을 추가하지 않고 종료한다. 로그인 항목은 `SMAppService.mainApp`을 통해 사용자가 제어하며, 승인 필요 상태를 표시한다. 앱은 설치 위치에서 실행한 뒤 로그인 항목을 등록하도록 안내한다.

### FR-18 권한 및 오류 안내 — P-06 / P0

권한 상태를 확인 전/사용 가능/macOS에서 거부됨으로 구분하고 사용자가 시스템 설정을 열 수 있어야 한다. 사전 검사는 힌트이며 실제 성공이 우선한다. 시간 초과나 일반 API 오류로 권한 허용/거부를 단정하지 않는다. ‘권한 다시 확인’은 실제 AX 창 목록·SCK 접근을 재검사하며 ‘현재 앱 위치 보기’는 실행 중인 번들을 Finder에 표시한다. 기능별 필요 이유를 설명하며 승인 자체는 OS에서 사용자가 수행한다. ad-hoc 재빌드/업데이트 후 권한 재등록 가능성을 설치 문서에 알린다. 거부 상태에서도 기본 앱 실행·설정·종료를 제공한다.

### FR-19 배포 — P-07 / P1

소스·MRD·PRD·SRS·TC를 공개 GitHub 저장소에 제공한다. 태그와 번들 버전을 일치시키고, arm64 ZIP과 SHA-256 파일을 Release에 올린다. Homebrew tap cask는 버전 고정 URL·체크섬·arm64·macOS 26 이상·앱 설치 항목을 선언한다. README는 설치·실행·업데이트·제거 및 권한을 안내한다. 베타는 prerelease로 표시한다. 복원 journal을 자동 zap 대상으로 등록하지 않는다.

### FR-20 개별 및 모든 창 닫기 — P-09 / P1

미리보기 카드마다 접근성 이름과 도움말이 있는 24pt × 버튼을 제공한다. 닫기 버튼이 없는 창은 비활성화한다. 이미지 선택과 별도 버튼으로 처리하여 닫기 클릭이 창 선택으로 전달되지 않아야 한다. 닫는 동안 중복 요청을 막고 AX 목록과 캡처 메타데이터 캐시를 갱신한다.

앱 우클릭 메뉴는 Finder를 포함한 실행 앱에 ‘모든 창 닫기’를 제공한다. 시작 시 창 객체 목록을 고정하고 순서대로 정상 AXCloseButton Press를 실행한다. 새 창은 포함하지 않는다. 이미 닫힌 창은 건너뛰고 오류는 중지·안내한다. 모달 대화상자/저장 sheet가 있거나 Press 후 최대 1.2초 동안 창이 사라지지 않으면 남은 창을 닫지 않고 앱을 전면에 표시해 사용자 응답을 기다린다. 저장·삭제·확인 버튼을 자동으로 누르거나 강제 종료하지 않는다.

### FR-21 메뉴와 이름 레이블 — P-02 / P1

우클릭, Control-클릭, 접근성 ShowMenu에 같은 앱 메뉴를 제공한다. 메뉴의 크기와 선택 아이콘의 화면 좌표로 아래 Dock에서는 위쪽, 양옆에서는 안쪽에 6pt 간격으로 배치한다. 음수 좌표와 화면 visibleFrame 경계를 보정하며 최종 배치는 NSMenu에 맡긴다. 메뉴 추적 중 호버·미리보기·확대·목록 배치를 멈추고 종료 후 최신 상태를 반영한다. 이름 상자의 배경은 별도 뷰로 그리고 레이블의 intrinsic 높이를 기준으로 세로 중앙에 놓는다.

### FR-22 Apps 앱 목록 — P-02/P-04 / P1

com.apple.apps.launcher 및 이전 Launchpad 식별자는 일반 창 앱으로 취급하지 않는다. Dock 클릭·메뉴 열기는 설치 앱 검색 팝업으로 연결한다. /Applications, /System/Applications(Utilities 포함), 사용자 Applications를 백그라운드에서 탐색한다. 앱 번들 내부 helper·숨김 항목은 제외하고 실제 경로를 중복 제거한다. 검색 필드에 초기 포커스를 주고 이름 검색과 클릭 실행, Finder 열기, 실행 실패 안내를 제공한다. Apps 자체를 다시 목록에 포함하지 않고 45초 실행 중 표시를 남기지 않는다.

### FR-23 확대 창의 Dock 영역 확보 — P-02 / P1

활성 외부 앱 하나에 AXObserver를 등록해 크기 변경·창 생성 알림을 받는다. 창마다 resize를 구독해 앱별 전달 차이를 보완한다. 알림을 100ms 병합하고 창별 0.5초 내 중복 보정을 제한한다. UI 스레드에서는 AX 메시지를 실행하지 않는다.

아래 Dock은 창의 위·아래가 화면 visibleFrame 경계에서 각 12pt 이내일 때 높이만 줄인다. 양옆 Dock은 왼쪽·오른쪽 경계가 각 12pt 이내일 때 해당 방향 폭과 필요 위치를 보정한다. 예약 경계는 실제 패널 위치 + 정지 Dock 두께(iconSize+12pt) + 4pt 여유다. 최대 확대·툴팁용 투명 영역은 예약하지 않는다. 겹치는 면적이 가장 큰 화면을 선택하고 AX의 위쪽 원점으로 변환한다. 숨긴 화면·일시 숨김에는 예약하지 않는다.

표준 AX 창·크기 변경 지원 창만 보정하고 AXFullScreen 또는 전체 화면 여부를 읽을 수 없는 창, 최소화, 대화상자, 일반 크기 창을 제외한다. 앱 활성 전환·레이아웃 변경·종료에서 관찰과 대기 작업을 정리한다. 전역 NSScreen.visibleFrame은 변경하지 않으며 AX를 제공하지 않거나 최소 크기 제약이 있는 앱에 동일한 결과를 보장하지 않는다. 선택적 EVERYDOCK_TRACE_WINDOWS 진단은 상태·geometry만 기록한다.

## 4. 비기능 요구사항

| ID | 요구 | 측정·인수 기준 | v0.3 상태 |
|---|---|---|---|
| NFR-01 | 호환성 | arm64 단일 아키텍처, LSMinimumSystemVersion=26.0, SDK 빌드 성공. 2대 이상 혼합 배율 검증 | 빌드 확인, 화면 행렬 일부 |
| NFR-02 | 반응·성능 | 기준 환경: Apple Silicon, 2화면, 앱 20개. 목표 유휴 CPU 평균≤2%/5분, RSS≤200MiB, 확대 프레임 P95≤16.7ms, 상태 변경 95%≤1초 | 미측정 목표 |
| NFR-03 | 복구 | 목표 프로세스 종료 감지 후 5초 내 정상 Dock 복원. 사용자 변경 보존. 앱 재실행·화면 변경 후 패널 중복 없음 | 자동 모델·v0.2 관찰, 종합 미검증 |
| NFR-04 | 개인정보 | 네트워크·분석 전송 없음. 창 이미지 파일 저장 없음. 실제 거부 후 자동 재시도 없음, 최초 실제 API 검사는 OS 승인 흐름 사용 | 코드 확인, 런타임 관찰 필요 |
| NFR-05 | 파일·설정 보존 | 복사 원본/동명 파일 보존, 취소 후 삭제 0개, 백업 전 Dock 변경 없음, journal 복원 시 사용자 수정 보존 | 일부 자동·수동 확인 |
| NFR-06 | 접근성 | 핵심 버튼 레이블·상태 제공, 동작 줄이기 반영, 라이트/다크·배율·VoiceOver 검사 | 레이블 관찰, 전체 미검증 |
| NFR-07 | 배포 재현성 | CI 테스트·release 빌드, 태그=번들 버전, 다운로드 SHA-256 일치, brew fetch 성공 | TC-R 참조 |
| NFR-08 | 추적 가능성 | 코드·docs를 같은 변경 단위에서 갱신하고 요구 변경 시 구현·테스트를 대조.  모든 P 요구에 FR/NFR과 TC 연결, PASS에 날짜·환경·근거 명시, 제약 공개 | 문서 검토 대상 |

CPU는 Activity Monitor의 프로세스 CPU(논리 코어 하나=100%) 기준으로 측정한다. RSS는 주 프로세스와 감시 프로세스를 합산한다. 성능 목표를 넘으면 실패 원인과 측정 환경을 기록하며 측정 전 달성했다고 주장하지 않는다.

## 5. 데이터와 저장

| 데이터 | 형식·위치 | 수명 |
|---|---|---|
| DockPreferences | JSON Data, UserDefaults `everyDock.preferences.v1`, domain `app.everydock.mac` | 사용자 설정 유지 |
| 고정 앱 | path, optional bundleIdentifier | 설정과 함께 저장 |
| 실행 상태 | id, URL, 이름, 아이콘, pinned/running/active/launching/hidden | 프로세스 메모리 |
| 미리보기 | PID+AX 객체(CFEqual/CFHash), 제목, frame, NSImage?, minimized, canClose | 메모리 캐시 |
| 복원 snapshot | `original`/`applied`, bool/number/string/absent | 복원 완료까지 journal 유지 |
| 폴더·앱 스택 | URL·표시 이름·날짜·캐시한 아이콘·검색 문자열 | 메모리 |

설정의 누락 키는 구버전 기본값으로 채우고 정규화한다. 수동 iconSize 32~72, inset 0~40, magnification 1~4, previewDelay 0.2~2이며 비유한 수는 기본값으로 대체한다. 사용자 데이터·절대 개인 경로·권한 DB·복원 journal을 소스 저장소나 배포 ZIP에 포함하지 않는다.

## 6. 상태 전이와 실패 처리

| 대상 | 정상 전이 | 실패/취소 |
|---|---|---|
| 앱 실행 | 중지 → 요청중 → 실행 → 활성 | 실행 오류 안내, stale pending 만료 |
| 창 | 활성 → 최소화 요청 → 최소화 → 복원 | 권한·AX 오류 안내, 숨김 대체 금지 |
| 기본 Dock | 미관리 → 백업 → 감시 시작 → 적용 → 복원 | 적용 전 실패 시 원래 값 유지, 복원 실패 시 journal 유지 |
| 미리보기 | 닫힘 → 지연 → 조회 → 표시 → 갱신 | 이전 Task 취소, 창 없음/권한 안내 |
| 다운로드 | 미조회 → 읽기 → 목록/빈 폴더/오류 | 대기 안내, Finder 열기, 중복 요청 금지 |
| 휴지통 비우기 | 대기 → 확인 → 삭제 → 완료/오류 | 확인 취소 시 즉시 종료, 삭제 없음 |

## 7. 기술적 한계와 미해결 검증

시스템 요술램프 도착점, 다른 앱 최대화 영역 예약, 보호된 창 캡처, 모든 앱 AX 구현, 잠금·보안 공간 위 표시는 보장하지 않는다. `DockLayout.frame` 테스트는 레거시 함수에 한정되며 런타임 배치는 `DockCoordinator` 수동 테스트가 필요하다. 기본 Dock 설정 복원 오류, 동명 창 선택, 최소화 창 이미지 품질과 대용량 폴더는 반드시 후속 TC로 검증한다.

참고 API: [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview), [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).

## 9. v0.3.1 변경 근거

권한 스위치가 켜져 있어도 현재 앱의 실제 AX/SCK 요청은 거부될 수 있으므로, UI 상태만으로 원인을 단정하지 않는다. ad-hoc 재빌드의 실행 파일 식별 변경은 가능한 원인이며 권한 DB를 우회하거나 변경하지 않는다. 성능 수정은 메인 스레드 반복 IPC와 프레임마다 아이콘 그리기를 제거한다. [검증 기록](QA-v0.3.1.md)을 참조한다. 화면 동기화 API 근거: [Apple NSView.displayLink](https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:)).

## v0.3.2 구현 근거

메뉴 좌표는 [Apple NSMenu.popUp](https://developer.apple.com/documentation/appkit/nsmenu/popup(positioning:at:in:))의 뷰/화면 좌표 규약을 따른다. 창 닫기는 [표준 닫기 버튼](https://developer.apple.com/documentation/applicationservices/kaxclosebuttonsubrole)을 사용한다. [QA-v0.3.2](QA-v0.3.2.md)에 검증 범위와 제한을 기록한다.

## v0.3.3 구현 근거

[NSScreen.visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe)은 시스템 Dock과 메뉴 막대가 제외된 읽기 전용 작업 영역이다. everyDock은 표시 중인 패널을 기준으로 AX 지원 확대 창을 보정한다. 결과와 미검증 조합은 [QA-v0.3.3](QA-v0.3.3.md)을 따른다.
