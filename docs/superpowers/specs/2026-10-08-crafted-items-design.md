# 제작(Crafted) 아이템

작성일: 2026-10-08
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 배경

[d2-item-system-reference.md](../../research/d2-item-system-reference.md) §4,
§8 체크리스트의 마지막 미반영 항목(`[ ] Crafted 아이템 개념`)을 반영한다.
연구 문서 §4 요약: 베이스는 매직 아이템, 호라드릭 큐브로 제작, 고정 속성
3~4개 + ilvl 구간별 확률표를 따르는 랜덤 접두사/접미사 1~4개, 전용 접사레벨
공식(clvl/ilvl 가중평균 + qlvl 보정) 사용. 레시피 4계열(Hit Power/Blood/
Caster/Safety Items)은 미조사 상태라 이번 라운드는 단일 범용 레시피로 범위를
좁힌다 — 4계열 전부 구현은 신규 조사가 선행돼야 하는 별도 작업.

## 2. 범위

**포함**: 매직 아이템 1개 + 전용 재료(룬 1개 + 퍼펙트 보석 1개) → 그 자리에서
"crafted" 품질로 변환(고정 접사 2개 + ilvl 구간별 랜덤 접사 1~4개). 대상은
weapon/armor 슬롯으로 한정(소켓 레시피와 동일한 범위 판단 — 반지/목걸이/참은
고정 접사 밸런스를 새로 설계해야 해서 비범위).

**비포함**(스코프 확장 방지):
- 신규 주얼류 아이템 타입 도입 안 함 — 드롭 테이블/아틀라스 확장을 유발해
  2026-10-04의 `[ASSET] "ok": false` 함정을 재현할 위험.
- 레시피 4계열 구분 안 함 — 조사 미비, 단일 범용 레시피로 시작.
- "안전 아이템"류의 캐릭터 레벨 요구치 완화 등 부가 효과 미반영.
- 제작된 아이템의 재굴림/소켓 추가는 기존 레시피 조건(품질=magic/rare,
  품질=normal)에 안 걸려 자동으로 비활성 — 원작과 동일하게 "제작 후 고정"
  취급(의도된 결과, 버그 아님).

## 3. 재료

새 전용 촉매 2종을 도입한다 — 기존 토파즈(리롤)/스컬(소켓) 경제와 겹치지 않게,
어떤 룬워드에도 안 쓰이는 룬과 소켓 삽입 외 다른 소비처가 없는 퍼펙트 보석을
고른다:

- **룬**: `Saal`(현재 룬워드 2종 Tempered Edge=Vey+Ahn, Gloom Crown=Korr+Vey
  어디에도 안 쓰임). 다만 몬스터 드롭 풀(`main.gd` `gems` 배열)이 지금까지
  `rune_Ahn`/`rune_Vey`만 포함해 Saal은 획득 경로가 없었다 — 룬 아이콘은
  이름과 무관한 범용 아이콘(`art_recipes.json`의 `"kind":"rune"` 1개가
  전체 룬을 커버)이라 아틀라스 작업 없이 드롭 풀에 추가 가능. 이번 라운드에
  `rune_Saal`을 드롭 풀에 포함.
- **보석**: 처음엔 `diamond:perfect`를 검토했으나 **`diamond`/`amethyst`는
  `GEM_STATS`에 스탯만 정의돼 있고 `art_recipes.json`에 아이콘이 없어**(현재
  컴파일된 보석 아이콘은 ruby/sapphire/topaz/emerald/skull 5종뿐) 재료로
  쓰면 2026-10-04 라운드에서 겪은 `[ASSET] "ok": false` 함정을 그대로
  재현한다 — 이미 드롭·아이콘·5단계 승급 체인이 전부 작동하는 `ruby:perfect`
  로 교체.

비용은 1:1(룬 1개 + 보석 1개) — 기존 레시피들(토파즈 3/6개, 스컬 3개)보다
단가가 낮지만, 재료 자체가 희귀한 퍼펙트 등급 보석(승급 체인 5단계 중 최상위)
이라 자연스럽게 소비 난이도가 있음.

## 4. 접사 규칙

- **고정 접사**(슬롯별 2개, 항상 적용):
  - weapon: `ar` +20~40, `cdmg`(냉기 추가 데미지) +3~8
  - armor: `def` +10~20, `res_all` +5~10
  - 전부 combat.gd에서 이미 실전 소비되는 기존 스탯 키 재사용(신규 스탯 타입
    도입 안 함 — PREFIXES/SUFFIXES의 ed/ar/def/res_all과 동일 패턴).
- **랜덤 접사**: ilvl 구간별 개수 확률표(연구 문서 §4 그대로) 후 절반은
  접두사 풀, 절반은 접미사 풀에서 기존 `_roll_affixes()` 재사용(개수가
  홀수면 접두사 쪽에 1개 더).

  | ilvl 구간 | 확률 |
  |---|---|
  | 1~30 | 1개 40% / 2개 20% / 3개 20% / 4개 20% |
  | 31~50 | 2개 60% / 3개 20% / 4개 20% |
  | 51~70 | 3개 80% / 4개 20% |
  | 71+ | 4개 100% |

- **접사레벨 공식**(원문 4단계 공식을 이 프로젝트 구조에 맞게 근사):
  `ilvl = min(99, int(0.5*character_level) + int(0.5*base_ilvl))`.
  원문의 qlvl(베이스 품질레벨) 보정 단계는 이 프로젝트가 베이스 아이템에
  qlvl 개념을 아예 모델링하지 않아 0으로 근사한다 — qlvl=0을 원문 3/4단계에
  대입하면 조건이 사실상 항등(`접사레벨 = ilvl`)이 되므로, 코드에는 의미
  없는 분기를 남기지 않고 바로 `ilvl`을 접사레벨로 사용한다(원문 공식의
  핵심인 clvl/base_ilvl 가중평균은 그대로 보존). 위 표의 "ilvl 구간"도 이
  계산된 `ilvl` 기준으로 평가한다.

## 5. 코드 변경

- `item.gd`: `CRAFT_FIXED_AFFIXES` 상수, `_craft_affix_count(rng, ilvl)`
  헬퍼, `craft(rng, it, character_level) -> bool`(품질=magic·감정됨·슬롯이
  weapon/armor일 때만 허용, 품질을 "crafted"로 바꾸고 접사 전체 재설정).
  `quality_color()`에 "crafted" 색상 추가(구리색 계열, 기존 5색과 구분).
- `automation.gd`: `QUALITY_RANK`에 `"crafted": 3` 삽입(rare=2와 set=4 사이,
  set/unique 기존 값 각각 +1) — 누락 시 자동 장착/판매/경매 게이트가 crafted를
  "normal"과 동급(기본값 0)으로 취급해 자동 장착 등급 게이트를 절대 못
  통과하는 실질 버그가 생김(2026-10-04 라운드에서 활성화한 게이트와 충돌).
- `main.gd`: `_item_value()` 판매가 표에 `"crafted": 160`(rare 110~set 220
  사이) 추가, `_cycle_automation()`의 `levels` 배열에 "crafted" 삽입(등급
  순환 UI 노출), 큐브 UI에 "CRAFT" 섹션 추가(레시피 조건 충족하는 매직
  weapon/armor 나열 + 버튼), `_craft_inventory_item(it)` 핸들러.
- `craft.gd`: `CRAFT_RUNE_CATALYST := "Saal"`, `CRAFT_GEM_CATALYST :=
  "diamond:perfect"`, `can_craft(materials, it) -> bool`,
  `craft(rng, materials, it, character_level, item_script) -> bool`(재료
  소모 + `item_script.craft()` 위임, 기존 `reroll()`/`add_sockets()`와 동일
  구조).
- `item.gd repair_cost()`의 `quality_multiplier` 표에 `"crafted": 4`
  추가(rare=3보다 비싸고 set=5(기존 4에서+1)보다 저렴 — set/unique 기존
  값 각각 +1).

## 6. 검증

- `system_tests.gd`에 신규 체크 추가: 매직 웨폰 생성 → craft() 적용 →
  품질=crafted, 고정 접사 2개 존재, 랜덤 접사 개수가 ilvl 구간 확률표 범위
  내(1~4), rank 삽입으로 `should_equip`가 rare보다 crafted를 우선시하는지
  (QUALITY_RANK 순서 확인).
- `main.gd _craft_selftest()`에 craft 레시피 항목 추가 — **반드시 함수
  스코프의 `test_rng`를 사용**([[shared-rng-selftest-pitfall]] 교훈 적용,
  라이브 `_rng` 재사용 금지).
- barb/sorc 표준 오토퀴트, `tools/progression_combat_test.gd`,
  `tools/cube_ui_test.gd`(신규 CRAFT 섹션이 기존 위젯 트리 검사를 깨지
  않는지) 전부 PASS 확인 후 배포(이번 라운드는 웹 동작이 바뀌므로 정직
  원칙상 재배포 필요).
