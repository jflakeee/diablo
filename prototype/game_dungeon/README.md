# 게임 던전 (Game Dungeon) — 캡스톤: 랜덤 던전 크롤러

모든 시스템의 캡스톤 통합: **랜덤 던전 생성 + A* 내비게이션 + 전투 + 드롭/크래프트 +
출구 워프(다음 레벨)**. 저사양 실기에서 도는 D2형 던전 크롤러.

## 실행
```
godot --path . --rendering-driver opengl3 -- barb    # 바바리안
godot --path . --rendering-driver opengl3 -- sorc    # 소서리스
```
- 모바일은 조이스틱, PC는 WASD/방향키로 이동한다. 스킬은 버튼 또는 1~4,
  물약은 5/6, 저장/불러오기는 F5/F9, 전체화면 전환은 F11을 사용한다.
  붉은 타일(출구)에 도달하면 **다음 던전 레벨로 워프**.
- 3레벨부터 보스(안다리엘) 등장.

### 검증 (자동 플레이)
```
godot --path . --rendering-driver opengl3 -- autoquit barb
godot --path . --rendering-driver opengl3 -- autoquit sorc
```

## 통합된 전체 루프
1. `level_gen`으로 **랜덤 던전 생성**(레벨별 결정론 시드) + AStarGrid2D 구축
2. 플레이어 = 입구, 몬스터 = 랜덤 바닥칸(JSON 정의), 보스 = 3레벨+
3. **A* 내비게이션**: 플레이어(자동)·몬스터가 경로 따라 이동(400ms 캐시)
4. 전투(Part 1/5 공식), 드롭→줍기→장착(Part 3), 크래프트(Part 4)
5. **출구 도달 → `_next_level()`**: 던전 재생성 + 몬스터 재배치

## 실측 (2026-09-20, HD 4000, 결정론 시드)
```
arcanist: dungeon_level=2 levels_cleared=1 kills>0                verdict=PASS
warden:   dungeon_level=2 levels_cleared=1 kills>0                verdict=PASS
```

저장은 모바일 설정 패널의 `게임 저장`/`불러오기` 또는 키보드 F5/F9로 사용한다. 앱 pause, 포커스 상실, 종료 요청에서도 자동 저장한다. `save_store.gd`가 임시 파일 검증 후 원자 교체하며, 스키마 마이그레이션, 손상 시 직전 백업 복구, 중단된 임시파일 격리를 담당한다.

무기와 방어구는 물리 명중·피격 시 내구도가 감소한다. 0이 되면 베이스 피해·방어와 접사가 비활성화되며 상인 패널에서 장착 장비를 골드로 일괄 수리할 수 있다. 내구도 필드가 없는 이전 저장 아이템은 완전 수리 상태로 이관된다.

독자 세트 `Ember Oath`와 `Storm Vigil`은 각각 무기·방어구 2부위로 구성된다. 개별 고정 옵션에 더해 두 부위를 함께 장착하면 세트 보너스가 적용되며 한 부위가 파손되면 완성 보너스도 비활성화된다. 세트 품질은 드롭·도박·자동 습득·장착·경매·판매·수리 흐름에 모두 포함된다.

각 클래스의 4개 스킬에는 요구 캐릭터 레벨, 선행 스킬과 20레벨 상한이 적용된다. 6개 시너지 연결은 관련 스킬의 실제 피해·버프 수치에 반영된다. 일반 플레이는 기본 스킬부터 해금하고, 자동 종단 검증만 모든 전투 경로와 기존 50초 층 클리어 기준을 유지하기 위해 명시적인 검증 프리셋을 사용한다.

온라인 권위 계층은 `online_authority.gd`에 분리되어 세션 재접속, 위치 시퀀스와 이동 한도, 소유권·잔액 기반 멱등 에스크로를 검증한다. 자동 검사는 유실된 시퀀스·중복 패킷과 100계정 거래 보존성을 포함한다. 실제 ENet 검사는 서버와 두 클라이언트를 별도 프로세스로 실행하여 서로의 월드 스냅샷 수신까지 확인한다.

`data/coverage.json`은 클래스·스킬·몬스터·아이템·제작·진행의 최소 역할 구성을 선언한다. `coverage.gd`가 시작 시 실제 데이터와 대조하므로 콘텐츠 제거 또는 역할 누락은 최종 PASS를 차단한다.

`data/quests.json`은 3개 액트에 걸친 6개 독자 퀘스트와 선행 조건·처치 목표·보상을 정의한다. 진행은 HUD에 표시되고 보스 및 일반 처치 이벤트와 연결되며 저장 데이터 스키마 v3에 포함된다. 이전 v1/v2 저장은 빈 퀘스트 상태를 보완한 뒤 정의에 맞춰 정규화한다.

`data/waypoints.json`은 3개 액트의 9개 이동 지점을 정의한다. 새 층 진입 시 자동 해금되고 HUD에 현재 지점이 표시된다. 상인 패널의 `웨이포인트 순환 이동`은 현재 액트에서 이미 해금한 지점만 순환하므로 잠금 우회와 이전 액트 보스 보상 반복을 허용하지 않는다. 상태는 저장 스키마 v4에 포함되며 v1~v3 저장도 자동 이관된다.

50초 엄격 실행은 `performance_budget.gd` 기준으로 실제 논리 틱을 25Hz±5%로 유지하고, 활성 게임 객체 128개 이하, 정적 메모리 증가 64MiB 이하인지 측정한다. 초과 시 최종 결과가 실패한다.

Web preset은 설치 가능한 PWA를 생성한다. 독자 앱 아이콘은 `assets/app_icon_source.png`에서 `tools/icon_builder.gd`로 144/180/512 크기를 만들며, release pack은 개발용 `tools`, 로그, UID, 고해상도 원본을 제외한다.

### Web/PWA 릴리스 검증

저장소 루트 또는 다른 경로에서 다음 스크립트를 실행하면 빈 임시 디렉터리에 release export를 만들고 필수 PWA 파일, 1.5 MiB PCK 예산, 개발 도구·샘플·원본 아이콘의 패키지 제외를 한 번에 검증한다. Godot 로그에 export 오류가 있으면 프로세스 종료 코드가 0이어도 실패한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File prototype/game_dungeon/tools/release_check.ps1
```

Android 네이티브 출시는 Web/PWA와 별도이며 필요한 SDK와 실기기 완료 기준은 `docs/ANDROID_EXPORT_REQUIREMENTS.md`에 기록한다.

### Crafting Cube

가방의 `Crafting Cube`에서 수집한 보석·각인의 수량과 승급 결과를 확인한다.
동일 재료 3개를 소모하면 다음 등급 1개가 재료함에 합쳐진다. 재료가 부족하면
버튼이 비활성화되고 최고 등급은 승급할 수 없다. 기본 보석과 Ahn/Vey 각인은
몬스터에게서 드롭된다. 기존 저장의 보석 ID는 보통 등급으로 유지되며,
승급 재료도 기존 자동화 재료함과 함께 저장/불러오기된다.

UI 회귀 검사: `godot_console --headless --path prototype/game_dungeon --script res://tools/cube_ui_test.gd`
검사는 실제 버튼 입력, 중복 입력, 재료 부족, 빈 재료함과 320/640px 폭을 확인하며
플레이 저장을 변경하지 않는다.

**리롤 레시피**: 토파즈(소켓 효과가 0이라 다른 쓸모가 없던 재료) + 가방의 감정된
매직/레어 아이템 1개 → 그 아이템의 접사를 같은 품질·아이템레벨 기준으로 다시 굴린다.
비용은 품질별로 다르다 — 매직 3개, 레어 6개(원작의 최상급 해골 3개/6개 비율을
그대로 따르되 재료는 토파즈 유지, 2026-10-08). 이름/슬롯/요구치/내구도/소켓은
그대로 유지된다. 미감정·일반·세트·유니크 아이템은 대상이 아니다.

**유니크 드롭 제한(2026-10-08)**: 같은 유니크 베이스 아이템은 한 세션(브라우저 탭)
내에서 두 번 이상 드롭되지 않는다 — 몬스터 처치 드롭 시 `_dropped_uniques`에
이미 기록된 유니크는 확률 캐스케이드가 자연히 레어/매직/노말로 떨어뜨린다.
저장/로드 간에는 영속화하지 않는다(세이브 스키마 변경 없음).

**소켓 레시피**: 스컬(토파즈와 같은 이유로 쓸모없던 재료) 3개 + 소켓 없는 일반 품질
무기/방어구 1개 → 그 자리에서 소켓 2개를 부여한다. 소켓이 열린 아이템마다 보유한
보석/시길 종류별로 삽입 버튼이 뜨며, 룬을 올바른 순서로 넣으면 기존 룬워드 매칭이
그대로 작동한다. 이 레시피 전에는 소켓/보석/룬/룬워드 시스템이 전부 구현돼 있었지만
실제 플레이에서 소켓 있는 아이템을 만들 방법이 아예 없었다.

**보석 품질**: 소켓 효과는 보석 품질(chipped~perfect)에 비례한다(.4~1.0배, `GEM_STATS`
표는 perfect 기준값). 승급 재료함의 "Combine 3 -> 다음 등급" 체인이 이제 소켓에 끼우는
보석의 실제 효과에 반영된다 — 전에는 등급과 무관하게 전부 perfect 효과를 냈다.

**제작(Crafted) 레시피(2026-10-08)**: Saal 시길 1개 + Perfect Ruby 1개 + 가방의
감정된 매직 무기/방어구 1개 → "crafted" 품질로 변환(고정 접사 2개 + ilvl 구간별
랜덤 접사 1~4개, 원작의 제작 아이템 접사레벨 공식을 이 프로젝트 구조에 맞게 근사).
품질 등급은 rare와 set 사이(자동 장착/판매/경매 등급 설정 순환에도 노출됨).
diamond/amethyst는 아이콘이 없어 재료로 쓰지 않고(2026-10-04 `[ASSET]` 함정
회피), 이미 드롭·아이콘이 있는 ruby의 perfect 등급을 재사용한다. 제작된 아이템은
재굴림/소켓 추가 레시피 대상이 아니다(원작처럼 제작 후 고정).

**스크랩북(2026-10-09)**: 기존 습득→자동감정→총전투력 비교 자동장착 흐름은
전혀 바뀌지 않는다. 장비(무기/방어구/반지/목걸이/참)를 주울 때마다 그 베이스/
등급/아이템레벨을 기록한 소모형 "복원 티켓"이 가방 옆 Scrapbook 패널에 한 장씩
쌓인다. 골드를 내고 복원하면 같은 베이스/등급/ilvl로 **새로 굴린** 아이템이
감정된 상태로 가방에 추가된다 — 자동장착되지 않고 사용자가 직접 Equip을
눌러야 한다. 비용은 `RESTORE_BASE{normal:15, magic:60, rare:160, set:350,
unique:500} * (1 + ilvl/20)`. 유니크 등급 티켓도 발급되며, 몬스터 자연 드롭에만
적용되는 "유니크 1게임 1드롭 제한"을 **의도적으로 우회**한다(골드를 내는 별도
경로이므로 중복 사본 획득 가능 — 사용자 확인 완료). 이 라운드에서 `UNIQUES`/
`SETS`의 접사도 고정값에서 `[min,max]` 범위로 바뀌어, 일반 드롭을 포함한 모든
유니크/세트 생성이 매번 다른 수치로 확정된다(스크랩북 전용 변경 아님).
상세: `docs/superpowers/specs/2026-10-09-item-scrapbook-design.md`.

### Identification and resistance effects

새 몬스터 드롭의 레어 장비는 미감정 상태다. 가방의 `Identify (Free)`로 기존에
생성된 이름·옵션을 공개한다. 감정 전에는 플레이어/동료 장착, 자동 판매·경매,
일괄 판매를 차단하며 보관함 이동은 가능하다. 감정 시 자동 장착하거나 옵션을
다시 뽑지 않는다. 기존 저장의 감정 필드가 없는 장비와 상인 도박 장비는 감정 완료로 취급한다.

- `Storm Lance`: 명중 직전 `Storm Hex`를 적용한다. 6초 동안 원소 저항을
  `min(70, 30 + 2 × 스킬 레벨)`만큼 낮춘다. 재시전은 지속시간을 갱신하며 중첩하지 않는다.
- `Iron Chant`: 기존 생명/마나 버프와 함께 `Sundering Aura`를 유지한다.
  살아 있는 시전자 기준 6타일 이내·시야가 닿는 적의 원소 저항을
  `min(60, 20 + 2 × 스킬 레벨)`만큼 낮춘다. 마을에서는 적용하지 않는다.
- 원래 저항이 100 이상이면 저주와 오라의 합산 감소량에 1/5 효율(내림)을 적용한다.
  계산 후 100 미만이어야 면역이 해제되고 저항 하한은 −100이다. 적은 99%까지,
  플레이어는 기존 75% 상한으로 피해를 계산한다. 물리 피해에는 적용하지 않는다.
- 저주 잔여시간은 보라색 막대, 활성 오라는 시전자 발밑 고리로 표시한다.
  스킬 설명은 캐릭터 창과 툴팁에서 확인한다. 저장 시 현재 층의 저주와
  Iron Chant 잔여시간도 보존하며, 새로 생성된 층의 적은 저주가 없는 상태로 시작한다.
- **Hell 원소 면역**: 난이도별 저항 보너스(Normal +0 / NM +20 / Hell +70)가 Hell에서만
  fire/cold/light 저항을 100 이상으로 올려 실제 면역을 만든다(독은 난이도와 무관하게
  이미 면역 몬스터가 있었다). 위 1/5 면역돌파 공식이 Hell에서 처음으로 실전 발동한다.
  `_immune_selftest()`가 정적 데이터로 Hell=전부 면역/Normal·NM=전부 비면역을 검증한다.
- **난이도별 보상**: 몬스터 레벨 자체는 난이도와 무관하게 고정(명중률 alvl/dlvl 균형
  보존)이지만, 드롭 아이템레벨(+0/+4/+8)과 킬 경험치(x1.0/x1.25/x1.5)는 난이도에 비례해
  오른다. Normal은 두 값 모두 항등이라 기존 동작과 완전히 동일하다.

통합 회귀 검사:
`godot_console --headless --path prototype/game_dungeon --script res://tools/progression_combat_test.gd`

```powershell
godot_console --headless --path . res://tools/network_harness.tscn -- net_server net_multi
godot_console --headless --path . res://tools/network_harness.tscn -- net_client net_multi
godot_console --headless --path . res://tools/network_harness.tscn -- net_client2 net_multi
```

### Monster pack placement

Dungeon monster spawns group into packs of 2-4 of the same monster type instead
of scattering individually across the floor. Each pack anchors to one random
floor cell and its members land on nearby floor tiles within a small radius
(falling back to a fully random floor cell if the area is too tight). Champion
and unique rank is rolled once per pack rather than per monster, so a successful
roll turns the whole pack gold/blue together and uniques share the same
`UNIQ_MODS` modifier. Boss spawns are unaffected. Autoquit self-test groups
spawned monsters by pack id and verifies cluster distance and rank consistency,
printing `[PACK] packs=N min_size=.. max_size=.. verdict=..`.

### Inventory grid (Bag)

The Bag view shows each item as a 64x64+ tappable tile (base name, quality
color, full name as tooltip) in a grid instead of a full detail row per item.
Tapping a tile selects it and reveals the existing single detail panel below
(equip, Identify (Free) when unidentified, Keep/Merc/Stash/Sell/Protected) —
the same handlers as before, only the rendering changed. Exactly one item is
selected whenever the bag is non-empty (defaults to the first), so a
single-item inventory still shows its detail panel without requiring a tap.
This is a tap-select grid, not a drag-and-drop W×H socket grid — item data has
no cell-size field and drag gestures are out of scope; see the design doc for
why. Cube/Collection/Item Log views are untouched.

### Monster AI interest-area culling

Witnessed monsters (seen at least once through fog) used to run full AI and
A* pathfinding every tick forever, even far from the player. Non-boss
monsters now skip that frame's AI entirely when farther than 6 tiles from the
player (attack cooldown still ticks down). The player's own movement is
unaffected, so approaching a culled monster still closes the distance and
re-enables its AI normally. Bosses are exempt. Autoquit prints
`[AI_CULL] astar_calls=.. culled_far=.. witness_max_dist=.. verdict=..` and
fails the run if culling never actually triggered.

### Preset room variety

Each generated room rolls one of three authored pillar presets: none (50%),
four pillars at the inner corners (25%), or four pillars at the inner edge
midpoints (25%). Presets only touch the inner 5x5 of a room's 7x7 interior,
leaving the 1-tile perimeter (where doors open) always clear, so connectivity
holds regardless of door placement. Boss arena carving and act3's full-room
pillar_plains theme both run after preset placement and simply overwrite it
where they apply. Fixed a latent act3 (pillar_plains) bug found while testing
this: its global pillar scatter had no connectivity repair, unlike
`MODE_BLOCKED_RANDOM`; it now restores pillars the same way until the
entrance-exit path and all room centers stay reachable.

### Treasure room

Non-boss chunks (including ones streamed in mid-level, not just the entrance
chunk) have a 25% independent chance of carving one non-entrance/non-exit
room into a treasure room — cleared of pillars/low walls, dropping 3 rare
items plus bonus gold the first time the chunk is entered. Boss floors never
roll one, so it never competes with the boss arena. Like the boss arena,
treasure-ness is recomputed from the chunk's own seed (not a saved flag), so
reloading a save regenerates the same room in the same place.

### Boss room arena

The entrance chunk of a boss floor (last level in an act) carves its center
room and the four adjacent rooms into one open plus-shaped arena instead of
leaving the usual 9-tile room walls and theme decoration (pillars / low walls)
in place. The boss spawns at the arena's center tile instead of a random floor
cell. Boss-ness is recomputed from the floor id every time (not a saved flag),
so loading a save on a boss floor regenerates the identical arena. Non-boss
floors and later chunks of a boss floor are unaffected. Autoquit self-test
prints `[BOSS_ROOM] anchor=.. boss_cell=.. used_arena=.. verdict=..`.

### Jewelry equipment

The equipment model includes dedicated `ring` and `amulet` slots in addition to
weapon and armor. Jewelry participates in world drops, gambling, automatic
equipment comparison, affix/stat aggregation, and save/load. Unique jewelry has
fixed authored affixes and is indestructible, so it is excluded from durability
loss and repair costs. Older saves load with empty jewelry slots.

### Mercenary equipment

The mercenary has persistent weapon and armor slots. Inventory rows expose a
separate mercenary equip action, and equipped base stats plus affixes contribute
to companion damage, attack rating, defense, life, and elemental resistances.
Broken equipment is ignored and save schema v5 migrates older saves with empty
companion slots.

### Mercenary type variety

A vendor-panel button cycles the companion through three types that keep the
shared weapon/armor slots but differ in combat role: Ember Scout (ranged,
fire bolt), Iron Guard (melee, tankier life/defense), and Frost Acolyte
(ranged, cold bolt that applies the same slow the player's cold weapons use).
Switching preserves level, equipment, kill count, and revive timer — only
stats and art are reapplied. Save schema v16 persists the selected type
(`mercenary.gd` `TYPES`/`TYPE_ORDER`, defaults to Ember Scout for older saves).

### Run and stamina

Strong joystick input activates running at 1.6x walk speed while stamina is
available. Maximum stamina scales with level and vitality, armor weight affects
drain, exhaustion forces walking, and stopping restores stamina after a short
delay. The HUD exposes the current pool and movement state; schema v6 persists
the pool while older saves start full.

### Death and corpse recovery

Death creates a visible corpse at the defeat position, applies difficulty-based
experience loss and moves 20% of carried gold onto the corpse. After a short
delay the hero revives at the dungeon entrance with half life and mana; walking
back to the marker recovers its gold. Corpse position, held gold, and death count
persist in save schema v7.

### Personal stash

The Bag panel supports one-tap transfers into and out of a 48-item personal
stash. Transfers preserve complete item dictionaries, reject missing or
duplicate operations, and never remove an item when the stash is full. Schema
v8 persists and bounds stored entries while migrating older saves to an empty
stash.

### Equipment requirements

Every item base defines level, strength, and dexterity requirements. Generated
normal, magic, rare, set, and unique items retain those requirements. Automatic
equipment and manual player or mercenary actions reject unmet requirements;
the Bag displays the thresholds and disables invalid touch targets. Legacy
items without requirement fields remain usable with level-one defaults.

### Dual ring slots

Characters equip independent left and right rings. Empty slots are filled first;
when both are occupied, automatic and one-tap equipment replaces the lower-score
ring. Both rings contribute affixes and resistances. Save schema v9 migrates the
former single `ring` entry into `ring_left` and initializes `ring_right` empty.

### Charm items

A new accessory category drops, gambles, and identifies like rings, but is
deliberately not a bag passive: this Bag is a tap grid with no inventory
space cost, so a stackable passive would be free stat hoarding. Charms
instead use dedicated `charm_left`/`charm_right` slots sharing the same
empty-slot-first / power-comparison swap rule as dual rings
(`main.gd _dual_slot_for_item`). Charm affixes feed into the same stat and
auto-equip comparison pipeline as every other slot. Save schema v17
initializes both charm slots empty for older saves.

### Automatic equip grade gate

The vendor panel's "Cycle Auto Equip" button sets `Automation.equip_min`, but
`_auto_equip()` previously never read it — the toggle changed state with no
gameplay effect, comparing items purely by combat power regardless of quality.
Fixed by gating the **replace** path only: a pickup only replaces already-
equipped gear if its quality rank is at or above `equip_min`, even when the
pickup is a raw power upgrade. Filling an empty slot is unaffected (any
quality equips immediately, so a fresh character is never left bare). Items
blocked by the gate fall through to the existing inventory/auto-sell logic
unchanged.

### Immortal-style skill button fan (mobile layout, not wired)

`MobileUI.layout()`'s 2x2 skill-button grid math is replaced with a two-tier
layout on mobile profiles: `skill_primary` stays at its original corner
position (thumb anchor), and the other three slots fan around the same pivot
across a 180-to-270-degree arc. An even four-button arc was tried first but
failed the existing `validate()` bounding-box overlap check — diagonal
neighbors at 45 degrees need a far larger radius than axis-aligned neighbors
to clear square buttons, and that radius pushes the arc off-screen on the
minimum landscape viewport. The primary-fixed, three-button fan clears every
pairing with margin at every tested viewport.

**This geometry currently has no visible effect.** Manual skill buttons were
intentionally removed from `_ready()` on 2026-09-29 (`aaac80b` — skill
keybinds, WASD, and per-class auto-play spell logic were removed together in
favor of a basic-attack-only auto-play loop with modal-pause). `layout()`
still computes `skill_primary/secondary/utility/quaternary` positions (kept
in sync with `validate()`'s own tests) but nothing in `main.gd` consumes
them — confirmed by `git log -S"_add_skill_button(ui"`, which shows the one
and only call site was removed in that commit. The missing wiring is **not a
regression** — it is a deliberate design choice. The arc math is ready for
whenever manual skill controls return, but **do not re-wire it without
confirming with the project owner first**; this round's temporary wiring
(added to verify the geometry end-to-end, `[SKILL_VISUAL] verdict=PASS`) was
reverted on an explicit 2026-10-04 user decision to keep auto-play-only
combat.

### Stat/skill respec

A vendor-panel button resets stats to class base values and skills to
level 1 (not level 0) for a gold cost (`300 + level * 60`). Skills are
floored at 1 rather than wiped, because the skill-point "+" button only
accepts skills already at level 1+ — new skills are unlocked exclusively by
finding Skill Book drops, so a full reset to 0 would strand refunded points
until a book dropped again. Refunds are computed from actual allocations
(current minus base/floor), never re-derived from level formulas, so quest
skill-point rewards are preserved exactly. No save schema change — every
field involved is already persisted.

### Compact mobile presentation

Combat controls, minimap, menu buttons, and HUD typography use a denser mobile
scale while retaining 48px-or-larger touch targets. The Bag uses vertical
scrolling and two-row item actions so long names and requirements stay inside
the panel. User-facing emoji/symbol glyphs were replaced with HP/MP and plain
text labels to prevent missing-font square characters in Web/mobile builds.

### Responsive mobile and desktop HUD

The runtime selects a touch-first mobile profile when a touchscreen is
available and a compact desktop profile otherwise. Mobile keeps the virtual
joystick and large combat targets. Desktop hides the virtual joystick, uses
smaller menu, potion, and skill controls, and accepts mouse clicks on skills.
Both profiles are checked at 960x540 through 1600x720 by the UI self-test.

→ 두 클래스 모두 **다층 던전 클리어→워프** 동작, 런타임 에러 0.

## 정식화 (2026-10-02 갱신 — 완료 항목 제거)

위 섹션들에 이미 반영된 완료 항목(A* 관심영역 컬링, pack 배치, 프리셋 룸 다양화, 보스룸
아레나, 보물방, 인벤 그리드 UI, 미니맵/웨이포인트/난이도/세이브 등)은 제거했다. 남은 후보는
"새 작업 전 여기 먼저 확인" 메모리에서 추적한다 — 이 목록을 다시 채우려면 코드 대조부터
새로 시작할 것(이 섹션을 과거에 갱신하지 않아 완료된 항목이 한동안 남아 있었다).
