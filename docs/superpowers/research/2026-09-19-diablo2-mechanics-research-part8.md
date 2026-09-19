# 디아블로 2 딥리서치 — Part 8 (기술 스택 재평가: 저사양·성능우선)

- 작성일: 2026-09-19
- 계기: 제약 변경 — **웹 배포 제거 · 네이티브 성능 최우선 · 저사양 개발 환경 고려**
- 결론: **Godot 4.4 (Compatibility/OpenGL3)** 확정 (사용자 결정: 에디터 생산성 우선)
- 관련: [로드맵 §7](../specs/2026-09-19-diablo2-clone-master-roadmap-design.md)

---

## 1. 개발 머신 실측 (결정을 지배한 제약)

| 항목 | 사양 | 함의 |
|------|------|------|
| CPU | **Intel i5-3360M** (2C/4T, 2.8GHz, 2012 Ivy Bridge 모바일) | 무거운 에디터·긴 컴파일에 취약. **Rust/Bevy 컴파일 시간 치명적 → 제외** |
| RAM | **8GB** | Unity/Unreal 실사용 곤란 |
| GPU | **Intel HD 4000** | **Vulkan 미지원**, OpenGL 4.0까지, OpenGL 3.3 드라이버 불완전 |
| OS | Windows 10 Pro (19045) | — |

### GPU가 핵심
- **Vulkan 드라이버는 Gen9(Skylake)+ 만 제공 → HD 4000 제외.** → Godot 4 기본(Forward+)/Mobile 렌더러 **구동 불가**.
- HD 4000은 OpenGL 4.0까지 지원하나 **Intel의 OpenGL 3.3 지원이 불완전**(godot#17660) → Godot 4 Compatibility도 잠재 불안정.
- **단, 이는 개발 머신 한정 제약**이다. 출시 타깃(모바일/최신 GPU)은 GLES3/Vulkan 정상 → 제품 성능 무관.

출처: [HD4000 Vulkan 미지원 — Intel](https://community.intel.com/t5/Graphics/When-should-we-get-vulkan-opengl-4-5-drivers-for-intel-hd-4000/td-p/580506), [HD4000 OpenGL3.3 불완전 — godot#17660](https://github.com/godotengine/godot/issues/17660), [Godot4 Vulkan/GLES 정책](https://godotengine.org/article/about-godot4-vulkan-gles3-and-gles2/), [Godot 4.4 시스템 요구사항](https://docs.godotengine.org/en/4.4/about/system_requirements.html)

---

## 2. 후보 스택 비교 (네이티브·성능우선·저사양)

필터: **OpenGL 기반(Vulkan 불필요) + 경량 개발환경 + 네이티브 성능 + 모바일 export**

| 스택 | 언어 | 성능 | 저사양 개발 | 모바일 | 대형 콘텐츠 관리 | 비고 |
|------|------|:--:|:--:|:--:|:--:|------|
| **Godot 4.4 (Compat)** | GDScript/C# | ★★★ | ★★ (HD4000 불안정) | ★★★★ | ★★★★★ | **에디터 생산성 = 채택 사유** |
| MonoGame | C# | ★★★★ | ★★★★ | ★★★★ (검증) | ★★★★ | 코드퍼스트 균형 최적(차선) |
| raylib | C | ★★★★★ | ★★★★★ | ★★★ (수동) | ★★ | 성능 천장 최고, 툴 자작 |
| LÖVE | Lua | ★★★ | ★★★★★ | ★★★★ | ★★ | 반복 최속, 동적타입 위험 |
| Godot 3.6 | GDScript | ★★★ | ★★★★ (GLES2) | ★★★★ | ★★★★ | HD4000 안정적이나 EOL(폴백용) |
| Unity | C# | ★★★★ | ★ (무거움) | ★★★★ | ★★★★ | 이 머신서 실사용 곤란 |
| Bevy | Rust | ★★★★★ | ★ (컴파일 지옥) | ★★★ | ★★★ | 2C/4T서 반복 불가 → 제외 |

출처: [저사양 2D 엔진 — Slant](https://www.slant.co/topics/5363/~2d-game-engines-for-low-end-machines-laptops), [raylib vs MonoGame](https://aircada.com/blog/raylib-vs-monogame), [Godot 렌더러 개요](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [Bevy 2026](https://aarambhdevhub.medium.com/rust-game-engines-in-2026-bevy-vs-macroquad-vs-ggez-vs-fyrox-which-one-should-you-actually-use-9bf93669e83f)

### 트레이드오프
- **순수 성능+저사양**만 보면 raylib(C) > MonoGame(C#) > LÖVE(Lua) 순의 **코드퍼스트 네이티브**가 유리.
- 그러나 **풀 D2 클론은 콘텐츠가 방대** → 씬/타일맵/애니메이션 **에디터 생산성**의 가치가 큼.
- **사용자 결정: 에디터 생산성 우선 → Godot 4 채택.** HD4000 불안정 리스크는 구성·폴백으로 관리.

---

## 3. 확정 구성 (Godot 4)

| 항목 | 값 |
|------|-----|
| 엔진 | **Godot 4.4.x** (TileMapLayer y-sort 개선판) |
| 렌더러 | **Compatibility (OpenGL3)** — 실행: `godot --rendering-driver opengl3`, 프로젝트 설정 Rendering Method = `gl_compatibility` |
| 언어 | GDScript 우선, 핫스팟만 C#/GDExtension |
| 드라이버 | Intel HD4000 최신 드라이버(15.28.x, EOL) 설치 권장 |
| 폴백 | **Godot 3.6 (GLES2)** — 4.4가 머신서 불안정 시 프로토타입용, 이후 4.x 이전 |
| 데이터 | JSON data-driven(게임 테이블) + 임포트 스크립트 분리 |
| 맵 | Godot TileMapLayer + 커스텀 청크 조립기(Part 2 §5) |

---

## 4. P0 디리스크 계획 (조사 종료, 실측 시작)

이 결정의 유일한 미검증 리스크 = **HD4000에서 Godot 4.4 실제 구동/성능**. 프로토타입으로만 해소됨:

1. **에디터 구동:** `--rendering-driver opengl3`로 Godot 4.4 에디터 실행 + 2D 아이소 씬 편집 안정성 확인.
2. **런타임 60fps:** 아이소 TileMapLayer + y-sort + 캐릭터/몬스터 ~200 스프라이트에서 60fps 실측 (Part 2 §1 25틱 논리 분리).
3. **입력:** 가상 조이스틱 + 스킬버튼(자동조준/홀드조준) 터치 프로토타입.
4. **판정 게이트:** 1~2가 불안정하면 즉시 **Godot 3.6 폴백**으로 P0 재개.

**성공 기준:** 에디터가 실사용 가능한 반응성 + 아이소 씬 60fps 유지. → 통과 시 Phase 1 진입.

### 4-1. P0 실측 결과 (2026-09-20) — 통과 ✅
프로토타입: `prototype/p0_render_smoke/` (Godot 4.7.2, `--rendering-driver opengl3`).

| 측정 | 값 |
|------|-----|
| 렌더 백엔드 | **ANGLE (OpenGL ES 3.0 → Direct3D11)** — Godot이 HD4000 감지 후 자동 전환 |
| 씬 부하 | 아이소 타일 576 + y-sort 이동 스프라이트 250 = **826 스프라이트 매 프레임 정렬** |
| **평균 FPS** | **145.4** (vsync off, 상한 해제, 934 샘플) |
| **최저 FPS** | **116.0** |
| 판정 | **PASS(≥60)** — 목표의 약 2.4배 여유 |

**결론:** 최대 리스크였던 "HD4000 Godot 4 구동/아이소 y-sort 성능"이 **실측으로 해소**됨.
- Godot 4.7의 **자동 ANGLE 전환**이 Intel OpenGL 3.3 불완전 문제를 우회(→ D3D11) → **Godot 3.6 폴백 불필요**.
- 아이소 + y-sort 826개가 116fps 최저 → **원작 규모 근사에도 충분한 헤드룸**.
- 단, 이는 렌더 전용 합성 씬(전투·경로탐색·AI 미포함) → 실제 게임 로직 부하는 이후 단계에서 재측정 필요.

**GDScript 함정 기록:** ① Dictionary는 `d.key` 점 접근 불가 → `d["key"]`. ② `abs()`는 Variant 반환 → `:=` 추론 실패, `absf()` 사용.

---

## 5. 결론

- 제약 3종(웹제거·성능우선·저사양)을 반영해 스택을 재평가, **Godot 4.4 Compatibility**로 확정.
- **최대 리스크는 제품이 아니라 "개발 머신 GPU"** — 로드맵 §6 리스크·§7에 반영.
- **딥리서치는 여기서 종료가 맞다.** 남은 불확실성(HD4000 Godot 구동)은 문서가 아니라 **P0 프로토타입**으로만 확인된다. → 다음 행동: **P0 착수**.
