# 프로토타입 진행 기록

개발/검증 머신: **i5-3360M(2C/4T) · 8GB · Intel HD 4000 · Win10** (최저사양 타깃).
엔진: **Godot 4.7.2**, Compatibility(OpenGL3 → 자동 ANGLE → Direct3D11).

| 단계 | 프로토타입 | 검증(실측) | 상태 |
|------|-----------|-----------|------|
| P0 렌더 | `p0_render_smoke` | 아이소+y-sort 826 스프라이트 **avg 145 / min 116 fps** | ✅ PASS |
| P0 입력/루프 | `p0_input_loop` | 25Hz 논리틱 **rate 25.14/s**, 조이스틱+스킬 탭/홀드 | ✅ PASS |
| Phase 1 | `phase1_arena` | 맵+충돌+몬스터AI+전투공식, **attacks 27 / hits 26 / life 94-157** | ✅ PASS |
| Phase 2 | `phase2_skills` | 캐릭터(AR/Def/Life/Mana 산출)+스킬(Bash/Berserk/BO/Mastery)+레벨링, **Lv3/kills3/BO: life 157→217/mastery3** | ✅ PASS |
| Phase 3 | `phase3_items` | 아이템/접사/드롭/인벤토리/장착, **kills5/drops2/picked2, 방어구 장착 def 21→47** | ✅ PASS |

> **🏁 수직 슬라이스(Phase 0~3) 완성** — 로드맵의 "게임이 돈다"(이동→전투→드롭→장착) 지점 도달.

| Phase 4 | `phase4_craft` | 소켓/보석/룬워드/큐브, **Ruby+38life · Steel(Tir+El) · 순서검증 · El×3→Eld** | ✅ PASS |
| Phase 5 | `phase5_boss` | 몬스터 AI(근접/원거리/보스)+안다리엘 3패턴, **melee9/nova3/spray1** | ✅ PASS |

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
