# v0.3.1 권한·프레임 갱신 회귀 검증

기준일: 2026-09-07~08. Apple M5 / 32GB / macOS 26.5.2 (25F84). 외부 화면 2304×1296pt와 내장 Retina 1512×982pt, native 크기 39→104pt, 16개 앱 및 유틸리티 3개. 아래 수치는 해당 세션의 관찰이며 표준 성능 시험 전체 통과를 뜻하지 않는다.

## 최종 결과

- 사용자 확인: 미리보기·최소화 정상 동작. 첫 후보는 여전히 끊겼으나 NSButtonCell 제거 후 ‘이제 부드러움’ 응답을 받았다.
- 최종 앱은 셀 없는 NSControl을 사용한다. 접근성 Press·Space/Return·드래그 취소/복귀 포함 자동 테스트 **17개 PASS**. 공개 배포 ZIP과 같은 번들을 실행 상태로 유지한다.
- 실제 AX 창 목록/SCK 접근 성공. 기존 권한의 동일 앱 등록을 최종 번들로 복구했다.
- 렌더 진단: 최종 컨트롤의 클릭 반응은 120Hz callback 36개, 긴 간격 0, render P95 0.594ms. 사용자 호버 구간 일부는 P95 6.760~8.844ms 및 1.5배 초과 간격이 남았다. 체감 개선 확인과 모든 120Hz 프레임 전달 보장은 구분한다.
- 메모리≤200MiB·확대 중 CPU 감소율·모든 표시 프레임 인수 기준은 통과를 주장하지 않는다. 아래 후보 기록은 최종 수치와 구분한다.

## 원인과 수정


- 시스템 설정의 everyDock 스위치는 켜져 있으나 이전 번들의 AX/화면 기록 사전 검사와 실제 AX/SCK 호출은 거부됐다. 임시 서명은 designated requirement에 실행 파일 cdhash를 사용했다. 현재 앱을 재등록한 뒤 실제 AX 창 목록·SCK shareable content 검사가 성공했다. 권한 등록과 실행 번들의 불일치에 부합하는 관찰이다.
- 코드의 사전 검사 false 분기를 제거하고 실제 API 결과로 판단한다. 창 없음·미지원·응답 지연·API 오류를 권한 거부와 분리한다. 명시적인 재검사와 현재 앱 위치 확인을 제공한다.
- 이전 3초 sample에서는 주 스레드의 앱 조회/관찰 경로에서 NSRunningApplication 동기 IPC 대기가 관찰됐다. 전체 속성 조회를 백그라운드 snapshot으로 옮기고 이벤트를 병합했다. 0.5초 보완 조회를 5초로 변경했으며 정상 상태 알림은 즉시 처리한다.
- 60Hz Timer와 매 프레임 NSImage/NSBezierPath 그리기를 화면별 CADisplayLink·캐시된 CGImage/CALayer로 교체했다. 픽셀 정렬한 패널 요청 frame을 기억하고 같은 frame을 다시 적용하지 않는다.
- 추가 5초 sample에서 포인터마다 ProcessInfo.environment 전체를 읽고 동일 ignoresMouseEvents 값을 WindowServer에 전송하는 비용을 발견해 각각 시작 시 캐시·변경 시에만 적용하도록 수정했다.

## 첫 후보에서의 관찰 (최종 인수 결과와 구분)

| 항목 | 결과와 근거 |
|---|---|
| 자동 회귀 TC-A01~A14 | PASS. 첫 후보 `swift test --arch arm64`, 14개 성공. 최종 컨트롤 테스트 추가 후 17개 성공 |
| release 패키징 | PASS. arm64, 최소 OS26, 버전0.3.1/build4, codesign strict 성공 |
| 아이콘·유틸리티 | PASS(관찰 범위). 최종 레이어 렌더링에 앱 아이콘·바탕화면·다운로드·휴지통과 점·구분선 표시 |
| 실제 권한 검사 | PARTIAL. 재등록 전 AX/SCK 실제 거부를 재현하고 재등록 후 두 실제 API 사용 가능 확인. 최종 배포 번들의 재등록 결과는 아래 추가 기록 참조 |
| 최소화·복원·썸네일 | PARTIAL. AX/SCK 접근 성공과 Dock 클릭 활성화를 확인. 모든 앱·10회 반복·시스템 요술램프 전체 프레임·실제 썸네일 카드 선택의 종합 검증은 미완료 |
| 렌더 콜백 진단 | PARTIAL. 추가 포인터 최적화 직전 후보에서 120Hz 연속 90/31 콜백 구간, 1.5배 초과 간격 0, 렌더 함수 P95 4.944/4.863ms. 이는 실제 표시 FPS나 GPU/WindowServer 시간을 뜻하지 않음 |
| CPU·RSS | 표준 TC-P01/P02 NOT RUN. UI 조작이 섞인 짧은 top 구간은 CPU 2.0/10.8/7.3%, ps 주 프로세스 RSS 443312KiB, 감시 9248KiB. 유휴 5분 수치가 아니며 CPU 감소율을 주장할 수 없음. 메모리 목표≤200MiB 충족 근거 없음 |

프로파일링 원본은 `.build`에만 보관한다. 사용자 창 내용·앱 경로·계정 정보가 포함될 수 있는 원본 sample과 화면은 공개하지 않는다. 지표만 이 문서에 옮긴다.

## 재현

```sh
swift test --arch arm64
./scripts/package-release.sh
# 실행 중인 앱을 정상 종료한 뒤, 빌드가 끝난 동일 번들로 실행한다.
open --env EVERYDOCK_TRACE_FRAMES=1 --stderr /tmp/everyDock-frames.log dist/everyDock.app
```

`frames`는 한 애니메이션 구간의 callback 수, `expectedHz`는 display link의 목표 간격 역수, `callbackGapOver1.5x`는 실제 callback timestamp 간격 초과 횟수, `renderP95ms`는 렌더 함수의 벽시계 시간이다. 정지하면 display link가 해제된다. 비활성화가 기본이며 로그에는 앱 이름·창 제목·이미지가 없다.

권한은 최종 배포 번들에서 등록해야 한다. 디버그/릴리스 빌드나 패키징의 strip·재서명으로 cdhash가 바뀌면 기존 등록이 다시 무효일 수 있다. 검증 후 바이너리를 다시 빌드하거나 재서명하지 않는다. 안정된 Apple Development/Developer ID 서명 도입은 별도 배포 과제다. [Apple DTS의 TCC·서명 설명](https://developer.apple.com/forums/thread/730043), [Apple의 화면 동기화 API](https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:)).

## 배포 번들 및 권한 확인

- 최종 ZIP SHA-256: `e1c82ad15f1682def8e9f9123ae6eef829a9e9c949414bd2d2a81c3672a0fe25`.
- 실행 중인 번들과 ZIP 추출본의 실행 파일 SHA-256 일치: `2127b6b71f3df04881d0750a877c2e220c1eb51d488114a419ccd2d42b16d939`.
- 사용자 재등록으로 후보 번들의 접근 성공을 확인했다. 이후 최종 ZIP 번들 교체에서 거부가 다시 재현되어, 같은 앱의 기존 두 권한 항목을 시스템 설정에서 제거·동일 번들로 다시 등록했다. 단순 스위치 껐다 켜기로는 해결되지 않았다.
- 최종 번들 실행 후 설정의 ‘권한 다시 확인’을 실행해 실제 AX 창 목록 및 SCK shareable content 요청이 성공하고 두 항목이 ‘사용 가능’인 것을 확인했다. 이 제한된 TC-M32 경로는 PASS이며, 썸네일 이미지·모든 앱 최소화 인수 시험 전체 PASS를 뜻하지 않는다.
- 최종 아이콘/세 유틸리티 렌더링 확인. 코드 수정 없이 같은 번들을 실행 상태로 유지한다.

첫 후보의 5분 top 기록에는 사용자의 실제 호버 시험이 섞였다. 초기 10초 간격 유휴 표본은 약0.3%였으나 전체를 유휴 평균으로 사용할 수 없다. 추가 개선은 NSControl 셀 제거이며, 최종 사용자가 체감 개선을 확인한 뒤 더 이상 실행 번들을 재빌드하지 않았다.
