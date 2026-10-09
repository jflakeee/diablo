# 아이템 스크랩북(소모형 복원 티켓) + 유니크/세트 수치 범위화

작성일: 2026-10-09
대상: `prototype/game_dungeon`
상태: 구현 기준 확정(사용자 승인 완료)

## 1. 배경

사용자가 제안한 신규 시스템: 장비 습득 시 기존 자동감정→자동장착 흐름은
그대로 두되, 습득한 아이템 종류를 "스크랩북"에 소모형 티켓으로 기록하고,
나중에 골드를 내면 같은 베이스/등급/아이템레벨로 **새로 굴린** 아이템을
추가로 얻을 수 있게 한다. 브레인스토밍 과정에서 여러 차례 설계 방향이
바뀌었다 — 최초 제안("습득이 인벤토리 대신 스크랩북으로 감")은 사용자가
직접 정정해 "습득은 그대로, 스크랩북은 별도 추가 파밍 수단"으로 확정됐다.
아래 §2~§6이 최종 확정 설계다.

## 2. 기존 습득 흐름(변경 없음)

`_pickup()`의 장비 분기(무기/방어구/반지/목걸이/참)는 **전혀 바뀌지 않는다**:
자동감정 → `_auto_equip()`(총전투력 비교, 교체 시 등급 게이트 적용) →
`should_auto_sell()` 폴백 → `_push_item_event()` 로그. 이 흐름 끝에 스크랩북
티켓 기록 한 줄만 추가된다.

## 3. 스크랩북(신규 `scrapbook.gd`)

- **범위**: 무기/방어구/반지/목걸이/참, 전 등급(노말~유니크). 포션/재료/
  골드/스킬북은 대상 아님(기존 로직 변경 없음).
- **구조**: 소모형 티켓 배열. 습득마다 한 줄 추가, 복원하면 그 줄은 사라짐
  (카탈로그/중복 제거 아님 — 같은 종류를 여러 번 주우면 티켓도 여러 장).
- **티켓 데이터**: `{base: Dictionary, quality: String, ilvl: int}` — 그
  순간 실제로 생성된 아이템과 **동일한** 베이스/등급/ilvl을 그대로 기록.
  신규 RNG 소비 없음(이미 결정된 값을 복사만 함).
- **용량**: 무제한.
- **표시**: 품질색 + "`<품질> <베이스명> Lv.<ilvl>`" + 복원 비용 + Restore
  버튼(골드 부족 시 비활성화).

## 4. 복원(Restore)

버튼을 누르면:
1. 비용만큼 골드 차감, 해당 티켓 제거.
2. `Item.generate(_rng, ticket.base, ticket.ilvl, ticket.quality)`로 **새로
   굴린** 아이템 생성(매직/레어는 접사 재추첨, 유니크/세트는 §6의 범위화
   덕분에 수치가 새로 굴러감, 노말은 변동 없음 — 티켓 가치가 낮아 가격도
   가장 저렴).
3. 생성된 아이템은 **감정된 상태**로 바로 인벤토리에 추가(`_inventory.append`).
   **자동장착은 호출하지 않는다** — 사용자가 가방에서 기존 "Equip" 버튼을
   직접 눌러야 장착됨.
4. `_collection.accepts()/register()`를 동일하게 호출(유니크/세트라면
   기존 트로피북에도 반영 — §6 덕분에 `option_bests`가 처음으로 의미를
   갖게 됨).
5. 복원 로그: `"SCRAPBOOK RESTORED: <display_name> / <affix_text>"`.

**유니크 1게임 1드롭 제한과의 관계(의도된 설계)**: 이 제한(`_dropped_uniques`)
은 `roll_drop()`의 자연 드롭 경로에만 적용된다. 스크랩북 복원은 `generate()`
를 직접 호출하므로 이 제한을 **의도적으로 우회**한다 — 골드를 내고 사는
별도 경로이므로 같은 유니크를 여러 벌 얻을 수 있다(사용자 확인 완료).

## 5. 복원 비용 공식

```gdscript
const RESTORE_BASE := {"normal": 15, "magic": 60, "rare": 160, "set": 350, "unique": 500}
cost = roundi(RESTORE_BASE[quality] * (1.0 + float(ilvl) / 20.0))
```
"crafted" 품질은 드롭에 없으므로 테이블 불필요(스크랩북 티켓 자체가 안 생김).
숫자는 초안 — 플레이 밸런스는 추후 조정 가능.

## 6. 유니크/세트 수치 범위화 (신규, 스크랩북과 별개로 드롭 전체에 적용)

현재 `UNIQUES`/`SETS`의 `affixes`는 고정 정수값(예: Rift Cleaver는 항상
`ed=70`)이다. 이를 `[min, max]` 쌍으로 바꾸고 `generate()`가 유니크/세트
분기에서도 매번 범위 내 랜덤값을 뽑도록 변경한다. **드롭(roll_drop)과
스크랩북 복원 양쪽에 동일하게 적용** — 스크랩북 전용 변경이 아니다.

범위는 기존 고정값의 ±20~30% 내외로 설정(초안, 전부 조정 가능):

```gdscript
const UNIQUES := {
	"Short Sword": {"name": "Emberneedle", "affixes": {"ed": [40,60], "fdmg": [7,13], "ar": [32,48]}},
	"Hand Axe": {"name": "Rift Cleaver", "affixes": {"ed": [56,84], "ar": [32,48], "cdmg": [6,10]}},
	# ... 나머지 7개 동일 패턴
}
const SETS := {
	"Short Sword": {"set_id": "ember_oath", ..., "affixes": {"ed": [26,38], "fdmg": [5,9]}},
	# ... 나머지 3개 동일 패턴
}
```

`generate()`의 유니크/세트 분기(`item.gd:121-134` 부근)가 현재는
`it["affixes"][k] = int(u["affixes"][k])`로 고정값을 그대로 복사하는데,
`[min,max]` 배열이면 `rng.randi_range(min,max)`로 롤하도록 분기 추가.

**영향받는 기존 코드**: `system_tests.gd`의 유니크/세트 관련 단언들이 정확히
고정값과 비교하고 있어(`int(unique_item["affixes"].get("ed",0)) == 70` 등)
전부 범위 검사(`>= min and <= max`)로 바꿔야 한다. `main.gd`의 `[UNIQ]`
셀프테스트 print, `_craft_selftest()`의 `unique_item`/`merc_weapon`/
`merc_armor` 관련 하드코딩 비교도 동일하게 점검 필요.

## 7. 저장 스키마

`_snapshot()`/`_apply_save()`에 기존 패턴대로 추가:
```gdscript
"scrapbook": _scrapbook.snapshot(),  # {"tickets": [...]}
```
구버전 세이브는 키가 없어 빈 배열로 기본 복원(스키마 버전 게이트 불필요,
기존 `collection_book`/`automation` 저장과 동일한 additive 패턴).

## 8. UI

가방 패널과 같은 레벨의 새 뷰 `_inventory_view == "scrapbook"` 추가, 기존
"Bag"/"Crafting Cube"/"Collection" 버튼 옆에 "Scrapbook" 버튼 신설.
`_rebuild_scrapbook()`이 티켓 목록 + Restore 버튼을 렌더링(기존
`_rebuild_cube()` 구조와 동일 패턴 재사용).

## 9. 검증

- `scrapbook.gd` 자체 `selftest()`: 티켓 추가/복원/소모, 비용 공식, 복원된
  아이템이 감정 상태인지.
- `system_tests.gd`: 유니크/세트 범위 검사로 전면 수정(위 §6), 신규
  스크랩북 라운드트립(저장/복원) 체크 추가.
- `main.gd _craft_selftest()`가 아니라 **`_scrapbook_selftest()`를 새로
  만들 것** — 크래프트와 무관한 별개 시스템이라 이름 분리, 역시
  [[shared-rng-selftest-pitfall]] 적용해 전용 `test_rng` 사용.
- barb/sorc 표준 오토퀴트, `tools/progression_combat_test.gd`,
  `tools/cube_ui_test.gd`(영향 없어야 함 — 변경 없음) 전부 PASS 확인 후
  배포. 유니크 수치가 랜덤화되므로 `[UNIQ]` 셀프테스트 print 문구도 범위
  표시로 조정 필요.

## 10. 비범위

- 스크랩북 티켓을 복원 없이 직접 판매/삭제하는 기능(무제한 용량이라 급하지
  않음).
- 기존 "미감정 레어" 식별 시스템 변경 없음(스크랩북과 무관, 일반 드롭은
  여전히 레어가 미감정으로 나옴).
- 레시피 세분화(해골/소켓/크래프트 등 기존 큐브 레시피) 변경 없음.
