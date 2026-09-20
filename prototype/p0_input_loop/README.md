# P0 — 입력 + 고정 틱 게임루프

디아블로2 클론 Phase 0: **모바일 조작 + 원작 프레임 모델(25Hz 논리 틱)** 검증.

## 실행 (직접 조작 테스트)
```
godot --path . --rendering-driver opengl3
```
- **이동:** 좌하단 가상 조이스틱을 마우스로 드래그(터치 에뮬레이션 활성).
- **스킬:** 우하단 버튼 3개 — **짧게 탭 = 즉시 자동조준 시전**, **길게 눌러 홀드 = 차징**(원형 게이지) 후 놓으면 방출.
- 창을 닫으면 종료.

### 비대화식 검증 (자동 6초 후 종료)
```
godot --path . --rendering-driver opengl3 -- autoquit
```

## 설계 포인트
- **논리 틱 25Hz** (`project.godot` → `physics/common/physics_ticks_per_second=25`).
  - 이동·전투 판정 = `_physics_process` (25Hz, 원작 프레임 모델 → 브레이크포인트 재현 기반).
  - 카메라 추적·HUD·이펙트 페이드 = `_process` (렌더 레이트).
- **아이소 좌표 변환**: `_iso()` (그리드→스크린), `_screen_dir_to_grid()` (조이스틱 방향→그리드 이동, 역투영).
- **입력 유닛 분리**: `virtual_joystick.gd`, `skill_button.gd` (각각 독립 Control).

## 실측 결과 (2026-09-20, Intel HD 4000 / ANGLE→D3D11)
- **logic_rate = 25.14/s** (target 25) → 고정 틱 정확 동작. **verdict=PASS**, 런타임 에러 0.
- 렌더 처리량은 별도 검증됨: `../p0_render_smoke` 826 스프라이트 @ 145fps.

## 참고 (GDScript)
- 컴포넌트 스크립트는 `preload()` 상수로 로드(전역 `class_name` 등록 의존 제거).
- `.godot/` 캐시에 스테일 전역 클래스가 남으면 삭제 후 재실행.
