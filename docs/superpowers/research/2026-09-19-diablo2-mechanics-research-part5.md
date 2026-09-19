# 디아블로 2 메커니즘 딥리서치 — Part 5 (핵심 전투/수학 공식)

- 작성일: 2026-09-19
- 목적: 구현 직결 공식 확보 — 전수 데이터가 아닌 **엔진 로직**에 필요한 계산식
- 다루는 항목: 물리 데미지 / 데미지 캡 / 블록 / 전투 모디파이어 / 매직파인드 / 경험치
- 주 대상 하위 프로젝트: **P2(전투 코어)**, P6(드롭/MF), P8(엔드게임)

> 이 문서는 Part 1~4가 다룬 "무엇을(데이터)"과 달리 **"어떻게 계산하는가(공식)"** 를 모은다. P2 전투 엔진 스펙의 1차 참조.

---

## 1. 물리 데미지 계산 · P2

계산은 **버킷(bucket) 구조** — 두 종류 ED가 다른 방식으로 적용된다.

```
1) 베이스 무기 데미지  = 무기 종류별 min~max (예: Dagger 1~4)
2) On-Weapon ED (local): 무기 자체의 +%ED (superior 최대 +15% 포함)
   → 무기데미지 × (1 + onWeaponED/100)
3) Off-Weapon ED (global 버킷): Str/Dex 데미지보너스 + 스킬 %ED
   + 오라 %ED + 비무기 장비 %ED + (해당 시)Demon/Undead 보너스
   → 이 모두를 "더한 뒤" 한꺼번에 곱함
```

- **핵심:** On-Weapon ED는 무기데미지에 먼저 곱해지고, **Off-Weapon ED들은 하나의 버킷에 가산(additive)된 후 곱**해진다. (그래서 스킬 %ED와 장비 %ED는 서로 곱연산이 아니라 합연산)
- **Str/Dex → %데미지:** 근접은 Strength, 특정 무기는 Dexterity가 %데미지 보너스로 환산되어 Off-Weapon 버킷에 들어감.

출처: [Damage Calculation — Maxroll](https://maxroll.gg/d2/resources/damage-calculation), [Damage Bonus — Diablo Wiki](https://diablo2.diablowiki.net/Damage_Bonus), [How Is Damage Calculated — d2runewizard](https://d2runewizard.com/articles/mechanics/damage-calculation), [physical damage — mannm.org](https://www.mannm.org/d2library/faqtoids/physd_eng.html)

> **구현 함의:** 데미지 파이프라인을 `baseMin/Max → ×(1+localED) → +flatMin/Max → ×(1+Σ offWeaponED)` 순서의 명시적 단계로 구현. 두 ED 버킷을 반드시 분리.

---

## 2. 데미지 감소·저항 캡 · P2

| 메커니즘 | 기본 캡 | 비고 |
|----------|--------|------|
| 원소 저항 (화/냉/번/독) | **75%** | 유니크/스킬로 최대 **95%** 상향 가능 |
| 물리 피해 감소(PDR %) | **50%** | 어떤 효과로도 초과 불가 |
| % Absorb (원소 흡수) | **40%** | 초과분 무의미. 단 **정수(integer) absorb**는 별도로 소량 원소뎀을 0으로/회복 가능 |

- 난이도별 캐릭터 저항 페널티: (Part 1 참조) Normal 0 / Nightmare −40 / Hell −100 이 저항에서 차감됨 → Hell에서 저항 유지가 핵심.

출처: [Damage Reduction — Diablo Wiki](https://diablo-archive.fandom.com/wiki/Damage_Reduction_(Diablo_II)), [Damage Reductions — Maxroll](https://maxroll.gg/d2/resources/damage-reductions), [Resistances — Diablo Wiki](https://diablo.fandom.com/wiki/Resistances)

> **구현 함의:** 데미지 수신 계산 = `dmg × (1 − min(resist,cap)/100) × (1 − min(PDR,50)/100) − flatReduce`, 이후 absorb 적용. 각 캡을 상수로 분리하고 max-resist 상향 아이템은 캡 변수를 수정.

---

## 3. 블록 확률 · P2

```
Total Block% = (shieldBlock × (Dex − 15)) / (cLvl × 2)     [최대 75%]
```
- `shieldBlock` = 방패 기본 블록 + 아이템/Holy Shield 보너스.
- **클래스 기본 블록:** Druid/Necro/Sorc **20%**, Amazon/Barb/Assassin **25%**, Paladin **30%**. (실제 방패 표기값에 반영됨)
- **75% 블록에 필요한 Dex 역산:** `Dex = (150 × cLvl) / shieldBlock표기값 + 15`
- 달리는 중엔 블록 판정이 다르게 작동(Part 1 §1의 명중 무시와 연동).

출처: [Block Mechanics — Maxroll](https://maxroll.gg/d2/resources/block-mechanics), [Blocking — Diablo Wiki](https://diablo2.diablowiki.net/Blocking), [Blocking Chance — mannm.org](https://www.mannm.org/d2library/faqtoids/block_eng.html)

> **구현 함의:** 블록은 clvl·dex 종속이라 레벨업 시 재계산 필요. FBR 브레이크포인트(Part 2 §1)와 함께 블록 애니메이션 프레임도 처리.

---

## 4. 전투 모디파이어 · P2

### Crushing Blow (분쇄 타격) — 대상 **현재 체력**의 일정 비율 감소
| 대상 | 근접 | 원거리 |
|------|:--:|:--:|
| 일반 몬스터 | 1/4 | 1/8 |
| 챔피언/유니크/보스 | 1/8 | 1/16 |
| 플레이어/용병 | 1/10 | 1/20 |
- 현재 체력 기준이라 **고체력일수록 효과 큼**, 체력 낮아질수록 감소.

### Deadly Strike / Critical Strike
- **물리 데미지 2배** 확률. 여러 소스의 %가 **합산**. 오프핸드 무기의 %는 그 무기로 공격할 때만 적용. (Amazon Critical Strike도 같은 "2배" 계열)

### Open Wounds (개방 상처)
- 지속 출혈 데미지. 멜리 스플래시로 여러 적 타격 시 **각 적마다 개별 롤**.

### Life/Mana Leech (흡혈/흡마)
```
Leech = 물리데미지 × Leech% × Penalty × DrainEffectiveness
```
- `Leech%` = 모든 "% Life stolen" 합. `Penalty` = **난이도별 흡혈 페널티**(Nightmare/Hell에서 감소). `DrainEffectiveness` = 몬스터별 흡혈 효율.

출처: [Attack Modifiers — Maxroll](https://maxroll.gg/d2/resources/attack-modifiers), [Combat — Fextralife](https://diablo2.wiki.fextralife.com/Combat), [Crushing Blow — Diablo Wiki](https://diablo.fandom.com/wiki/Crushing_Blow)

> **구현 함의:** 각 모디파이어는 명중 후 데미지 파이프라인의 **후처리 훅**으로: Deadly Strike(데미지×2 롤) → 기본뎀 적용 → Crushing Blow(현재HP 비례 추가) → Open Wounds(DoT 부여) → Leech(피해량 기반 회복). 난이도 페널티 상수 분리.

---

## 5. 매직 파인드 수확체감 · P6

MF는 **레어/세트/유니크마다 다른 감쇄 공식** 적용 (magic/일반엔 감쇄 없음):
```
유니크: EffMF = (MF × 250) / (MF + 250)
세트  : EffMF = (MF × 500) / (MF + 500)
레어  : EffMF = (MF × 600) / (MF + 600)
```
- 예: 500% MF → 유니크 유효 약 **166%**. 1000% MF → 약 200%.
- 0~100% 구간은 거의 선형(1점당 큰 효과), 100~250%도 유효, 이후 급감.
- **MF 자체 상한은 없음**(감쇄만 존재). 약 200%부터 체감 감소.

출처: [MF Diminishing Returns — Diablo Wiki](https://diablo2.diablowiki.net/Magic_find_diminishing_returns), [MF DR — PureDiablo](https://www.purediablo.com/diablo-2/magic-find-diminishing-returns), [MF Guide — DiabloBytes](https://diablobytes.com/guides/magic-find/)

> **구현 함의:** 드롭 결정(Part 1 §4 TC) 단계에서 아이템 품질 롤 시 위 EffMF를 품질별로 적용. MF는 곱연산이 아니라 **품질 상승 확률 가중치**로 작동.

---

## 6. 경험치 & 레벨 · P2/P8

### 레벨 차 페널티
- 몬스터-캐릭터 **레벨차 ≤5**: 경험치 100%.
- **레벨차 ≥10**: 경험치 5%로 급감(몬스터가 10+ 높으면 캐릭터가 얻는 건 2% 수준).

### 고레벨 페널티 (레벨 70+)
- 70레벨부터 획득 경험치에 추가 페널티. **70렙 ≈95.31%**, 98렙 ≈0.59%까지 감소 → 후반 레벨업 극도로 느림.

### 사망 페널티
- 다음 레벨까지 필요 경험치의 **Nightmare 5% / Hell 10%** 상실. **경험치 손실로 레벨 하락은 없음**.

### 엔드게임 파밍 (Area Level 85)
- **alvl 85 = 일반 몬스터가 스폰하는 최고 지역 레벨.** 최고 TC 접근 → 파밍 명소.
- 풀 경험치: 일반몹 ~Lv90, 챔피언 ~Lv92, 유니크몹 ~Lv93까지. → **85~90레벨대 파밍에 최적.**

출처: [Experience — PureDiablo](https://www.purediablo.com/diablo-2/diablo-2-experience), [Experience — Diablo Wiki](https://diablo2.diablowiki.net/Experience), [D2R XP Chart](https://www.vhpg.com/d2r-experience/)

> **구현 함의:** 경험치 분배 = `기지경험 × 레벨차계수 × 파티계수 × 고레벨페널티`. alvl은 레벨 생성(P1)·드롭(P6)·경험치(P2) 모두가 참조하는 핵심 파라미터 → 구역 정의에 `areaLevel` 필드 필수.

---

## 7. 리서치 종합 (최종)

| 문서 | 축 | 핵심 |
|------|----|------|
| Part 1 | 데이터·개요 | 명중·스탯·접사개념·드롭/TC·면역·커뮤니티소스 |
| Part 2 | 데이터·심화 | 브레이크포인트·IAS·몬스터스케일링·룬워드·레벨생성 |
| Part 3 | 데이터·심화 | 바바리안스킬·접사테이블·큐브레시피·액트1 |
| Part 4 | 데이터·심화 | 6클래스스킬(210맵)·베이스등급·유니크 |
| **Part 5** | **공식·엔진** | **데미지·저항캡·블록·모디파이어·MF·경험치** |

→ **전투 엔진(P2) 구현에 필요한 계산식이 사실상 완비.** 남은 것은 각 하위 프로젝트 착수 시 1차 txt 데이터 임포트(Part 4 §4).

> ✅ 아래 보조 공식은 [Part 6](./2026-09-19-diablo2-mechanics-research-part6.md)에서 정리 완료.

### 아직 공식 보강 여지 (필요 시 다음 라운드)
- Faster Run/Walk·Stamina 소모 공식
- 원소/마법 데미지의 스킬 계수 구조(스킬레벨→뎀 함수)
- 도박(Gambling) 유니크/세트 확률
- 용병(Mercenary) 레벨·오라·장비 규칙
- 보석(Gem) 슬롯별(무기/방어구/방패/투구) 스탯 전표
