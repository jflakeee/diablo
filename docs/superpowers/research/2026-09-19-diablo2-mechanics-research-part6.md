# 디아블로 2 메커니즘 딥리서치 — Part 6 (보조 시스템 공식)

- 작성일: 2026-09-19
- 목적: [Part 5 §7](./2026-09-19-diablo2-mechanics-research-part5.md) 보조 공식 처리
- 다루는 항목: 달리기/스태미나 / 보석 슬롯별 스탯 / 용병 / 도박
- 주 대상: P2(이동/스태미나), P5(보석), P8(용병/도박)

---

## 1. 달리기 / 걷기 / 스태미나 · P2

### FRW (Faster Run/Walk)
- **브레이크포인트 없음.** FRW는 연속적 — Effective FRW 1%당 속도 **+0.06 yards/초**.
- 주 출처: 부츠, 참(charm). 아이템 FRW는 **수확체감** 적용(스탯 FRW는 예외).
- 무거운 갑옷·방패는 이동속도를 낮춤.

### 스태미나 소모 (달리는 중)
```
Stamina Drain/초 = 25 × max( 40 × (1 + armorSpeed/10) × (100 − SlowerStaminaDrain)/100 , 1 ) / 256
```
- 범위: **0.0977 ~ 7.8125 /초**.
- **Medium 갑옷은 스태미나 소모 +50%** (Medium 방패는 영향 없음). 무거운 갑옷일수록 소모↑.

출처: [Run/Walk Mechanics — Maxroll](https://maxroll.gg/d2/resources/run-walk-mechanics), [Faster Run Walk — Diablo Wiki](https://diablo2.diablowiki.net/Faster_Run_Walk), [FRW — Basin Wiki](https://www.theamazonbasin.com/wiki/index.php/Faster_Run/Walk)

> **구현 함의:** 이동속도 = `baseSpeed + EffFRW×0.06 − armorPenalty`. 스태미나는 위 공식으로 매초 감소, 0이면 걷기 강제. FRW는 브레이크포인트 처리 불필요(연속값).

---

## 2. 보석 슬롯별 스탯 (Perfect 기준) · P5

Perfect 보석 착용 요구레벨 = **Clvl 18**. 슬롯에 따라 효과가 완전히 달라짐:

| 보석 | 무기 | 방패 | 투구/갑옷 |
|------|------|------|-----------|
| **Amethyst** | +150 AR | +30 Defense | +10 Strength |
| **Diamond** | +68% vs 언데드, +100 AR | +19% 모든 저항 | +100 AR |
| **Emerald** | 29 독뎀(1초) | +40% 독저항 | +10 Dexterity |
| **Ruby** | +15–20 화염뎀 | +40% 화염저항 | +38 최대 Life |
| **Sapphire** | +10–14 냉기뎀(3초) | +40% 냉기저항 | +38 최대 Mana |
| **Topaz** | +1–40 번개뎀 | +40% 번개저항 | **+24% MF** |
| **Skull** | 생명 4%·마나 3% 흡수 | 공격자 20뎀 반사 | +5 Life회복, 19% 마나재생 |

- 하위 등급(Chipped~Flawless)은 위 값의 비례 축소판. 큐브로 3개→1등급 상승(Part 3 §3.2).
- 대표 활용: 투구 Topaz(MF), 갑옷 Ruby(Life), 무기 Topaz/Ruby(속성뎀), 방패 Diamond(전저항).

출처: [Gems — PureDiablo](https://www.purediablo.com/diablo-2/diablo-2-gems), [Gems — Diablo Wiki](https://diablo2.diablowiki.net/Gems)

> **구현 함의:** 보석 = `{ type, quality, statsBySlot: { weapon[], shield[], helmArmor[] } }`. 소켓 삽입 시 **아이템 슬롯 카테고리로 분기**해 해당 스탯 적용. 룬도 동일 구조(룬은 슬롯 무관 단일 스탯).

---

## 3. 용병 (Mercenary) · P8

가장 범용적인 **액트2(사막) 용병** 기준:

### 오라 (난이도별)
| 난이도 | Combat | Defensive | Offensive |
|--------|--------|-----------|-----------|
| Normal / **Hell** | Prayer | Defiance | Blessed Aim |
| Nightmare | Thorns | **Holy Freeze** | **Might** |

- 고용 시 (난이도 × 카테고리)로 오라 고정. 예: NM Defensive = Holy Freeze(적 감속) → 인기.
- **오라는 파티·소환수 전체에 적용**(범위 내).

### 레벨·장비
- 오라 레벨은 용병 레벨 따라 상승(무제한이나 hlvl 캡 98 → 실질 오라 최대 20~23).
- 공격: 전원 **Jab** 사용. 착용: **폴암/스피어/재블린 + 투구 + 갑옷**.
- **+모든 스킬 아이템**(무기/투구/갑옷)이 오라 레벨을 높임.
- **Ethereal 장비는 내구도 소모 없음** → 용병에 이더리얼 장착이 정석.

출처: [Desert Mercenary — Diablo Wiki](https://diablo.fandom.com/wiki/Desert_Mercenary), [Mercenaries — DiabloWiki](https://diablo2.diablowiki.net/Mercenaries), [Merc Guide — DiabloBytes](https://diablobytes.com/d2-resurrected/guides/mercenary-guide/)

> **구현 함의:** 용병 = `{ actType, auraByDifficulty, level, equip[weapon/helm/armor] }`. 오라는 플레이어 오라 시스템(P3 팔라딘) 재사용. 이더리얼 내구 예외 플래그 필요.

---

## 4. 도박 (Gambling) · P8

- 상점에서 미확정 아이템 구매 → 매직/레어/유니크/세트로 판별.
- **확률:** 약 **89.85% 매직 / 10% 레어 / 0.1% 세트 / 0.05% 유니크**. 유니크는 약 1/2000.
- **품질은 전적으로 도박하는 캐릭터의 Clvl로 결정.** 아이템 ilvl = Clvl −5 ~ +4.
- **영향 없는 것:** 난이도·액트·게임 인원·MF 장비 — 전부 무관.
- **비용:** Clvl 상승에 따라 증가. 단 **반지 항상 50,000 / 아뮬렛 항상 63,000**. Gheed's Fortune(유니크 참) 등만 가격 인하.

출처: [Gambling — PureDiablo](https://www.purediablo.com/diablo-2/diablo-2-gambling), [Gamble — Fextralife](https://diablo2.wiki.fextralife.com/Gamble), [Gambling — DiabloWiki](https://diablo2.diablowiki.net/Gambling)

> **구현 함의:** 도박 = `rollQuality(89.85/10/0.1/0.05)` → 해당 품질로 `ilvl=Clvl+rand(−5..+4)` 아이템 생성(접사 롤은 P4 재사용). MF·인원 무관하게 고정 확률.

---

## 5. 리서치 최종 종합 (문서 7개)

| 문서 | 축 | 핵심 |
|------|----|------|
| Part 1 | 개요·데이터 | 명중·스탯·접사·드롭/TC·면역·커뮤니티 |
| Part 2 | 데이터 | 브레이크포인트·IAS·몬스터스케일링·룬워드·레벨생성 |
| Part 3 | 데이터 | 바바리안스킬·접사테이블·큐브·액트1 |
| Part 4 | 데이터 | 6클래스스킬·베이스등급·유니크 |
| Part 5 | 공식·엔진 | 데미지·저항캡·블록·모디파이어·MF·경험치 |
| **Part 6** | **공식·보조** | **달리기/스태미나·보석슬롯·용병·도박** |

### 결론
디아블로 2 클론의 **핵심·보조 시스템 공식이 사실상 전부 문서화**되었다. 이제 남은 것은 오직 **전수 콘텐츠 데이터**(monstats/weapons/armor/uniqueitems/skills txt의 개별 수치)뿐이며, 이는 [Part 4 §4](./2026-09-19-diablo2-mechanics-research-part4.md) 방침대로 **구현 착수 시 원본 txt → JSON 임포트**로 처리하는 것이 문서화보다 정확·효율적이다.

→ **딥리서치는 완결 지점.** 다음 권장 단계는 Phase 0(프로토타입) 착수 또는 P2 전투 엔진 스펙 작성(Part 5·6이 1차 참조).
