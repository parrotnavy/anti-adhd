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
