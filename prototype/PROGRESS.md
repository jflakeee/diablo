# 프로토타입 진행 기록

개발/검증 머신: **i5-3360M(2C/4T) · 8GB · Intel HD 4000 · Win10** (최저사양 타깃).
엔진: **Godot 4.7.2**, Compatibility(OpenGL3 → 자동 ANGLE → Direct3D11).

| 단계 | 프로토타입 | 검증(실측) | 상태 |
|------|-----------|-----------|------|
| P0 렌더 | `p0_render_smoke` | 아이소+y-sort 826 스프라이트 **avg 145 / min 116 fps** | ✅ PASS |
| P0 입력/루프 | `p0_input_loop` | 25Hz 논리틱 **rate 25.14/s**, 조이스틱+스킬 탭/홀드 | ✅ PASS |
| Phase 1 | `phase1_arena` | 맵+충돌+몬스터AI+전투공식, **attacks 27 / hits 26 / life 94-157** | ✅ PASS |

## 핵심 검증 결론
- HD 4000에서 Godot이 자동 ANGLE(→D3D11) 전환 → **OpenGL 3.3 불완전 우려 무력화**. Godot 3.6 폴백 불필요.
- 렌더 헤드룸 충분(원작 규모 근사 826개서 116fps 최저).
- 원작 프레임 모델(25Hz 논리틱) 정확 동작 → 브레이크포인트 재현 기반 확보.
- 딥리서치 전투 공식(명중률·물리데미지·바바리안 Life)이 실제 게임 루프에서 작동.

## GDScript 함정 로그 (재발 방지)
- Dictionary 값은 `d["key"]` (점 접근 불가)
- `abs()`는 Variant 반환 → `absf()`
- 신규 프로젝트에서 `class_name` 전역 등록 불안정 → **`preload()` 상수 + 타입 힌트로 사용**
- 동적 멤버(Node/Variant) 산술은 `:=` 추론 실패 → **명시 타입** 또는 스크립트 타입(`ActorScript`)으로 선언

## 다음 후보
- 두 입력/렌더 경로를 Phase 1에 완전 통합(현재 phase1_arena가 이미 통합본)
- P2 정식화: AR/Defense 산출식, 저항·블록·전투 모디파이어(Part 5/6)
- P7: `monstats.txt` 임포트 → 실제 몬스터 스탯
- P6: 사망 시 드롭(트레저 클래스) 연결
- P3: 스킬 시스템(바바리안 트리)
