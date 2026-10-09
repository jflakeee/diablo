# 헬름(투구) 장비 슬롯 신규 추가 — 설계 문서

작성일: 2026-10-09

## 동기

2026-10-09 Korr/Dren/Pyre 룬 드롭 풀 라운드에서 "Gloom Crown"(Korr+Vey, `slot:
"helm"`) 룬워드가 완성 불가능하다는 것을 발견했다. 원인은 룬 수급이 아니라
**"helm" 장비 슬롯 자체가 이 프로젝트에 한 번도 구현된 적이 없다**는 것 —
`git log -S"\"helm\""`로 확인한 결과 `craft.gd`의 `RUNEWORDS` 정의 한 줄에서만
참조되고 그 외 어디에도 등장하지 않았다(소켓/룬워드 시스템 자체는 이미 완비돼
있는데 대상 슬롯이 없어 도달 불가능 — 이 프로젝트에서 반복돼 온 "이미
구현됐지만 실전 연결 안 된 시스템" 패턴과는 결이 다른, "연결할 슬롯 자체가
없는" 케이스).

## 핵심 발견 — 기존 구조가 대부분 제네릭함

탐색 결과 장착 디스패치, 스탯 합산, 저장/복원, 아이콘 렌더링까지 대부분
슬롯 문자열을 하드코딩하지 않고 리스트/딕셔너리 기반으로 순회한다:

- `main.gd _equipment_slot_for_item()`은 ring/charm 듀얼슬롯만 특별 처리하고
  나머지는 `item_slot`을 그대로 반환 — 장착 디스패치 자체는 **코드 추가 불필요**.
- `main.gd _recompute_player()`는 `EQUIPMENT_SLOTS` 배열을 순회해 스탯을
  합산 — helm을 그 배열에 넣기만 하면 **자동 편입**.
- `mercenary.gd normalize_equipment()`/`empty_equipment()`도 `SLOTS` 배열
  기반이라 helm을 거기 추가하면 **저장/복원도 자동**.
- 아이콘은 `main.gd`의 `match slot:` 분기에서 `"weapon"`만 "sword"이고
  나머지는 전부 기본값 "shield" — helm도 **아틀라스 작업 없이** 기본 shield
  아이콘을 그대로 받는다(이전 라운드들의 `[ASSET] "ok": false` 함정이 여기선
  발생하지 않음, grep으로 사전 확인 완료).
- `main.gd` 인벤토리 패널의 "Merc" 버튼 노출 조건(`slot in Mercenary.SLOTS`)도
  이미 제네릭 — `Mercenary.SLOTS`에 helm을 추가하면 버튼도 자동으로 뜬다.

즉 이번 작업은 새 아키텍처를 설계하는 게 아니라 **기존 제네릭 구조에 "helm"
문자열을 끼워 넣는 작업** + 룬/보석 개별 효과·접사 테이블처럼 슬롯별로 수치가
다른 곳에 새 수치를 채우는 작업이다.

## 파일별 변경 사항

### `item.gd`

- `HELM_BASES` 신규 상수(3종, `ARMOR_BASES` 패턴 미러). 베이스명에 "Helm"
  단어를 쓰지 않는다 — `RUNE_ORDER`의 룬 이름 "Helm"(원작 Hel의 이 프로젝트
  명칭, 2026-10-09 소켓 제거 라운드에서 도입)과의 동명이의 혼동을 한 겹 더
  쌓지 않기 위해서다.

  | name | slot | defense | req_level | req_str |
  |---|---|---|---|---|
  | Leather Cap | helm | 5 | 1 | 8 |
  | Bone Skullcap | helm | 9 | 2 | 12 |
  | Iron Sallet | helm | 16 | 5 | 22 |

- `UNIQUES`에 3종 추가(기존 `ARMOR_BASES` 3종 전부에 유니크가 있는 패턴과
  동일하게 helm도 3종 전부):

  | 베이스 | 유니크명 | affixes([min,max]) |
  |---|---|---|
  | Leather Cap | Scoutlight Hood | def[16,24], dex[8,12], ar[20,30] |
  | Bone Skullcap | Marrowguard | def[28,42], life[16,24], str[6,10] |
  | Iron Sallet | Warden's Judgment | def[40,60], res_all[12,18], mana[14,20] |

  `SETS`는 생략 — 기존도 4개 세트 아이템 중 armor 계열은 1개뿐이라 "모든
  슬롯에 세트 추가"가 기존 패턴이 아니다.
- `find_base()`에 `elif slot == "helm": pool = HELM_BASES` 분기 추가(스크랩북
  티켓 복원이 helm도 지원하도록).
- `identify()`의 슬롯 화이트리스트 `["weapon", "armor", "ring", "amulet",
  "charm"]`에 `"helm"` 추가 — 없으면 레어 품질로 드롭된 미감정 헬름을 영원히
  감정할 수 없는 막다른 버그가 생긴다.
- `_eligible()`(접두/접미사 풀링)에 armor/helm 동치 처리 추가: 현재
  `PREFIXES`의 "Reinforced"(+def)가 `slot: "armor"`로만 매칭돼 helm은 이
  접두사를 받을 수 없다. `a_slot == "armor" and slot == "helm"`도 매칭되도록
  한 줄 추가(헬름을 방어구 계열 접사 풀에 편입 — 다른 "any" 접사는 이미
  슬롯 무관이라 영향 없음).
- `roll_drop()` 드롭 브래킷 재조정(아래 "드롭 확률" 절).

### `craft.gd`

- `RUNE_STATS`(6종)·`GEM_STATS`(7종) 각 항목에 `helm` 키 신설(armor 값의
  약 60~65% 축소, 아래 표).
- `can_add_sockets()`의 `String(it.get("slot","")) in ["weapon","armor"]`에
  `"helm"` 추가(**필수** — 없으면 헬름에 소켓을 못 끼워 Gloom Crown이 여전히
  도달 불가능). `can_remove_sockets()`는 슬롯을 보지 않는 구조라 **변경 불필요**
  (설계 발표 때 "2곳 다 수정 필요"라 말했던 것을 이 문서에서 정정 — 실제로는
  `can_add_sockets()` 한 곳만).
- `can_craft()`(제작 레시피)는 `["weapon","armor"]` 그대로 유지 — helm 포함은
  Gloom Crown 목표와 무관한 범위 확장이라 YAGNI로 제외.

RUNE_STATS/GEM_STATS helm 열:

| 룬 | armor 값 | helm 값 |
|---|---|---|
| Ahn | def 15 | def 10 |
| Vey | mana 2 | mana 1 |
| Korr | def 30 | def 18 |
| Saal | mana 3 | mana 2 |
| Dren | res_all 5 | res_all 3 |
| Pyre | res_all 5 | res_all 3 |

| 보석 | armor 값 | helm 값 |
|---|---|---|
| amethyst | str 10 | str 6 |
| diamond | res_all 19 | res_all 12 |
| ruby | life 38 | life 24 |
| sapphire | mana 38 | mana 24 |
| emerald | dex 10 | dex 6 |
| topaz | res_all 0 | res_all 0 (촉매 전용, 변경 없음) |
| skull | life 0 | life 0 (촉매 전용, 변경 없음) |

Gloom Crown(Korr+Vey, 룬워드 완성 보너스 `def:50`) 완성 시 기대 수치:
`def = 50(룬워드) + 18(Korr helm) = 68`, `mana = 1(Vey helm)` — 2026-10-09
룬 드롭 라운드에서 배운 "룬워드 완성 보너스 + 개별 소켓 효과 합산" 규칙을
그대로 적용.

### `main.gd`

- `EQUIPMENT_SLOTS`에 `"helm"` 추가(armor 다음 위치).
- `var _equipped` 초기값과 세이브 로드 복원(두 곳 모두 `"helm": {}`
  additive 추가 — 구버전 세이브는 키가 없으니 `.get("helm", {})`로 기본값
  처리, 스키마 버전 번호 변경 불필요, charm/ring 라운드와 동일한 패턴).
- 인벤토리 패널의 "Equipped" 텍스트 라벨(약 4628행 부근, 전체 장비 목록을
  나열하는 곳)에 `Helm: %s`/`Merc Helm: %s` 추가.
- **전투 중 HUD 라벨(약 2860행 부근)은 의도적으로 변경하지 않는다** — 이
  HUD는 애초에 weapon/armor만 보여주고 ring/amulet/charm도 표시 안 하는
  압축 포맷이라, helm만 예외적으로 추가하면 오히려 일관성이 깨진다.
- 몬스터 드롭 풀(`gems` 배열, 소켓 재료)은 **무관** — 이번 라운드는 베이스
  아이템 카테고리 추가이지 소켓 재료 추가가 아니다.

### `mercenary.gd`

- `SLOTS`에 `"helm"` 추가 → `empty_equipment()`/`normalize_equipment()`/
  저장복원이 모두 자동으로 helm을 지원(두 함수 다 `SLOTS` 순회 기반).
- `stats()`의 `if slot=="weapon" ... elif slot=="armor": result["defense"]
  += ...` 분기에 `elif slot=="helm": result["defense"] += int(item.get
  ("defense",0))`(armor와 동일 처리) 추가.

### 드롭 확률 브래킷(`item.gd roll_drop()`)

현재(60% 드롭 중 분포): weapon 38% / armor 34% / accessory 14% / charm 14%.
변경: **armor에서만 10%p 분리**해 helm 신설.

```
if base_roll < 0.38: weapon      # 변경 없음
elif base_roll < 0.62: armor     # 0.72 → 0.62 (34%→24%)
elif base_roll < 0.72: helm      # 신규 10%
elif base_roll < 0.86: accessory # 변경 없음
else: charm                      # 변경 없음
```

이 변경은 `base_roll` RNG 소비 구조는 그대로지만 **임계값이 바뀌어 같은
난수값이라도 다른 카테고리로 떨어질 수 있다** — seed=42 오토퀴트 결과
(아이템 드롭/인벤토리 상태)가 합법적으로 달라진다. 이는
[[shared-rng-selftest-pitfall]]이 경고하는 "셀프테스트가 몰래 RNG를 더
소비해서 생기는 버그"가 아니라 **의도된 콘텐츠 변경에 의한 정상적 지문
이동**이다 — `kills=0` 같은 이상 신호가 아니라면 재검증 없이 수용한다.

### 건드리지 않는 곳(의도적 비범위, 선례 기반)

- `automation.gd`의 `accepts()`/`should_auto_sell()`는 `slot in ["weapon",
  "armor", "ring", "amulet"]` 화이트리스트에 `charm`도 포함 안 돼 있다(기존
  charm 라운드부터 이미 그랬음). helm도 이 선례를 따라 **추가하지 않는다** —
  blanket auto-sell 대상이 아니라 charm과 동일하게 `pickup_min` 등급 게이트만
  적용받는다(줍기 자체는 영향 없음, 자동판매 범용 수락만 제외).
- `coverage.json`/`data/item_bases.json`: `CHARM_BASES`(실사용 중, 2종)가
  이미 이 JSON 미러에 전혀 반영돼 있지 않은 기존 선례가 있다(coverage는
  "최소 하한"만 검사하므로 실제 베이스가 더 많아도 안전). helm도 같은
  선례를 따라 JSON/coverage.gd의 하드코딩된 `["weapons","armor",
  "accessories"]` 그룹 목록을 건드리지 않는다 — 별도 작업으로 분리.
- `craft.gd`의 `can_craft()`(제작 큐브 레시피): helm 미포함 유지, Gloom
  Crown 목표와 무관.

## 테스트 계획

- `_craft_selftest()`에 Gloom Crown 회귀 테스트 추가(Korr+Vey 소켓 → helm
  슬롯 아이템에서 `def==68`, `mana==1`, `runeword=="Gloom Crown"` 단언).
- `system_tests.gd`에 helm 유니크 범위 롤 검증(기존 weapon/armor 패턴과
  동일하게 `>=min and <=max` 범위 어서션) 1~2개 추가.
- `coverage.gd`의 `[COVERAGE]` 셀프테스트가 영향받지 않는지 확인(건드리지
  않는 파일이므로 회귀 없음을 재확인 수준).
- barb/sorc 오토퀴트, `progression_combat_test.gd`, `cube_ui_test.gd`(Add
  Sockets 버튼이 helm 아이템에도 뜨는지 시나리오 추가) 전부 PASS 확인.
- 드롭 브래킷 변경으로 인한 seed=42 지문 이동은 정상으로 간주하고 `kills=0`
  등 이상 신호만 재검증 대상으로 삼는다(위 "드롭 확률 브래킷" 절 참고).

## 세이브 호환성

모든 변경이 additive(`EQUIPMENT_SLOTS`/`Mercenary.SLOTS`에 새 슬롯 추가,
`.get(key, {})` 기본값 패턴)이므로 세이브 스키마 버전 번호 변경은 불필요 —
구버전 세이브를 로드해도 helm 슬롯은 그냥 빈 상태로 시작한다.
