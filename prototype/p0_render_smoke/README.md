# P0 — 렌더 스모크/벤치마크

디아블로2 클론 Phase 0의 최우선 디리스크: **저사양 개발 머신(Intel HD 4000)에서
Godot 4가 아이소메트릭 + y-sort 다수 스프라이트를 60fps로 렌더하는가** 검증.

## 실행
```
godot --path . --rendering-driver opengl3
```
- 약 7초간 자동 측정 후 평균/최저 FPS를 stdout에 출력하고 종료.
- 비대화식 로그 캡처:
  ```
  godot --path . --rendering-driver opengl3 > bench.log 2> bench.err.log
  ```

## 구성
- `project.godot` — Compatibility(OpenGL3) 렌더러 강제
- `main.gd` — 아이소 타일 576 + y-sort 이동 스프라이트 250 생성, FPS 측정, 자동 종료
- `main.tscn` — 진입 씬

## 실측 결과 (2026-09-20, i5-3360M / 8GB / Intel HD 4000)
- 백엔드: **ANGLE (OpenGL ES 3.0 → Direct3D11)** — Godot이 HD4000 자동 감지 전환
- **avg 145.4 fps / min 116.0 fps** (826 스프라이트, vsync off)
- 판정: **PASS(≥60)** — 목표의 ~2.4배 여유

상세: [딥리서치 Part 8 §4-1](../../docs/superpowers/research/2026-09-19-diablo2-mechanics-research-part8.md)

## 참고 (GDScript 함정)
- Dictionary 값 접근은 `d["key"]` (점 접근 `d.key` 불가)
- `abs()`는 Variant 반환 → `:=` 추론 실패, `absf()` 사용
