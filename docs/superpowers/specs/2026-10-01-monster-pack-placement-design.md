# 몬스터 Pack 군집 배치 설계

작성일: 2026-10-01
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

현재 `main.gd:_spawn_dungeon_monsters()`는 목표 몬스터 수(`count`)만큼 매번 독립적으로
타입과 위치를 랜덤 선택해 던전 전체에 흩뿌린다. 챔피언/유니크 등급도 몬스터 1마리
단위로 개별 확률을 굴린다. 이를 D2 특유의 "같은 종류 몬스터가 한곳에 뭉쳐 나오고,
등급도 무리 전체에 적용되는" pack 배치로 교체한다.

## 2. 완료 조건

1. 신규 생성되는 몬스터는 전부 pack 단위로 배치된다(개별 산발 스폰 없음).
2. 한 pack은 같은 몬스터 타입 2~4마리로 구성되며, 서로 가까운 바닥 타일에 모여 있다.
3. pack 전체 수는 기존 `count` 공식(`clampi(12 + _dlevel*2, 14, 26)`, 보스 층 감소)을
   그대로 채우도록 마지막 pack 크기를 남은 예산에 맞게 자른다.
4. 챔피언/유니크 등급 롤은 pack당 1회만 수행한다. 성공하면 pack 전원이 동일한 등급과
   (유니크의 경우) 동일한 `UNIQ_MODS` 모디파이어를 공유한다.
5. 등급 확률은 기존과 동일(오토퀴트 시 첫 pack 강제 유니크, 그 외 5% 유니크 / 10% 챔피언).
6. 보스 스폰은 pack 로직과 무관하게 기존 방식을 유지한다.
7. 활성 게임 객체 수 상한(128)과 `performance_budget.gd` 통과 기준에 영향 없음 —
   총 몬스터 수가 변하지 않으므로 자연히 충족된다.
8. 저장 스키마 변경 없음(스폰 시점 런타임 로직만 변경, 영속 데이터 아님).
9. 오토퀴트 셀프테스트가 pack 멤버의 군집 거리와 동일 등급 공유를 자동 검증하고
   `[PACK] ... verdict=PASS/FAIL`을 출력하며 최종 `ok` 집계에 포함된다.

## 3. 범위와 비범위

### 범위
- `_spawn_dungeon_monsters()`의 스폰 루프를 pack 단위로 재구성
- `_spawn_one()` / `_apply_rank()`에 pack에서 전달하는 강제 등급/모디파이어 인자 추가
- anchor 주변 바닥 타일을 찾는 신규 헬퍼(실패 시 `_random_floor_cell()` 폴백)
- 오토퀴트 전용 pack 셀프테스트 및 `[PACK]` 결과 출력

### 비범위
- 몬스터 간 충돌/겹침 회피(기존에도 없던 기능, 이번에 추가하지 않음)
- 보스 전용 룸이나 특수룸 지오메트리(별도 미착수 항목)
- 저장/마이그레이션 스키마 변경

## 4. 상세 설계

### 4.1 Pack 구성 루프 (`_spawn_dungeon_monsters`)

기존 `for i in count: _spawn_one(pool[rand], _random_floor_cell())` 루프를 아래로 교체:

```
var spawned := 0
while spawned < count and not pool.is_empty():
    var remaining := count - spawned
    var pack_size := mini(_rng.randi_range(2, 4), remaining)
    var md: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
    var anchor := _random_floor_cell()
    var pack_rank := ""
    var pack_mod := {}
    if _auto_quit and not _forced_rank:
        _forced_rank = true
        pack_rank = "unique"
    else:
        var roll := _rng.randf()
        if roll < 0.05: pack_rank = "unique"
        elif roll < 0.15: pack_rank = "champion"
    if pack_rank == "unique":
        pack_mod = UNIQ_MODS[_rng.randi_range(0, UNIQ_MODS.size() - 1)]
    var pack_id := spawned  # 호출 시점의 unique 정수 ID로 충분
    for n in pack_size:
        var cell := anchor if n == 0 else _pack_member_cell(anchor, 3)
        _spawn_one(md, cell, pack_rank, pack_mod, pack_id)
    spawned += pack_size
```

보스 스폰 블록은 변경하지 않고 이 루프 뒤에 그대로 둔다.

### 4.2 `_pack_member_cell(anchor, radius)`

`anchor` 기준 `±radius` 범위에서 `_grid` 값이 `FLOOR(1)`인 타일을 최대 20회 시도로 찾는다.
전부 실패하면 `_random_floor_cell()`로 폴백해 pack 형성이 막다른 공간에서 멈추지 않게 한다.

### 4.3 `_spawn_one` / `_apply_rank` 시그니처 변경

- `_spawn_one(md, cell, forced_rank: String = "", forced_mod: Dictionary = {}, pack_id: int = -1)`:
  기존 개별 `roll`/`_apply_rank` 호출 블록을 제거하고, `forced_rank`가 비어있지 않으면
  `_apply_rank(m, forced_rank, forced_mod)`를 호출한다. `pack_id >= 0`이면 `m.set_meta("pack_id", pack_id)`.
- `_apply_rank(m, rank, mod_override: Dictionary = {})`: 유니크 분기에서 `mod_override`가
  비어있지 않으면 그 값을 쓰고, 비어있으면(향후 호출 대비 하위호환) 기존처럼 랜덤 롤.

### 4.4 오토퀴트 셀프테스트

`_spawn_dungeon_monsters()` 직후(오토퀴트 한정) `pack_id` 메타 기준으로 몬스터를 그룹화해:
- 그룹 내 모든 멤버의 상호 타일 거리가 `radius`(3) + 여유 이내인지
- 그룹 내 `rank`/`umod` 메타가 모두 동일한지

를 검증해 `_pack_selftest_ok`에 저장하고 `[PACK] packs=%d min_size=%d max_size=%d verdict=%s`를
출력한다. 최종 `ok` 집계(`main.gd` RESULT 블록)에 `_pack_selftest_ok`를 추가한다.
