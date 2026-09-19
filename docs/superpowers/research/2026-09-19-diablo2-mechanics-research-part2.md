# 디아블로 2 메커니즘 딥리서치 — Part 2 (심화)

- 작성일: 2026-09-19
- 목적: [Part 1](./2026-09-19-diablo2-mechanics-research.md) §8 "추가 조사 필요" 항목 심화
- 기준: D2 LoD v1.14 / D2R (v3.3 값이 섞인 출처는 표기)
- 다루는 항목: 브레이크포인트 / 공격속도(IAS) / 몬스터 스케일링 / 룬워드 목록 / 레벨 생성 알고리즘

> **정확도 주의:** 아래 수치 상당수는 커뮤니티 2차 집계 출처다. 특히 §4 룬워드의 **효과 요약값은 근사치**이며, 구현 시 각 스탯의 정확 롤 범위는 1차 DB([d2runewizard](https://d2runewizard.com/runewords), [diablo2.io](https://diablo2.io/runewords/))로 재검증할 것.

---

## 1. 브레이크포인트 (FCR / FHR / FBR) · P2/P3

### 기본 메커니즘
- 게임은 **25 FPS**. 모든 액션은 정수 프레임 소비, 프레임은 분할 불가 → 속도 향상은 **1프레임 단위로만** 체감됨.
- 각 브레이크포인트 = 애니메이션이 1프레임 줄어드는 지점(= 0.04초 단축).
- **감쇄 공식(EFCR 예):** `EFCR = floor(FCR × 120 / (FCR + 120))` — 수확체감. (스탯별 상수는 다름)

### FCR (Faster Cast Rate)
**Sorceress (일반 스펠)**
| FCR% | 프레임 |
|---|---|
| 0 | 13 |
| 9 | 12 |
| 20 | 11 |
| 37 | 10 |
| 63 | 9 |
| 105 | 8 |
| 200 | 7 |

- **Sorceress Lightning/Chain Lightning(느린 프레임):** 0→19, 20→17, 35→15 (별도 테이블)
- **Barbarian FCR:** 0→13, 9→12, 20→11, 37→10, 63→9

### FHR (Faster Hit Recovery)
| | Sorceress | Barbarian |
|---|---|---|
| 0 | 15 | 9 |
| 낮은 BP | 14 FHR→14 / 20→13 | 8→8 / 15→7 |
| 높은 BP | 42→10 / 86→8 | 27→6 |

- FHR은 **클래스별·무기별로 테이블이 크게 다름** → 클래스마다 개별 데이터 필요.

### FBR (Faster Block Rate) — Paladin 예
| FBR% | Holy Shield 없음 | Holy Shield 있음 |
|---|---|---|
| 0 | 5 프레임 | 2 프레임 |
| 13 | 4 | - |
| 32 | 3 | - |
| 86 | 2 | 1 |

출처: [Maxroll — Breakpoints & Animations](https://maxroll.gg/d2/resources/breakpoints-animations), [Breakpoints — Diablo Wiki](https://diablo2.diablowiki.net/Breakpoints), [DiabloBytes BP 계산기](https://diablobytes.com/tools/breakpoints/)

> **구현 함의:** 브레이크포인트는 애니메이션 프레임 시스템의 결과물이다. 우리 클론이 25 FPS 프레임 모델을 채택하면 동일 재현 가능. 60 FPS 렌더라도 **전투 로직은 25 tick/s의 논리 프레임**으로 분리해 계산해야 원본 브레이크포인트가 성립.

---

## 2. 공격속도 (IAS) → FPA · P2

- **WSM (Weapon Speed Modifier):** 양수=느림, 음수=빠름. 무기별 고유값.
- **계산 흐름:** 무기 IAS + 장비 IAS + 스킬 IAS = 총 IAS → WSM으로 보정 → **Effective IAS(EIAS)** → 클래스·무기별 브레이크포인트 테이블에 대입 → **FPA(Frames Per Attack)**. FPA가 낮을수록 빠름.
- IAS도 수확체감(EIAS 변환)이 적용됨.

출처: [Maxroll — Attack Speed](https://maxroll.gg/d2/resources/attack-speed), [IAS 설명 — mannm.org](https://www.mannm.org/d2library/faqtoids/ias_eng.html), [diablo2.io 공속 계산기](https://diablo2.io/attackspeed.php)

---

## 3. 몬스터 스케일링 (인원수 · 난이도) · P7

### 플레이어 수 (`/players X`)
- **몬스터 Life(v1.10+):** `HP = X_base × (n + 1) / 2` (`n`=플레이어 수, 1~8; 8 초과는 8로 고정).
  - 참고: v1.00~1.08은 `HP = X_base × n` (더 가팔랐음).
- **데미지:** 플레이어 1명 추가마다 몬스터 데미지 **+6.25%**.
- **경험치·드롭:** 인원↑ → 경험치↑, NoDrop↓(드롭↑). 단 **players 7과 8의 드롭률은 동일**(경험치·HP는 다름).

### 난이도 (Normal → Nightmare → Hell)
- Nightmare/Hell에서 **Monster Level·HP·방어력·경험치·데미지·명중·저항 모두 상승**.
- **몬스터 스킬 레벨:** Nightmare +3, **Hell +7**.
- **유니크 몬스터 보너스 능력:** Nightmare +1개, **Hell +2개**.
- **Immunity:** Normal 소수 → Nightmare 증가 → **Hell 거의 모든 몬스터가 하나 이상 면역**.
- **Hell 물리 저항 바닥:** 모든 몬스터 **최소 50% 물리 저항**. (유니크는 Stone Skin 접사로 +50% 추가 가능)
- Hell에서 대부분 몬스터는 자신의 "주 저항" 속성이 **99% 초과(면역)** 이며, 이는 그 몬스터가 가하는 데미지 속성과 일치하는 경향.

출처: [Player Settings — Diablo Wiki](https://diablo2.diablowiki.net/Player_Settings), [Maxroll — Player Settings](https://maxroll.gg/d2/resources/player-settings), [Arreat Summit — Monster Basics](https://classic.battle.net/diablo2exp/monsters/basics.shtml), [Maxroll — Immunities](https://maxroll.gg/d2/resources/immunities)

> **구현 함의:** 몬스터 데이터는 (baseHP, baseDmg, baseAR, baseDef, 속성별 baseResist)를 두고, **난이도·인원수 계수를 런타임 곱연산**으로 얹는 구조. 면역(저항≥100)은 별도 플래그로 취급.

---

## 4. 룬워드 목록 (대표) · P5

요구레벨(rlvl) 순. **효과는 근사 요약** — 정확 롤은 1차 DB 재검증 필요.

| 룬워드 | rlvl | 룬 순서 | 베이스 | 소켓 | 핵심 효과(요약) |
|--------|:--:|--------|--------|:--:|------|
| Steel | 13 | Tir·El | 검/도끼/메이스 | 2 | +25% 공속, 개방상처 |
| Stealth | 17 | Tal·Eth | 갑옷 | 2 | +25% 이속, FHR/마나재생 |
| Leaf | 19 | Tir·Ral | 스태프 | 2 | 화염스킬+3 |
| Ancient's Pledge | 21 | Ral·Ort·Tal | 방패 | 3 | 모든저항 +43~48% |
| Strength | 25 | Amn·Tir | 근접무기 | 2 | 생명흡수, 분쇄타격 25% |
| Spirit | 25 | Tal·Thul·Ort·Amn | 검/방패 | 4 | 모든스킬+2, FCR +25~35% |
| Lore | 27 | Ort·Sol | 투구 | 2 | 모든스킬+1, 번개저항+30 |
| Insight | 27 | Ral·Tir·Tal·Sol | 폴암/스태프 | 4 | **명상 오라**, FCR+35% |
| Honor | 27 | Amn·El·Ith·Tir·Sol | 근접무기 | 5 | 모든스킬+1, 데미지+160% |
| Rhyme | 29 | Shael·Eth | 방패 | 2 | 차단+20%, 모든저항+25 |
| Black | 35 | Thul·Io·Nef | 클럽/해머/메이스 | 3 | 분쇄타격40%, 냉기 |
| White | 35 | Dol·Io | 완드 | 2 | 독/뼈 스킬+3, FCR+20 |
| Smoke | 37 | Nef·Lum | 갑옷 | 2 | 방어력+75%, 모든저항+50 |
| Heart of the Oak | 55 | Ko·Vex·Pul·Thul | 스태프/메이스 | 4 | 모든스킬+3, FCR+40% |
| Call to Arms | 57 | Amn·Ral·Mal·Ist·Ohm | 무기 | 5 | Battle Orders 등 전투외침 스킬 |
| Grief | 59 | Eth·Tir·Lo·Mal·Ral | 검/도끼 | 5 | +340~400 데미지, 방어무시 |
| Fortitude | 59 | El·Sol·Dol·Lo | 갑옷/무기 | 4 | 데미지+300%(무기), 방어+200% |
| Infinity | 63 | Ber·Mal·Ber·Ist | 폴암 | 4 | **확신 오라**(번개면역 깨기) |
| Enigma | 65 | Jah·Ith·Ber | 갑옷 | 3 | 모든스킬+2, **순간이동**, 이속+45% |
| Breath of the Dying | 69 | Vex·Hel·El·Eld·Zod·Eth | 무기 | 6 | 영구내구, 생명흡수12~15% |

- **소켓 수 = 룬 개수**, **삽입 순서가 정확히 일치**해야 발동.
- 핵심 아키타입: Insight(명상=마나공급), Spirit(저비용 캐스터), Enigma(전클래스 텔포), Infinity/Conviction(면역깨기), Grief(근접 최강 무기).

출처: [Runewords by Level — Games Finder](https://gameslikefinder.com/article/diablo-2-runewords-by-level/), [All Runewords — d2runewizard](https://d2runewizard.com/runewords), [Runewords — diablo2.io](https://diablo2.io/runewords/), [All Runewords — Project Diablo 2](https://wiki.projectdiablo2.com/wiki/All_Runewords)

> **구현 함의:** 룬워드는 `{ 이름, 룬시퀀스[], 허용베이스타입[], 필요소켓수, 부여스탯[] }` 데이터로 정의. 소켓 삽입 시 (베이스타입·소켓수·룬순서) 3조건 매칭으로 발동 판정.

---

## 5. 랜덤 레벨 생성 알고리즘 · P1

> ⚠️ D2의 절차적 생성은 **원본 문서화가 부실**한 영역. 개발자조차 전 단계를 완전히 기억하지 못한다고 밝힘. 아래는 커뮤니티 리버스 엔지니어링 종합.

### 3가지 맵 타입
1. **Overworld** — 지상 랜덤 구역(프리셋 아님).
2. **Maze** — 랜덤 생성 던전(룸 조립).
3. **Preset** — 고정 레벨(변하지 않음). 같은 목적에 여러 프리셋 존재 가능.

### 생성 6단계
1. **맵 크기 결정** — X/Y축 최소·최대 범위 내 산출, 구역별 총면적 상한.
2. **맵 방향 결정.**
3. **경계벽 생성** — 자체 알고리즘.
4. **주요 지형지물 배치** — 던전 입구/워프 등.
5. **룸·오브젝트 채우기** — "deck of cards" 방식. 미리 만든 **~95개 룸(프리셋 청크)** 을 뽑아 조립.
6. **몬스터 배치** — 밀도 제한 기반.

### 조립 원리
- 각 타일은 **connectivity pattern(연결 패턴)** 을 갖고 제작됨.
- 같은 패턴을 가진 타일끼리 매칭해 이어붙임 → **알고리즘 복잡도는 낮고, 사실상 패턴 매칭**.
- "무작위처럼 보이지만" 실제로는 제한된 조각의 조합.

출처: [Reverse Design: Diablo 2 — Randomness](http://thegamedesignforum.com/features/RD_D2_5.html), [Randomization — DiabloWiki](https://www.diablowiki.net/Randomization), [Area Size — Diablo Wiki](https://diablo-archive.fandom.com/wiki/Area_Size_(Diablo_II)), [Dungeon Generation in Diablo 1 — BorisTheBrave](https://www.boristhebrave.com/2019/07/14/dungeon-generation-in-diablo-1/)

> **구현 함의(P1):** 우리 클론은 (a) 손수 제작한 **타일 청크 세트** + 각 청크의 **엣지 연결 패턴 메타데이터**를 두고, (b) 시드 기반으로 크기·방향 결정 → 경계 생성 → 청크를 패턴 매칭으로 조립 → 입구/워프/몬스터 배치, 순으로 근사. 완전 동일 재현보다 **"제한된 조각의 패턴 매칭 조립"이라는 철학**을 모사하는 게 현실적.

---

## 6. 남은 심화 대상 (다음 라운드)

> ✅ **바바리안 스킬·접사 대표 테이블·큐브 레시피 전체·액트1 몬스터/안다리엘**은 [Part 3](./2026-09-19-diablo2-mechanics-research-part3.md)에서 정리 완료.

- **접사 전체 테이블**(prefix/suffix별 스탯 범위·spawn weight·alvl 요구) — 방대. 1차 소스: [planetdiablo affix DB](https://planetdiablo.eu/diablo2/itemdb/affix_info_en.php), Phrozen Keep `MagicPrefix.txt`/`MagicSuffix.txt`.
- **클래스별 스킬 데이터 전체**(레벨당 계수·시너지 관계·마나코스트) — 클래스 착수 시 클래스별로.
- **호라드릭 큐브 레시피 전체 목록** — [diablo2.io/recipes](https://diablo2.io/recipes/).
- **몬스터별 스탯 원본값**(TC 연결 포함) — Phrozen Keep `monstats.txt`.
- **아이템 베이스 스탯**(qlvl·소켓 상한·내구도 등) — `weapons.txt`/`armor.txt`.

권장: 이들은 **개별 하위 프로젝트 스펙 착수 시** 해당 범위만 1차 게임 파일(`*.txt`) 기준으로 확보하는 것이 정확·효율적.
