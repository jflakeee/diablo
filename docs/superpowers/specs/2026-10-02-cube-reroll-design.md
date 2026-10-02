# 호라드릭 큐브 레시피 확장 — 매직/레어 아이템 접사 리롤

작성일: 2026-10-02
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

기존 큐브는 재료(보석/시길)를 다음 등급으로 합성하는 레시피만 있었다. D2의 "아이템 재굴림"
계열 레시피를 하나 추가한다: 재료 3개 + 감정된 매직/레어 아이템 1개 → 그 아이템의 접사를
같은 등급·아이템레벨 기준으로 다시 굴린다.

## 2. 완료 조건

1. 토파즈(기존 드롭 재료) 3개 + 감정된 매직 또는 레어 아이템 1개를 소비해 그 아이템의
   접사(prefix/suffix/affixes)를 새로 굴린다. 이름/슬롯/요구치/내구도/소켓/품질/
   아이템레벨은 그대로 유지한다.
2. 미감정 아이템, normal/set/unique 품질 아이템은 대상이 아니다.
3. 재료가 부족하면 버튼이 비활성화되고, 억지로 호출해도 아무 일도 일어나지 않는다
   (재료도 아이템도 그대로).
4. 큐브 UI(가방 → Crafting Cube)에서 가방의 감정된 매직/레어 아이템마다 리롤 버튼이 뜬다.

## 3. 범위와 비범위

### 범위
- `item.gd`: `generate()`의 품질별 접사 롤 로직을 `_apply_quality_roll()`로 추출(재사용),
  `reroll()` 추가
- `craft.gd`: `REROLL_CATALYST`("topaz")/`REROLL_COST`(3), `can_reroll()`, `reroll()`
  (재료 소비 + `item_script.reroll()` 위임)
- `main.gd`: `_rebuild_cube()`에 리롤 섹션(가방의 매직/레어 감정 아이템마다 버튼),
  `_reroll_inventory_item()`, `_craft_selftest()`에 5번째 체크 추가
- `tools/cube_ui_test.gd`: 리롤 버튼 탐지/클릭/재료소비 검증 추가

### 비범위
- 등급 업그레이드(매직→레어, 레어→유니크) 레시피 — 별도 후속 항목
- 소켓 추가/제거 레시피 — 별도 후속 항목
- 재료 선택 UI(어떤 재료 스택을 쓸지 플레이어가 고르는 것) — 토파즈로 고정해 구현을
  한 사이클로 완결

## 4. 상세 설계

### 4.1 왜 토파즈인가

`craft.gd GEM_STATS`의 topaz 항목은 `armor: {res_all: 0}`로 소켓 삽입 효과가 사실상 없다
(0 스탯). 드롭 테이블(`main.gd` 몬스터 드롭)에는 이미 포함되어 있어 신규 재료를 만들지 않고
기존에 쓸모가 거의 없던 재료에 새 용도를 준 것 — 재료 종류를 늘리지 않으면서 리롤을
항상 접근 가능하게 한다.

### 4.2 재굴림 로직

`generate()`가 품질별 접두/접미사 개수를 굴리던 블록을 `_apply_quality_roll(rng, it,
quality, ilvl)`로 추출해 `reroll()`에서도 재사용한다(중복 금지). `reroll()`은 `affixes`를
비우고 `prefix`/`suffix`를 초기화한 뒤 같은 품질·아이템레벨로 다시 굴린다 — 정확히
`generate()`가 처음 그 품질을 굴릴 때와 동일한 테이블/확률을 사용하므로 별도 밸런싱이
필요 없다.

### 4.3 UI

`_rebuild_cube()`는 재료 합성 목록 뒤에 "REROLL" 섹션을 추가해, 가방에 있는 감정된 매직/
레어 아이템마다 이름+현재 접사 레이블과 "Reroll" 버튼을 보여준다. 재료가 모자라면 버튼만
비활성화(기존 합성 버튼과 동일한 패턴). 리롤 후 `_rebuild_inv()`로 즉시 갱신.

### 4.4 검증

- `item.gd`/`craft.gd`는 신규 로직이라 자체 단위 동작은 `_craft_selftest()`의 5번째 체크
  (`[P4] reroll: ...`)로 확인: 재료 소비, 품질 유지, 접사 1개 이상 생성.
- `tools/cube_ui_test.gd`: 매직 아이템을 가방에 넣고 토파즈 3개를 지급한 뒤 "Reroll"
  버튼이 뜨고 비활성화되지 않았는지, 클릭 후 토파즈가 소비되고 접사가 비어있지 않은지
  확인(값 자체의 변화는 낮은 확률로 동일할 수 있어 구조적 불변식만 검사).
- barb/sorc 50초 오토퀴트: `[P4][RESULT] craft_selftest verdict=PASS`로 기존 4체크 +
  신규 5번째 체크를 확인. 이 작업 중 `_craft_selftest()`의 결과가 지금까지 print만 되고
  최종 `[GD][RESULT] ok` 집계에는 전혀 묶이지 않았던 것을 발견했다(`_pack_selftest_ok`/
  `_waypoint_selftest_ok`/`_boss_room_selftest_ok`는 이미 묶여 있었는데 craft만 빠짐 —
  MAP_VARIANTS 교훈과 같은 종류의 숨은 FAIL 위험). 리롤을 추가하는 김에 `_craft_selftest_ok`
  멤버 변수를 신설해 최종 `ok` 체인에 합류시켰다.
