# 유니크 1게임 1드롭 제한 + 재굴림 비용 품질별 분리

작성일: 2026-10-08
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 배경

[d2-item-system-reference.md](../../research/d2-item-system-reference.md)와
[d2-horadric-cube-recipes.md](../../research/d2-horadric-cube-recipes.md) 리서치
체크리스트 중, 사용자에게 확인한 3개 항목(해골 재료 용도 전환, 소켓 레시피
장비별 세분화, 노말/익셉셔널/엘리트 베이스 체계)은 전부 "현재 유지/보류"로
확정됐다. 남은 항목 중 **코드 변경 없이 이미 충족된 것**과 **안전하게 바로
반영 가능한 것**을 이번 라운드에서 처리한다.

## 2. 이미 충족 확인(코드 변경 없음)

- **매직 아이템 접두사/접미사 확률 25%/25%/50%**: `item.gd _apply_quality_roll()`의
  `r<0.5→접미사만 / r<0.75→접두사만 / else→둘다`가 원작 "접미사만 50% / 접두사만
  25% / 둘다 25%"와 정확히 일치. 변경 불필요.
- **레어/매직 접사 그룹 배타**: 원작은 "그룹"(같은 스탯 계열의 여러 수치 구간)당
  1개만 허용. 이 프로젝트의 `PREFIXES`/`SUFFIXES` 테이블은 각 그룹이 이미 단일
  `stat` 필드로 표현되고(`ed` 그룹=Serrated/Ruinous/Savage 등), `_roll_affixes()`가
  `used[stat]`로 같은 stat 중복을 막는다 — 테이블 구조상 그룹=스탯이라 이미 동일한
  효과. 변경 불필요.
- **세트 부분 보너스**: `item.gd equipped_set_bonus()`가 `SET_BONUSES[set_id]`를
  필요 개수(`required`)별 tier dictionary로 순회하며 이미 지원. 현재 세트가 2부위
  뿐이라 "부분=전체"처럼 보이지만 인프라 자체는 다단계 tier를 지원 — 세트 확장
  시 추가 작업 없이 동작. 변경 불필요.

## 3. 이번 라운드 구현 범위

### A. 유니크 아이템 1게임 1드롭 제한

원작: 같은 유니크 아이템은 한 게임 내에서 몬스터/상자로부터 두 번 이상 드롭되지
않는다. 현재 `Item.roll_drop()`은 순수 확률 기반이라 같은 유니크가 중복 드롭될
수 있다.

**구현**: `main.gd`에 `_dropped_uniques: Dictionary = {}` 멤버 추가(새 게임 시작
시 초기화). `Item.roll_drop()`에 `dropped_uniques: Dictionary = {}` 선택 인자를
추가 — 유니크 후보 베이스가 이미 이 딕셔너리에 있으면 유니크 판정에서 제외하고
**기존 확률 캐스케이드가 자연히 레어로 떨어뜨린다**(코드 구조상 `elif` 체인이
이미 "유니크 조건 불충족 시 다음 등급 조건 재평가"로 짜여 있어 별도 분기 불필요).
유니크가 실제로 생성되면 `dropped_uniques[base_name] = true`로 기록.

**비범위**: 저장/로드 간 영속화는 하지 않는다(세이브 스키마 변경 없음) — 이
프로젝트에서 "한 게임"은 세션 단위(브라우저 탭 유지)로 해석하고, 저장 불러오기는
사실상 새 게임 재개에 가깝다고 보는 기존 암묵적 관례를 따른다. 상자(Chest) 드롭
경로가 따로 있다면 동일 `_dropped_uniques`를 공유해야 하지만, 현재 드롭 경로는
몬스터 처치 한 곳뿐이라 추가 배선 불필요(코드 확인 후 실제로 1곳만 있으면 그대로,
여러 곳이면 모두 같은 멤버를 참조하도록 통일).

### B. 재굴림(Reroll) 비용 품질별 분리

원작: 레어 재굴림 6개, 매직 재굴림 3개(둘 다 최상급 해골). 현재 프로젝트는
재료가 토파즈이고(확인된 결정 유지) 비용은 품질 무관 고정 3개.

**구현**: `craft.gd`의 `REROLL_COST` 고정값을 품질별 딕셔너리로 교체
(`REROLL_COST := {"magic": 3, "rare": 6}`, 원작의 3:6 비율 유지, 재료는 토파즈로
유지). `can_reroll()`/`reroll()`이 아이템 품질을 보고 해당 비용을 조회하도록 수정.

## 4. 검증

- `system_tests.gd`에 유니크 드롭-once 체크 추가: 같은 RNG 시드로 충분히 많은
  롤을 돌려 `dropped_uniques`를 공유했을 때 같은 base의 유니크가 2번 이상 나오지
  않는지 확인. 기존 `roll_drop` 관련 체크(line 112 부근)와 나란히 배치.
- `craft.gd` 관련 기존 `_craft_selftest()` 리롤 체크(`[P4] reroll`)가 매직 기준
  3개 소비를 가정하고 있다면 그대로 통과해야 하고, 레어 기준 6개 소비 체크를
  신규 추가.
- barb/sorc 표준 오토퀴트 + `tools/progression_combat_test.gd` 회귀 확인.

## 5. 구현 중 발견한 회귀와 수정(2026-10-08)

5b 리롤 비용 테스트를 `main.gd _craft_selftest()`에 추가한 직후
`autoquit barb`가 `[GD][RESULT] verdict=FAIL`(`kills=0`)로 실패했다. 재현
실행(동일 시드)에서도 `champs=2 uniques=5 kills=0`으로 완전히 동일한 결과가
나와 플레이키가 아님을 확인했고, 변경분을 스태시하고 돌린 베이스라인은
`kills=14 dungeon_level=2 verdict=PASS`로 정상이었다 — 즉 내 코드가 원인.

원인: `_craft_selftest()`는 처음부터(5/6/7번 항목) 라이브 던전과 같은 `_rng`를
공유해 왔다. `autoquit` 검증 경로는 `_rng.seed = 42`로 고정되는데, 이 함수가
`_start_game()` 이전에 실행되므로 여기서 소비하는 난수 횟수가 바뀌면 이후
던전의 몬스터 스폰·챔피언 구성·전리품까지 전부 다른 분기로 틀어진다. 신규
5b 항목이 `Item.generate`+`Craft.reroll` 호출 쌍을 하나 더 끼워 넣으면서,
seed=42 한정으로 플레이어가 50초 오토퀴트 창 안에 몬스터를 한 번도 마주치지
못하는 레이아웃으로 밀려버렸다.

수정: `_craft_selftest()` 전체(5/5b/6/7번 항목)가 라이브 `_rng` 대신 함수
스코프의 `test_rng := RandomNumberGenerator.new(); test_rng.seed = 1`을
쓰도록 변경 — 크래프트 수학 검증이 더 이상 던전 RNG 스트림에 끼어들지 않는다.
수정 후 동일 시드로 재검증: `kills=15 dungeon_level=2 verdict=PASS`.

**교훈**: pre-game 셀프테스트가 라이브 RNG를 공유하는 구조는 향후에도 같은
사고를 반복시킨다 — 셀프테스트를 추가/수정할 때는 반드시 전용 로컬 RNG를
쓸 것(`system_tests.gd`는 애초부터 이 패턴을 따르고 있었음).
