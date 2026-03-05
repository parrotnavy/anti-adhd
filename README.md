# AntiADHD (macOS Focus Mask)

주의 분산을 줄이기 위한 macOS 메뉴바 도구입니다.

## 기능
- 나머지 화면 검정 마스킹 ON/OFF
- 모드
  - **Current Display**: 현재 마우스가 있는 모니터만 보이기
  - **Focused Window**: 현재 포커스 창만 보이기
  - **Locked Window**: 잠근 창만 계속 보이기
- Focused Window 전용 나머지 영역 표시 방식
  - **Freeze Non-selected Area**: 선택 창 제외 영역을 정지 화면으로 유지
  - **Black Overlay**: 선택 창 제외 영역 검정 오버레이
  - **Blur Non-selected Area**: 선택 창 제외 영역 블러 처리
- 선택 창 컷아웃은 macOS 느낌에 맞게 **rounded corner**로 표시
- Black Overlay 투명도 조절
  - `30% / 50% / 70% / 85% / 100%`
- 제어 방식
  - 상태바 메뉴
  - 전역 단축키
    - `⌥⌘B`: 마스크 ON/OFF
    - `⌥⌘L`: 현재 포커스 창 잠금
    - `⌥⌘⎋`: 긴급 해제(Emergency Off)

## 요구사항
- macOS 13+
- Swift 5.9+

## 실행
```bash
swift build
swift run
```

## 권한
창 모드(`Focused/Locked`)는 **Accessibility 권한**이 필요합니다.
- 메뉴에서 `Request Accessibility Permission` 클릭
- 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 앱 허용

권한이 없으면 앱은 자동으로 Current Display 모드로 폴백합니다.

## 알려진 제한
- 일부 앱(보안/특수 렌더링)은 창 프레임 추적이 제한될 수 있습니다.
- Spaces/풀스크린 환경에서 오버레이 우선순위가 앱별로 다를 수 있습니다.

## 패키징 (DMG)
로컬에서 DMG를 만들려면 아래 스크립트를 실행합니다.

```bash
./scripts/package_dmg.sh X.Y.Z
```

- 생성물: `dist/AntiADHD-X.Y.Z.dmg`, `dist/SHA256SUMS.txt`
- VERSION 형식: `X.Y.Z`, `X.Y.Z-rc.1`, `main-abcdef0`

CI/릴리즈에서도 동일한 스크립트를 사용합니다: `.github/workflows/ci.yml`, `.github/workflows/release.yml`

## 릴리즈 (GitHub Release)
릴리즈 워크플로우: `.github/workflows/release.yml`

태그를 push하면 자동으로 실행되어 DMG와 체크섬을 GitHub Release에 업로드합니다.

```bash
git tag vX.Y.Z && git push origin vX.Y.Z
```

- 업로드 아티팩트: `dist/AntiADHD-X.Y.Z.dmg`, `dist/SHA256SUMS.txt`
- 릴리즈 노트는 `scripts/generate_release_notes.sh` 로 생성됩니다.

## 자동 업데이트 (Sparkle)
Sparkle 앱캐스트(feed)는 GitHub Pages에서 호스팅됩니다.

- `SUFeedURL`: `https://parrotnavy.github.io/anti-adhd/api/macos-appcast.xml`
- 소스 파일: `site/api/macos-appcast.xml`
- 릴리즈 워크플로우에서 DMG에 대한 Sparkle 서명을 만들려면 아래 secret이 필요합니다.
  - `SPARKLE_ED25519_PRIVATE_KEY_BASE64`: Ed25519 private key (base64). 절대 커밋하지 마세요.
- `scripts/package_dmg.sh` 는 notarization을 선택적으로 지원합니다. 아래 값이 모두 설정되면 `notarytool submit` 후 `stapler staple`까지 수행합니다.
  - `APPLE_NOTARY_KEY_P8_PATH`: App Store Connect API Key(.p8) 파일 경로
  - `APPLE_NOTARY_KEY_ID`: Key ID
  - `APPLE_NOTARY_ISSUER_ID`: Issuer ID
- 재현 가능한 의존성 고정을 위해 `Package.resolved` 는 저장소에 커밋합니다.

## GitHub Pages (사이트 배포)
Pages 배포 워크플로우: `.github/workflows/deploy-pages.yml`

- Settings > Pages > Build and deployment 에서 Source를 `GitHub Actions` 로 설정하세요.
- `site/` 디렉터리가 그대로 배포됩니다.
- `site/.nojekyll` 파일은 반드시 커밋되어 있어야 합니다.

## Clarity 설정
`deploy-pages.yml` 는 `CLARITY_PROJECT_ID` 가 필요합니다.

- Actions variable `CLARITY_PROJECT_ID` (권장) 또는 secret `CLARITY_PROJECT_ID` 를 설정하세요.
- `site/*.html` 안의 `__CLARITY_PROJECT_ID__` 플레이스홀더가 배포 시 치환됩니다.

분석 수집과 동의, 개인정보 관련 안내는 `site/privacy.html` (및 `site/terms.html`) 에 반영하세요.
Microsoft Clarity 문서: https://learn.microsoft.com/en-us/clarity/
