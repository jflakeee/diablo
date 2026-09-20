# 전투 심화 (B) — 저항·블록·흡혈·크러싱블로우

Part 5/6의 전투 메커니즘을 게임에 적용: 저항/면역/약점, 최대저항 캡, 블록, 생명 흡혈,
크러싱 블로우.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3 -- barb     # 블록·흡혈·크러싱블로우
godot --path . --rendering-driver opengl3 -- sorc     # 파이어볼 화염저항(안다리엘 약점)
godot --headless --path . --quit                      # 공식 자체검증만
```

## 딥리서치 → 코드 (`combat.gd`)
| 공식 | 함수 | 검증값 |
|------|------|--------|
| 저항 적용 (Part 5 §2) | `apply_resistance(dmg,resist,cap)` | 50%→50, 약점-50→150, 면역100→0, 캡90→25 |
| 최대저항 캡 | `effective_resist` | 75 기본 |
| 블록 확률 (Part 5 §3) | `block_chance(shield,dex,clvl)` | (30×85)/40=63.75 |
| 생명 흡혈 (Part 5 §4) | `leech_life(dmg,pct)` | 100×6%=6 |
| 크러싱 블로우 (Part 5 §4) | `crushing_blow(life,ranged,boss)` | 400×1/4=100 |

## 게임 연동
- **바바리안**: 블록(방패30, `roll_block`) + 흡혈 6% + 크러싱블로우 20%
- **소서리스 파이어볼 = 화염 데미지**: 대상 `res_fire` 적용 → **안다리엘(화염 -50%)엔 150% 약점**
- 몬스터/플레이어 `res_fire`·`block_val`·`leech_pct` 필드(actor.gd)

## 실측 (2026-09-20, HD 4000)
```
combat_deep_selftest verdict=PASS (저항/블록/흡혈/크러싱/캡 전부 일치)
barbarian: block=30 leech=6, game verdict=PASS, 에러 0
```

## 정식화
- 4속성 저항 전부(냉/번/독) + 냉기 슬로우·독 DoT, 흡혈 난이도 페널티
- IAS/FCR/FHR 브레이크포인트 애니메이션 프레임, 물리 피해감소(PDR)·흡수(absorb)
- 난이도(NM/Hell) 몬스터 저항/HP 스케일링(Part 2 §3), 면역 깨기(Conviction/LR)
