# 디아블로 2 메커니즘 딥리서치 — Part 4 (심화 §5)

- 작성일: 2026-09-19
- 목적: [Part 3](./2026-09-19-diablo2-mechanics-research-part3.md) §5 남은 심화 대상 처리
- 다루는 항목: 나머지 6개 클래스 스킬트리 / 아이템 베이스 등급·소켓 / 대표 유니크

> **정확도 주의:** 스킬 목록·요구레벨은 2차 출처 집계. 스킬 계수·마나코스트, 아이템 베이스 전수 스탯, 유니크 고정 롤은 1차 파일(`skills.txt`, `weapons.txt`/`armor.txt`, `uniqueitems.txt`)로 재검증. 구현은 클래스·콘텐츠 착수 시점에 해당 범위만 확정.

---

## 1. 6개 클래스 스킬트리 (P3 확장)

각 클래스 3트리 × 10스킬 = 30스킬. (바바리안은 [Part 3 §1](./2026-09-19-diablo2-mechanics-research-part3.md).) 요구레벨 표기.

### Sorceress
**Cold:** Ice Bolt(1)·Frozen Armor(1)·Frost Nova(6)·Ice Blast(6)·Shiver Armor(12)·Glacial Spike(18)·Blizzard(24)·Chilling Armor(24)·**Frozen Orb**(30)·Cold Mastery(30)
**Lightning:** Charged Bolt(1)·Static Field(6)·Telekinesis(6)·Nova(12)·Lightning(12)·Chain Lightning(18)·**Teleport**(18)·Thunder Storm(24)·Energy Shield(24)·Lightning Mastery(30)
**Fire:** Fire Bolt(1)·Warmth(1)·Inferno(6)·Blaze(12)·Fire Ball(12)·Fire Wall(18)·Enchant(18)·Meteor(24)·Fire Mastery(30)·Hydra(30)
- 핵심: Static Field(적 HP %감소), Teleport(기동 필수), Cold Mastery(냉기 저항 무시). 시너지 예: Blizzard·Frozen Orb→Ice Bolt 각 +15%.

### Amazon
**Javelin & Spear:** Jab(1)·Power Strike(6)·Poison Javelin(6)·Impale(12)·Lightning Bolt(12)·Charged Strike(18)·Plague Javelin(18)·Fend(24)·Lightning Strike(30)·**Lightning Fury**(30)
**Passive & Magic:** Inner Sight(1)·Critical Strike(1)·Dodge(6)·Slow Missiles(12)·Avoid(12)·Penetrate(18)·Decoy(24)·Evade(24)·**Valkyrie**(30)·Pierce(30)
**Bow & Crossbow:** Magic Arrow(1)·Fire Arrow(1)·Cold Arrow(6)·Multiple Shot(6)·Exploding Arrow(12)·Ice Arrow(18)·Guided Arrow(18)·Strafe(24)·Immolation Arrow(24)·Freezing Arrow(30)
- 핵심: Dodge/Avoid/Evade(회피 패시브), Pierce(관통), Valkyrie(소환), Critical Strike(피해 2배 확률).

### Paladin
**Combat:** Sacrifice·Smite·Holy Bolt·Zeal·Charge·Vengeance·**Blessed Hammer**·Conversion·**Holy Shield**·Fist of the Heavens
**Offensive Auras:** Might·Holy Fire·Thorns·Blessed Aim·Concentration·Holy Freeze·Holy Shock·Sanctuary·**Fanaticism**·**Conviction**
**Defensive Auras:** Prayer·Resist Fire·Defiance·Resist Cold·Cleansing·Resist Lightning·Vigor·**Meditation**·Redemption·Salvation
- 핵심: 오라는 상시 1개(장비로 2개 가능). Conviction(적 저항↓·면역깨기), Fanaticism(공속·데미지), Meditation(마나회복—Insight 룬워드 근원), Blessed Hammer(최상위 평가 스킬), Holy Shield(블록속도 은닉 효과).

### Necromancer
**Summoning:** Raise Skeleton(1)·Skeleton Mastery(1)·Clay Golem(6)·Golem Mastery(12)·Raise Skeletal Mage(12)·Blood Golem(18)·Summon Resist(24)·Iron Golem(24)·Fire Golem(30)·Revive(30)
**Poison & Bone:** Teeth(1)·Bone Armor(1)·Poison Dagger(6)·Corpse Explosion(6)·Bone Wall(12)·Poison Explosion(18)·Bone Spear(18)·Bone Prison(24)·Poison Nova(30)·Bone Spirit(30)
**Curses:** Amplify Damage(1)·Dim Vision(6)·Weaken(6)·Iron Maiden(12)·Terror(12)·Confuse(18)·Life Tap(18)·Attract(24)·Decrepify(24)·Lower Resist(30)
- 핵심: Corpse Explosion(시체 폭발—광역 핵심), Lower Resist/Amplify Damage(저주), Bone Spear/Spirit(마법 데미지—면역 우회), Iron Golem(장비 소환).

### Druid
**Elemental:** Firestorm·Molten Boulder·Arctic Blast·Fissure·Cyclone Armor·Twister·Volcano·**Tornado**·Armageddon·**Hurricane**
**Shape Shifting:** Werewolf·Lycanthropy·Werebear·Feral Rage·Maul·Rabies·Fire Claws·Hunger·Shock Wave·**Fury**
**Summoning:** Raven·Poison Creeper·**Oak Sage**·Summon Spirit Wolf·Carrion Vine·Heart of Wolverine·Summon Dire Wolf·Solar Creeper·Spirit of Barbs·**Summon Grizzly**
- 핵심: Wind 스킬(Tornado/Hurricane—물리 데미지라 면역 회피 유리), 변신(Werewolf/Werebear 근접), Oak Sage(생명력 토템).

### Assassin
**Martial Arts:** Tiger Strike(1)·Dragon Talon(1)·Fists of Fire(6)·Dragon Claw(6)·Cobra Strike(12)·Claws of Thunder(18)·Dragon Tail(18)·Blades of Ice(24)·Dragon Flight(24)·**Phoenix Strike**(30)
**Shadow Disciplines:** Claw Mastery(1)·Psychic Hammer(1)·**Burst of Speed**(6)·Cloak of Shadows(12)·Weapon Block(12)·**Fade**(18)·Shadow Warrior(18)·Mind Blast(24)·Venom(30)·**Shadow Master**(30)
**Traps:** Fire Blast(1)·Shock Web(6)·Blade Sentinel(6)·Charged Bolt Sentry(12)·Wake of Fire(12)·Blade Fury(18)·**Lightning Sentry**(18)·Wake of Inferno(24)·**Death Sentry**(24)·Blade Shield(30)
- 핵심: 무술은 **차징(charge-up)** 후 방출 구조(Phoenix Strike), Traps는 자동 발사 설치물(Lightning/Death Sentry가 엔드게임), Burst of Speed/Fade(버프), Shadow Master(소환).

출처: [Sorceress](https://www.warcrafttavern.com/d2/classes/sorceress/sorceress-skills/) · [Amazon](https://www.warcrafttavern.com/d2/classes/amazon/amazon-skills/) · [Paladin](https://www.warcrafttavern.com/d2/classes/paladin/paladin-skills/) · [Druid](https://www.warcrafttavern.com/d2/classes/druid/druid-skills/) · [Assassin](https://www.warcrafttavern.com/d2/classes/assassin/assassin-skills/) — Diablo Tavern; [Necromancer — Fextralife](https://diablo2.wiki.fextralife.com/Necromancer+Skills)

> **구현 함의:** 7클래스 × 30스킬 = 210스킬을 **공통 스킬 인터페이스** 하나로 추상화(패시브/오라/차징/설치물/소환/발사체/근접 등 behavior 타입). 스킬은 데이터(behavior + 계수함수 + 시너지목록)로, 로직은 behavior 핸들러로 분리해야 관리 가능.

---

## 2. 아이템 베이스 등급 & 소켓 (P4/P5)

### 3단계 품질 등급
- **Normal → Exceptional → Elite.** 상위 등급일수록 기본 스탯↑, 최대 소켓↑, 대신 **힘/민첩 요구치↑**.
- 같은 "아이템 종류"가 세 등급 버전을 가짐(예: 무기·방어구 계열별).
- **qlvl(quality level):** 베이스 종류별 고유. 드롭 판정·소켓 수 산정에 관여.

### 소켓 상한 규칙 (방어구 예)
- **Normal/Nightmare 드롭:** 최대 3소켓.
- **Hell 드롭:** 최대 4소켓.
- 단, **해당 아이템 종류가 허용하는 상한**을 넘지 못함(대부분 elite body armor는 4가 상한).
- 실제 소켓 수 = f(qlvl, ilvl, 소켓팅 방법[드롭/Larzuk 퀘스트/큐브]).

출처: [Item Quality — Diablo Wiki](https://diablo-archive.fandom.com/wiki/Item_Quality_(Diablo_II)), [Item Bases — PD2 Wiki](https://wiki.projectdiablo2.com/wiki/Item_Bases), [Socket Guide — DiabloBytes](https://diablobytes.com/d2-resurrected/guides/socket-guide/), [Base Items — diablo2.io](https://diablo2.io/base/)

> **구현 함의:** 베이스 = `{ name, tier(N/E/E), category, qlvl, baseMin/Max(무기뎀 or 방어력), maxSockets, reqStr, reqDex, speed(WSM) }`. 룬워드/소켓 시스템(P5)은 이 maxSockets·category와 직접 연동.

---

## 3. 대표 유니크 아이템 (P4/P6)

전체 유니크·세트는 수백 종 → 1차 DB([diablo2.io/uniques](https://diablo2.io/uniques/)) 참조. 아래는 아키타입 예시.

### Harlequin Crest (Shako) — 만능 유니크의 표본
- 베이스: Shako. 효과: **+2 모든 스킬**, 레벨당 Life·Mana 증가, **물리 피해 감소 10%**, **자석찾기(MF) 50%**.
- 캐스터·소환·근접 모두 채용하는 범용 최상급 투구 → "고정 스탯 유니크"의 대표.

### 엔드게임 상시 채용 예
Mara's Kaleidoscope(아뮬렛: +2 스킬·전저항), Griffon's Eye(번개 캐스터 서클릿: -저항·번개뎀), Herald of Zakarum(팔라딘 방패), Crown of Ages(투구: DR·소켓), War Traveler(부츠: MF·데미지), Annihilus/Hellfire Torch(참: 전스킬·스탯·저항).
- 룬워드와 경쟁/보완: Grief·Fortitude·Heart of the Oak·Chains of Honor·Call to Arms가 상위 슬롯 지배(Part 2 §4).

출처: [Harlequin Crest — diablo2.io](https://diablo2.io/uniques/harlequin-crest-t37.html), [Harlequin Crest — Diablo Wiki](https://diablo2.diablowiki.net/Harlequin_Crest), [Best D2R Items](https://www.d2itemstore.com/collections/best-d2r-items)

> **구현 함의:** 유니크/세트 = `{ name, baseItem, fixedStats[{stat,min,max}], qlvl, dropRestriction }`. 접사 롤링과 달리 **고정 스탯 리스트**(일부 범위 롤). 세트는 추가로 `setBonus[착용수→효과]`. 데이터 주도로 `uniqueitems.txt`/`setitems.txt` 구조 이식.

---

## 4. 리서치 종합 상태

| 문서 | 커버 범위 |
|------|-----------|
| Part 1 | 명중공식·캐릭터스탯·접사개념·드롭/TC·룬워드/큐브개요·저항면역·커뮤니티소스 |
| Part 2 | 브레이크포인트·IAS·몬스터스케일링·룬워드20종·레벨생성 |
| Part 3 | 바바리안스킬·접사대표테이블·큐브레시피전체·액트1/안다리엘 |
| Part 4 | 6클래스스킬(총210스킬맵)·아이템베이스등급/소켓·대표유니크 |

### 남은 1차-파일 전수 작업 (구현 착수 시 범위별로)
- `monstats.txt` 몬스터 전수 스탯 · `weapons.txt`/`armor.txt` 베이스 전수 · `uniqueitems.txt`/`setitems.txt` 전수 · 클래스별 `skills.txt` 계수·마나 · 접사 `spawnWeight`.
- 이는 문서화보다 **구현 시 데이터 임포트**(원본 txt 구조를 JSON으로 이식)가 정확·효율적. → 각 하위 프로젝트 스펙에서 "게임 데이터 임포트" 태스크로 편성 권장.
