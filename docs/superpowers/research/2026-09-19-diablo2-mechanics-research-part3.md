# 디아블로 2 메커니즘 딥리서치 — Part 3 (심화 §6)

- 작성일: 2026-09-19
- 목적: [Part 2](./2026-09-19-diablo2-mechanics-research-part2.md) §6 남은 심화 대상 처리
- 로드맵 우선순위 반영: 첫 클래스=**바바리안**, 첫 콘텐츠=**액트1**
- 다루는 항목: 바바리안 스킬 / 접사(대표) / 호라드릭 큐브 레시피(전체) / 액트1 몬스터·안다리엘

> **정확도 주의:** 스탯 범위·마나코스트 등은 2차 출처 집계값. 구현 시 1차 게임 파일(`skills.txt`, `MagicPrefix/Suffix.txt`, `cubemain.txt`, `monstats.txt`)로 재검증. RotW(Reign of the Warlock) 표기 항목은 **클래식 LoD가 아닌 D2R 신규 콘텐츠**이므로 정통 클론에서는 제외 대상.

---

## 1. 바바리안 스킬 (P3, 첫 클래스)

3개 스킬트리 × 10스킬 = 30스킬. 하드포인트만 시너지 적용(Part 1 §6).

### Combat Masteries (전투 숙련)
Blade Mastery · Axe Mastery · Mace Mastery · Polearm Mastery · Throwing Mastery · Spear Mastery · Increased Stamina · Iron Skin · Increased Speed · Natural Resistance
- Mastery류: 해당 무기군 데미지·명중·크리티컬(Deadly Strike) 증가. **패시브.**
- Iron Skin(방어력), Natural Resistance(모든 저항), Increased Speed(이동속도), Increased Stamina(스태미나+Frenzy 지속).

### Combat Skills (전투 스킬)
Bash · Leap · Double Swing · Stun · Double Throw · Leap Attack · Concentrate · Frenzy · Whirlwind · Berserk
- **Whirlwind**: 대표 엔드게임 스킬(회전 다단히트).
- **Frenzy**: 연타로 이동·공속 버프 누적.
- **Berserk**: 마법 데미지 전환 + 방어무시(대신 자기 방어력 0).
- 마나 특이점: **Double Swing은 6렙에서 마나코스트 ≈0, 9렙 이상은 오히려 마나 회복**.

### Warcries (전쟁 외침)
Howl · Taunt · Shout · Battle Cry · Battle Orders · Grim Ward · War Cry · Battle Command
- **Battle Orders(BO)**: 파티 전체 **최대 Life/Mana/Stamina 증가** — 바바리안 필수 유틸.
- **Shout**: 방어력 버프. **Battle Command**: 모든 스킬 +1(일시).
- **War Cry**: 광역 스턴+물리 데미지. Howl(공포), Taunt(도발), Grim Ward(공포 토템).

### 시너지 예시 (하드포인트 기준)
- Bash → Double Swing에 +10% 데미지
- Double Swing → Frenzy에 +8% 데미지
- Increased Stamina → Frenzy 지속시간 증가
- (Whirlwind 빌드 정석: Mastery 20 + BO 20 + Battle Command 1 + Shout 1)

출처: [Barbarian Skills — Diablo Tavern](https://www.warcrafttavern.com/d2/classes/barbarian/barbarian-skills/), [Barbarian Skills — Fextralife](https://diablo2.wiki.fextralife.com/Barbarian+Skills), [All Barbarian Skills — PD2 Wiki](https://wiki.projectdiablo2.com/wiki/All_Barbarian_Skills), [WW Barb — Icy Veins](https://www.icy-veins.com/d2/whirlwind-barbarian-build-skills)

> **구현 함의:** 스킬 데이터는 `{ id, tree, rlvl(선행조건 포함), manaCost(lvl함수), 효과계수(lvl함수), synergies[{skillId, perLevel%}] }`. 마나코스트·계수는 대개 **스킬레벨 선형/구간 함수** → 레벨별 테이블 또는 계수식으로 관리.

---

## 2. 아이템 접사 — 대표 테이블 (P4)

전체는 방대하므로 대표군만. 각 접사: alvl(등장 가능 최소) / rlvl(착용 요구).

### Prefix — 데미지 증가 (%ED, 무기)
| 접두사 | %ED | alvl | rlvl |
|--------|-----|:--:|:--:|
| Jagged | 10–20 | 1 | 1 |
| Deadly | 21–30 | 5 | 3 |
| Vicious | 31–40 | 8 | 6 |
| Brutal | 41–50 | 14 | 10 |
| Massive | 51–65 | 20 | 15 |
| Merciless | 81–100 | 32 | 24 |
| Ferocious | 101–200 | 41 | 33 |

### Prefix — Attack Rating / 방어력 / MF
| 접두사 | 효과 | alvl | rlvl |
|--------|------|:--:|:--:|
| Bronze | +10–20 AR | 1 | 1 |
| Gold | +81–100 AR | 17 | 12 |
| Platinum | +101–120 AR | 22 | 16 |
| Sturdy | +10–30% Def | 1 | 1 |
| Blessed | +51–65% Def | 25 | 18 |
| Holy | +81–100% Def | 36 | 27 |
| Felicitous | +5–10% MF | 5 | 3 |
| Fortuitous | +11–15% MF (매직 전용) | 12 | 8 |

### Suffix — 속도 (IAS / FCR / FHR)
| 접미사 | 효과 | alvl | rlvl |
|--------|------|:--:|:--:|
| Readiness | +10% IAS | 5 | 3 |
| Alacrity | +20% IAS | 25 | 17 |
| Swiftness | +30% IAS | 34 | 26 |
| Quickness | +40% IAS | 46 | 38 |
| Apprentice | +10% FCR | 5 | 3 |
| Magus | +20% FCR | 29 | 21 |
| Balance | +10% FHR | 5 | 3 |
| Stability | +24% FHR | 18 | 13 |

### Suffix — Life / Mana
| 접미사 | 효과 | alvl | rlvl |
|--------|------|:--:|:--:|
| Jackal | +1–5 Life | 1 | 1 |
| Wolf | +11–20 Life | 15 | 11 |
| Energy | +1–3 Mana | 1 | 1 |
| Brilliance | +7–10 Mana | 13 | 9 |

출처: [Prefixes — PureDiablo](https://www.purediablo.com/diablo-2/prefixes), [Suffixes — PureDiablo](https://www.purediablo.com/diablo-2/suffixes), [Affix DB — planetdiablo](https://planetdiablo.eu/diablo2/itemdb/affix_info_en.php)

> **구현 함의:** 접사 = `{ name, group, affixType(pre/suf), stat, min, max, alvl, rlvl, allowedItemTypes[], spawnWeight, magicOnly? }`. 롤링: 아이템 ilvl→alvl 산출 → 후보 접사 필터(alvl≤아이템alvl, 타입 허용, 그룹 중복 배제) → spawnWeight 가중 추첨(Part 1 §3 등급별 개수 규칙).

---

## 3. 호라드릭 큐브 레시피 (P5, 전체)

### 3.1 룬 업그레이드
**저급(동일 룬 3개):** El→Eld→Tir→Nef→Eth→Ith→Tal→Ral (Ral 3개는 +Ort→Amn) →Sol→Shael→Dol→Hel→Io→Lum→Ko→Fal→Lem (Lem 3개 +Flawed Emerald→Pul)

**중상급(동일 룬 2개 + 보석):**
| 조합 | 결과 |
|------|------|
| Pul×2 + Flawless Diamond | Um |
| Um×2 + Flawless Topaz | Mal |
| Mal×2 + Flawless Amethyst | Ist |
| Ist×2 + Flawless Sapphire | Gul |
| Gul×2 + Flawless Ruby | Vex |
| Vex×2 + Flawless Emerald | Ohm |
| Ohm×2 + Flawless Diamond | Lo |
| Lo×2 + Flawless Topaz | Sur |
| Sur×2 + Flawless Amethyst | Ber |
| Ber×2 + Flawless Sapphire | Jah |
| Jah×2 + Flawless Ruby | Cham |
| Cham×2 + Flawless Emerald | Zod |
> (보석 등급 표기는 출처마다 상이 — 1차 `cubemain.txt` 재확인 필수)

### 3.2 보석 업그레이드
동일 종류·등급 3개 → 다음 등급. Chipped→Flawed→Normal→Flawless→Perfect. (종류: Amethyst/Topaz/Sapphire/Ruby/Emerald/Diamond/Skull)

### 3.3 소켓 추가 (일반 아이템)
| 대상 | 레시피 | 결과 소켓 |
|------|--------|:--:|
| 무기 | Ral + Amn + Perfect Amethyst | 1–6 |
| 갑옷 | Tal + Thul + Perfect Topaz | 1–4 |
| 투구 | Ral + Thul + Perfect Sapphire | 1–3 |
| 방패 | Tal + Amn + Perfect Ruby | 1–4 |

### 3.4 아이템 등급 업 (Normal→Exc→Elite)
| 대상 | Normal→Exc | Exc→Elite |
|------|-----------|-----------|
| Unique 무기 | Ral+Sol+P.Emerald | Lum+Pul+P.Emerald |
| Unique 갑옷 | Tal+Shael+P.Diamond | Ko+Lem+P.Diamond |
| Rare 무기 | Ort+Amn+P.Sapphire | Fal+Um+P.Sapphire |
| Rare 갑옷 | Ral+Thul+P.Amethyst | Ko+Pul+P.Amethyst |

### 3.5 리롤 / 소켓 정리
- 매직 리롤: 3 Perfect Gems + 매직 아이템 → 동타입 랜덤 매직
- 아뮬렛↔반지: 매직 아뮬렛3→매직 반지 / 매직 반지3→매직 아뮬렛
- 레어 리롤: 6 Perfect Skull + 레어 → 저품질 동타입 레어
- 소켓 제거(보석 반환X): **Hel + Town Portal Scroll + 소켓 아이템**

### 3.6 크래프팅 4계열
매직 아이템 + (룬 + Perfect Gem + Jewel) → 크래프티드. 계열별 고정 보너스 + 랜덤 접사:
- **Blood**(생명흡수/데미지, +P.Ruby) · **Caster**(FCR/마나, +P.Amethyst) · **Hit Power**(AR/데미지, +P.Sapphire) · **Safety**(방어/저항, +P.Emerald)

### 3.7 특수 포탈 / 퀘스트
- 소 레벨: Tome of Town Portal + Wirt's Leg
- 호라드릭 스태프: Amulet of the Viper + Staff of Kings
- 칼림의 의지: Khalim's Eye+Brain+Heart+Flail
- 우버 트리스트람: Mephisto's Brain + Baal's Eye + Diablo's Horn
- 매트론의 소굴: Key of Hate + Terror + Destruction

### 3.8 수리/포션/기타
- 무기 수리+재충전: Ort + Chipped Gem + 무기
- 갑옷 수리+재충전: Ral + Flawed Gem + 갑옷
- Rejuvenation: 3 Healing + 3 Mana + Chipped Gem (Full은 Normal Gem)

출처: [All Cube Recipes — diablo2.io](https://diablo2.io/recipes/), [Cube Recipes — Diablo Wiki](https://diablo2.diablowiki.net/Horadric_Cube_Recipes)

> **구현 함의:** 큐브 엔진 = 규칙 리스트 `{ inputs[{type, qty, quality?}], output, condition? }` 를 순서대로 매칭. `cubemain.txt` 구조 그대로 데이터 주도(data-driven)로 구현.

---

## 4. 액트1 몬스터 & 안다리엘 (P7/P8)

### 몬스터 군 (액트1)
Fallen / Fallen Shaman · Spike Fiend(Quill Rat) · Zombie · Wendigo · Corrupt Rogue(근접/궁수/창병) · Skeleton(+Archer/Mage) · Goatman · Blood Hawk · Tainted · Giant Spider · Wraith · Fetish
- Quill Rat = Spike Fiend 계열 최약체(Blood Moor 등장). 원거리 가시 발사.
- Fallen Shaman은 Fallen을 부활시킴(우선 처치 AI 대상).

### 액트1 보스 — Andariel (프리셋 스탯, 랜덤 모디파이어 없음)
| | Normal | Nightmare | Hell |
|---|:--:|:--:|:--:|
| Level | 12 | 49 | 75 |
| HP | 1,024 | 24,800 | 60,031 |
| Defense | 60 | 752 | 1,622 |
| 물리 저항 | 0% | 0% | 66% |
| 화염 저항 | −50% (약점) | −50% | −50% |
| 냉기 저항 | 50% | 50% | 66% |
| 독 저항 | 80% | 50% | 66% |

- 공격: 근접(물리+독), **독 스프레이/노바**(50–100 독뎀 16초), 독 침(물리+독).
- **화염이 명확한 약점(-50%)** → 공략 설계 시 반영.

### 참고: 다른 액트 보스 특징
- Duriel(A2): 빠른 돌진 + Holy Freeze 오라(감속)
- Mephisto(A3): 번개/냉기/독 원거리 마법
- Diablo(A4): 파이어스톰·라이트닝 브레스·콜드터치
- Baal(A5): 분신(Vile Effigy)·저주·노바

출처: [Act Bosses — PureDiablo](https://www.purediablo.com/diablo-2/act-bosses), [Act I Bestiary — Diablo Wiki](https://diablo.fandom.com/wiki/Act_I_Bestiary), [Monster DB — diablo2.io](https://diablo2.io/monsters/), [Monster DB — LootCube](https://lootcube.net/en/monsters)

> **구현 함의:** 일반 몬스터 스탯은 `monstats.txt` 기반 데이터로, 보스는 프리셋 고정값 + 난이도별 테이블. 보스 공격 루틴은 **상태머신**(페이즈·쿨다운·특수기)으로 P8에서 개별 스크립트화. 안다리엘부터 (근접 / 독노바 / 독침)의 3-패턴 상태머신으로 착수 권장.

---

## 5. 남은 심화 (다음 라운드 후보)

- 나머지 6개 클래스 스킬 전체(각 클래스 착수 시)
- 몬스터별 정확 HP/AR/Def/저항 원본 테이블(`monstats.txt` 전수)
- 아이템 베이스 스탯 전수(`weapons.txt`/`armor.txt`: qlvl·소켓상한·내구·요구스탯)
- 유니크/세트 아이템 전체 목록 및 고정 스탯
- 접사 spawnWeight 정확값(가중 추첨 밸런싱용)
