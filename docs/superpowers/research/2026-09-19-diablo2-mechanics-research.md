# 디아블로 2 메커니즘 딥리서치

- 작성일: 2026-09-19
- 목적: [마스터 로드맵](../specs/2026-09-19-diablo2-clone-master-roadmap-design.md)의 하위 프로젝트(P2~P7, P13)가 참조할 **정확한 공식·수치·데이터 출처** 확보
- 기준 버전: Diablo II: Lord of Destruction v1.14 / D2 Resurrected
- 검증 방식: 다중 출처 교차 확인, 커뮤니티 데이터베이스(게임 파일 추출값) 인용

> **주의:** 아래 수치는 원본 게임 파일(`*.txt` MPQ 데이터)에서 커뮤니티가 추출한 값이다. 실제 구현 시 각 하위 프로젝트 스펙 단계에서 1차 출처(silospen 계산기, Phrozen Keep 등)로 재검증할 것.

---

## 1. 전투 — 명중률(Chance to Hit) 공식 · P2

```
ToHit% = 200 × [AR / (AR + DR)] × [Alvl / (Alvl + Dlvl)]
```
- `AR` = 공격자 Attack Rating, `DR` = 방어자 Defense
- `Alvl` = 공격자 레벨, `Dlvl` = 방어자 레벨
- **하한 5%, 상한 95%** 로 클램프
- PvP / PvM / MvP 모두 동일 공식
- 레벨 차가 클수록 AR의 영향이 줄어듦(두 번째 항이 지배)
- **특수 케이스:**
  - `DR < 0`이면 `-DR`을 AR·DR 양쪽에 더해 DR을 0으로 만든 뒤 계산 → `ToHit = 100 × 2 × Alvl/(Alvl+Dlvl)`
  - **달리는(running) 대상에 대한 모든 명중 판정은 무시되고 100% 명중** (Defense는 걷거나 정지 시에만 유효)

출처: [To Hit Calculations (tommigustafsson)](https://tommigustafsson.narod.ru/tohit.html), [Maxroll — Hit Chance Mechanics](https://maxroll.gg/d2/resources/hit-chance-mechanics), [Diablo Wiki — Attack Rating](https://diablo-archive.fandom.com/wiki/Attack_Rating_(Diablo_II))

---

## 2. 캐릭터 속성 — Life/Mana 수치표 · P2

4대 속성: **Strength**(근접 데미지), **Dexterity**(AR·원거리 데미지·블록), **Vitality**(Life·Stamina), **Energy**(Mana).

### Life (클래스별)
| 클래스 | 기본 Life | 레벨당 | Vitality당 |
|--------|:--:|:--:|:--:|
| Amazon | 50 | 2 | 3 |
| Assassin | 50 | 2 | 3 |
| Barbarian | 55 | 2 | **4** |
| Druid | 55 | 1.5 | 2 |
| Necromancer | 45 | 1.5 | 2 |
| Paladin | 55 | 2 | 3 |
| Sorceress | 40 | 1 | 2 |

### Mana (클래스별)
| 클래스 | 기본 Mana | 레벨당 | Energy당 |
|--------|:--:|:--:|:--:|
| Amazon | 15 | 1.5 | 1.5 |
| Assassin | 25 | 1.5 | 1.75 |
| Barbarian | 10 | 1 | 1 |
| Druid | 20 | 2 | 2 |
| Necromancer | 25 | 2 | 2 |
| Paladin | 15 | 1.5 | 1.5 |
| Sorceress | 35 | 2 | 2 |

- Stamina: Vitality 1당 +1 (Assassin만 +1.25)
- **함의:** Barbarian은 Vitality 효율 최고(4), Sorceress는 기본 Mana 최고(35). 클래스별 파생스탯 계수는 데이터 테이블로 분리 관리해야 함.

출처: [Maxroll — Life & Mana Mechanics](https://maxroll.gg/d2/resources/life-mana-mechanics), [Diablo Wiki — Character Attributes](https://diablo.fandom.com/wiki/Character_Attributes)

---

## 3. 아이템 접사(Affix) 시스템 · P4

### 레벨 개념
- **ilvl (item level):** 드롭 시 결정. 보통 몬스터의 Mlvl과 같음.
- **qlvl (quality level):** 베이스 아이템 종류별 고유값.
- **maglvl (magic level):** 일부 베이스가 가진 접사 레벨 보너스.
- **alvl (affix level):** ilvl·qlvl·maglvl로 산출되며, **어떤 접사가 등장 가능한지 결정**. 보통 ilvl이 alvl 상한.
- **rlvl (required level):** 대체로 alvl의 75% (예외 있음).

### 등급별 접사 수
| 등급 | 접사 규칙 |
|------|-----------|
| Magic | prefix 0~1 + suffix 0~1 (총 1~2개). 확률: 접미사만 50% / 접두사만 25% / 둘 다 25%. ilvl 65 초과 무기·방어구는 항상 2개 |
| Rare | prefix 최대 3 + suffix 최대 3 (같은 family에서 1개씩만) |
| Set / Unique | 고정 스탯(접사 롤 아님) |

- 접사는 **group(family)** 으로 묶이며 같은 그룹에서 중복 불가.
- 각 접사는 자체 스탯 범위·spawn 확률·해당 아이템 타입 제한을 가짐.

출처: [Item Affixes — Project Diablo 2 Wiki](https://projectdiablo2.miraheze.org/wiki/Item_Affixes), [Affixes — Diablo Wiki](https://diablo-archive.fandom.com/wiki/Affixes_(Diablo_II)), [Affix generation — PlanetDiablo](https://planetdiablo.eu/diablo2/itemdb/affix_info_en.php)

---

## 4. 드롭 — 트레저 클래스(TC) & NoDrop · P6

- 각 몬스터는 **Treasure Class**에 연결(`TreasureClassEx.txt`). TC는 드롭 가능한 아이템 풀을 정의하고, 고레벨 몬스터일수록 상위 TC.
- **Picks:** 게임은 TC에서 여러 번(Picks 컬럼) 뽑음. 매 뽑기마다 NoDrop(무드롭) 확률 존재.
- **확률식:** 각 선택지 확률 = `X / Sum`, `X`는 Item1~Item10의 Prob 값 또는 NoDrop 값, `Sum = NoDrop + Prob1..Prob10`.
- **조건부:** NoDrop 확률이 `z`일 때, 드롭이 결정된 경우 특정 아이템 확률 = `p / (1 - z)`.
- **순서:** ① 드롭 여부 판정 → ② TC 타고 내려가며 무엇이 드롭될지 결정.
- **플레이어 수:** 인원이 많을수록 NoDrop 감소 → 전체 드롭 증가.

→ 구현 시 TC를 **재귀적 트리**로 모델링. 정확 확률 검증엔 [silospen Drop Calculator](https://dropcalc.silospen.com/) 활용.

출처: [Item Generation Tutorial — Diablo Wiki](https://diablo2.diablowiki.net/Item_Generation_Tutorial), [NoDrop 동작 — Phrozen Keep](https://d2mods.info/forum/viewtopic.php?t=67310), [silospen Drop Calculator](https://dropcalc.silospen.com/)

---

## 5. 소켓·보석·룬워드·큐빙 · P5

### 룬워드
- 특정 **룬 순서**를 알맞은 베이스(소켓 수 일치)에 정확한 순서로 삽입 시 추가 보너스 발동.
- 예) **Enigma** = Jah + Ith + Ber (3소켓 body armor).
- 룬워드는 (필요 룬 시퀀스, 허용 아이템 타입, 최소 소켓 수, 부여 스탯) 데이터로 정의.

### 호라드릭 큐브
- 기능: 아이템 조합/제작, **룬 업그레이드**, 젬 업그레이드, 소켓 생성, 보스 포탈, 수리 등.
- **룬 업그레이드:** 하위 룬은 동일 룬 3개 → 상위 1개. 중상위 룬은 동일 룬 3개 + 특정 젬 필요.
- 레시피 DB: D2R v3.3 기준 / 미지정 시 v1.14 LoD 기준.

출처: [Horadric Cube Recipes — Diablo Wiki](https://diablo2.diablowiki.net/Horadric_Cube_Recipes), [All Cube Recipes — diablo2.io](https://diablo2.io/recipes/), [Windows Central — Cube Recipes](https://www.windowscentral.com/diablo-2-resurrected-horadric-cube-recipes)

---

## 6. 스킬 시너지 · 저항 · 면역 · P3/P7

### 시너지
- LoD 패치로 도입. 한 스킬에 포인트 투자 시 **다른 스킬의 데미지/효과도 증가**.
- **하드 포인트만 시너지 적용** — 아이템의 +스킬 보너스는 시너지에 기여하지 않음.

### 저항·면역
- **저항 99% 초과 = 해당 속성 면역.**
- **깨지지 않는 면역 임계:** 3속성 144, 물리 124(D2R)/120(LoD), 독 114.
- **면역 깨기:** Conviction·Lower Resist만 가능하며, 면역 대상엔 **효과가 1/5로 감소**.
  - Lower Resist 최대 -70%, Conviction 최대 -150%. 일부 면역은 둘 다 필요.
  - 둘이 함께 있으면 합산 후 적용(둘 다 1/5 적용).

출처: [Synergies — Diablo Wiki](https://diablo.fandom.com/wiki/Synergies), [Maxroll — Immunities](https://maxroll.gg/d2/resources/immunities), [Resistance — Diablo Wiki](https://diablo2.diablowiki.net/Resistance), [Lower Resist — Diablo Wiki](https://diablo-archive.fandom.com/wiki/Lower_Resist_(Diablo_II))

---

## 7. 커뮤니티 · 참고 소스 검토 (거래 시스템 P13 / 데이터 소스)

사용자가 지정한 소스 수집·검토 결과.

### 7.1 카오스큐브 (chaoscube.co.kr) — 거래 시스템 벤치마크
국내 최대 D2/D2R/D4 커뮤니티. **거래소가 핵심.**
- **CP(카오스 포인트) 전용 화폐:** 공식 충전 1 CP = 1원. 게시글·댓글·거래 완료 등 활동으로도 적립. 등급 상승 시 쪽지 등 기능 해금.
- **거래 게시판 종류:** 소코 경매 / CP 거래 / 명품관(우수 아이템 인증) / 아이템 거래(CP 미사용). 각각 레저렉션·클래식 × 하드코어·스탠다드 × 래더·비래더로 세분화.
- **거래 흐름:** 검색 → 게시글 하단 쪽지 → 접속 시간 합의 → 게임 내 동일 모드 방에서 교환 → 사이트에서 거래 확정 버튼 → 제목 `[완료]` 표기.
- **시세 민감도:** 옵션 수치 1 차이로 가격 급변. 예) 애니참 20/20/10 = 38,500 CP vs 20/20/8 = 4,200 CP. 평균 시세보다 5~10% 저렴하게 제시 시 성사율↑.

> **P13 설계 함의:** 모바일 거래 시스템은 (a) 아이템 옵션 수치 기반 정밀 시세, (b) 전용 포인트 화폐, (c) 안전 거래 확정 단계, (d) 등급/평판 시스템을 참고. 단 원본은 "게임 밖 수동 중개(쪽지+게임 내 교환)" 구조 → 우리 클론은 **게임 내 자동 에스크로 거래**로 개선 가능.

출처: [카오스큐브](https://www.chaoscube.co.kr/), [사용법 정리](https://today.niceyk13.com/67), [거래 방법 가이드](https://whitejerry.com/posts/item/디아블로2-아이템-거래)

### 7.2 디아블로2 인벤 (diablo2.inven.co.kr) — 데이터베이스 참고
국내 종합 DB·커뮤니티. 우리 아이템/스킬/TC 데이터 구조 벤치마크로 유용.
- **DB/도구:** 아이템 DB, **스킬 시뮬레이터**, 거래소, 퀘스트 가이드, **TC(보물 클래스) 정보**, **큐빙 공식**.
- **커뮤니티:** 정보/공략, 거래(래더·스탠다드·하드코어), 파티 모집, 8직업별 게시판, 갤러리, **우버 디아블로 현황**.

출처: [디아블로2 인벤](https://diablo2.inven.co.kr/)

### 7.3 r/diablo2 (레딧) — 글로벌 커뮤니티 규모
- 개설 2009-04-20, **구독자 182,463명**, 인덱싱 게시물 1,889개 (reddapi 무료 통계 기준. 감정·인기글·인플루언서 등 상세는 유료).
- 직접 fetch는 차단됨 → 통계는 reddapi.dev 경유 확인.

출처: [reddapi — r/diablo2 insights](https://reddapi.dev/subreddits/diablo2/insights)

---

## 8. 추가 조사 필요 (후속 스펙 단계에서 1차 출처로 심화)

각 하위 프로젝트 착수 시 아래를 정밀 확보:
- **IAS/FCR/FHR/FBR 브레이크포인트 테이블** (애니메이션 프레임 단위, 클래스·무기별) — P2/P3
- **접사(prefix/suffix) 전체 테이블** (스탯 범위·spawn 확률·alvl 요구) — P4
- **룬워드 전체 목록**(~80종) 및 각 스탯 — P5
- **호라드릭 큐브 레시피 전체** — P5
- **몬스터 스탯 전체**(Life/AR/Defense/저항, 난이도·인원수 스케일링 계수) — P7
- **클래스별 스킬 데이터**(레벨당 계수·시너지 관계·마나코스트) — P3
- **랜덤 레벨 생성 알고리즘**(프리셋 타일 조각 + 랜덤 연결 방식) 상세 — P1

권장 1차 출처: Phrozen Keep(d2mods.info, 게임 파일 스펙), silospen 계산기, Project Diablo 2 Wiki, Maxroll, Diablo Wiki(diablowiki.net).
