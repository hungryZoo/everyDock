# 릴리스와 Homebrew 배포

기준일: 2026-09-07. 소스 저장소는 [hungryZoo/everyDock](https://github.com/hungryZoo/everyDock), cask는 기존 [hungryZoo/homebrew-tap](https://github.com/hungryZoo/homebrew-tap)의 `Casks/everydock.rb`에서 관리한다.

## 1. 버전과 검증

1. `Resources/Info.plist`의 앱 버전·빌드 번호를 갱신한다. 설정 UI는 번들의 버전을 읽으므로 별도 문자열을 수정하지 않는다.
2. MRD·PRD·SRS 변경과 관련 TC를 갱신한다. 미검증 기능을 통과로 표시하지 않는다.
3. 테스트와 패키징을 실행한다.

```sh
swift test --arch arm64
./scripts/package-release.sh
```

패키징 스크립트는 임시 staging에서 빌드하므로 실행 중인 `dist/everyDock.app`을 덮어쓰지 않는다. arm64·최소 macOS 26·서명을 확인하고 debug symbol을 제거한 후 다시 서명한다. 결과는 `dist/releases/everyDock-VERSION-arm64.zip`과 `SHA256SUMS`다. ZIP에는 앱 번들만 포함하며 사용자 설정·journal·스크린샷을 넣지 않는다.

기본 빌드는 ad-hoc 서명이다. `CODE_SIGN_IDENTITY`가 있는 환경에서는 해당 identity로 서명하지만, 이 스크립트가 공증까지 완료하는 것은 아니다. Developer ID·hardened runtime·공증·staple은 안정 배포를 위한 후속 절차다.

## 2. 공개 전 점검

- git에 소스·문서·스크립트만 포함됐는지 확인한다. `.build`, `dist`, `.env`, 인증서·권한 DB·개인 파일은 올리지 않는다.
- 원격 브랜치의 CI가 통과했는지 확인한다. Actions는 macOS 26 arm64에서 테스트와 동일 패키징을 수행한다.
- 공개할 바이너리의 TC-R01~R04를 확인하고 릴리스 노트에 남은 제약을 적는다.
- 버전 태그는 공개할 commit을 가리켜야 한다. 같은 태그의 자산을 덮어쓰지 않고 수정은 새 버전으로 배포한다.

## 3. GitHub Release

검증한 commit에 버전 태그를 만들고 push한다. 예시는 v0.3.0 공개 베타다.

```sh
git tag -a v0.3.0 -m 'everyDock v0.3.0 public beta'
git push origin v0.3.0
gh release create v0.3.0 \
  dist/releases/everyDock-0.3.0-arm64.zip \
  dist/releases/SHA256SUMS \
  --repo hungryZoo/everyDock --verify-tag --prerelease \
  --title 'everyDock v0.3.0 — Public Beta' \
  --notes-file docs/releases/v0.3.0.md
```

최초 배포 이후 위 예시를 그대로 재실행하지 않는다. 다음 버전 값과 릴리스 노트를 먼저 바꾼다. [GitHub Release 문서](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

## 4. Homebrew tap 갱신

기존 tap을 별도 checkout하고 다른 cask를 유지한다. `Casks/everydock.rb`의 version·sha256·고정 다운로드 URL을 새 릴리스에 맞춘다. SHA-256은 **업로드 후 다시 내려받은 자산**에서도 확인한다. prerelease 단계에서는 `livecheck` 자동 승격을 사용하지 않는다.

```sh
brew tap hungryZoo/tap
# Homebrew 6+: 해당 cask에만 로딩 신뢰를 부여한다.
brew trust --cask hungryZoo/tap/everydock
brew style hungryZoo/tap/everydock
brew audit --cask hungryZoo/tap/everydock
brew fetch --cask hungryZoo/tap/everydock
```

공증 검사를 포함한 online/strict audit은 현재 ad-hoc 베타에서 실패할 수 있다. 실패를 숨기거나 Homebrew 공식 cask 기준을 충족한다고 주장하지 않는다. 일반 audit 결과와 공증 미완료는 별도로 기록한다. cask는 Gatekeeper·quarantine을 해제하는 설치 스크립트를 포함하지 않는다.

v0.3.9부터 cask의 uninstall_preflight는 명시적 uninstall/reinstall에서 앱의 초기화 도우미를 실행한다. upgrade에서는 설정을 보존한다. 도우미는 앱 종료·기본 Dock 복원·로그인 해제 후 설정 도메인과 캐시를 제거한다. Homebrew가 설치 당시 cask를 재사용하므로 제거 정책 변경은 새 버전 배포와 함께 검증한다. zap에는 미복원 기본 Dock journal을 포함하지 않는다. 설치·업데이트·제거 명령은 [README](../README.md)에 있다.

근거: [Tap 유지보수](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap), [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook), [Homebrew 6 Tap Trust](https://docs.brew.sh/Tap-Trust).

## 5. 잘못된 릴리스 대응

이미 배포한 ZIP을 조용히 교체하지 않는다. 결함을 릴리스에 알리고 새 패치 버전과 새 체크섬을 배포한다. 긴급 설치 중단은 해당 cask에 명시적인 disable 사유를 추가하고 기존 설치자의 설정·복원 기록을 삭제하지 않는다. 앱 설정 마이그레이션이 있으면 업그레이드·제거/재설치 TC를 재실행한다.

최종 패키징의 strip·재서명 후 번들로 권한을 등록하고 검증한다. 검증한 로컬 번들은 재빌드하지 말고 Release ZIP과 같은 파일을 유지한다. 임시 서명의 업데이트 권한 문제와 재등록 근거는 [v0.3.1 QA](QA-v0.3.1.md)를 따른다.
