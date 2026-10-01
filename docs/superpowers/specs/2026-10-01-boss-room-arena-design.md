# 보스룸 전용 아레나 설계

작성일: 2026-10-01
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

보스는 현재(`main.gd:_spawn_dungeon_monsters`) 일반 몬스터와 동일하게 `_random_floor_cell()`로
던전 어딘가의 랜덤 바닥칸에 스폰된다. 전용 룸 지오메트리가 없어 일반 방과 체감이 다르지 않다.
액트 마지막 층(보스 층)의 첫 청크에 D2식 "넓게 트인 보스룸"을 만들고 보스를 그 중심에 고정
스폰한다.

## 2. 완료 조건

1. 보스 층(`_level_in_act() == ACT_LEN`)의 첫 청크(입구 청크)는 3x3 룸 그리드의 중앙 룸과
   상하좌우 인접 4룸 사이 벽이 완전히 열려 십자(+) 모양의 넓은 개활지를 이룬다.
2. 이 아레나 내부(5개 룸 분량)는 액트 테마의 PILLAR/LOW_WALL 장식이 전혀 없는 순수 FLOOR다
   (직선/랜덤/장애물 랜덤 생성 모드 전부 포함).
3. 보스는 아레나 중심 타일에 스폰된다. 아레나가 없거나(구형 저장·레거시 경로) 중심 타일이
   막혀 있으면 기존처럼 `_random_floor_cell()`로 대체한다.
4. 보스가 아닌 층과 보스 층의 2번째 이후 청크는 아레나를 만들지 않는다(출구가 보스 처치
   전까지 잠겨 있어 플레이어가 입구 청크를 벗어나기 전에 보스와 마주치는 것이 일반적이다).
5. 보스 여부는 저장된 플래그가 아니라 `floor_id`/`act`에서 그때그때 다시 계산한다. 저장/불러오기
   후에도 동일한 시드로 동일한 아레나가 재생성되어야 한다.
6. 던전 연결성(입구→출구, 모든 룸 중심 도달 가능)은 아레나 추가 후에도 깨지지 않는다
   (벽을 더 여는 것은 연결성을 해치지 않는다).
7. 오토퀴트 셀프테스트가 보스 층에서 아레나 중심 사용 여부를 검증하고 `[BOSS_ROOM] ...
   verdict=PASS/FAIL`을 출력하며 최종 `ok` 집계에 포함된다.

## 3. 범위와 비범위

### 범위
- `level_gen.gd`: `generate_chunk`/`_generate_region`에 `carve_boss_arena` 인자, 아레나 카빙
  헬퍼, `boss_anchor` 반환값, 셀프테스트 확장(3개 액트 테마 + blocked_random 모드)
- `world_stream.gd`: 보스 층 판정(`_is_boss_floor`), 입구 청크(`sequence == 0`)에만 카빙 적용,
  `restore()`에서도 동일하게 재도출, `compose_active_grid()`가 전역 좌표 `boss_anchor` 노출,
  셀프테스트에 보스 층 스냅샷/복원 케이스 추가
- `main.gd`: `_boss_anchor_cell` 보관, 보스 스폰 시 아레나 중심 우선 사용, 오토퀴트 셀프테스트

### 비범위
- 보스 외 특수룸(보물방 등) — 별도 미착수 항목
- 보스전 전용 기믹(소환 웨이브, 특수 바닥 효과 등)
- 저장 스키마 변경(아레나는 항상 재생성되므로 영속 데이터 불필요)

## 4. 상세 설계

### 4.1 `level_gen.gd`

`generate_chunk(seed_val, act, mode, carve_boss_arena=false)` → `_generate_region(..., carve_boss_arena)`.
`_generate_region`은 테마 장식(PILLAR/LOW_WALL)과 `MODE_BLOCKED_RANDOM`의 장애물 배치가 전부
끝난 **뒤**(반환 직전)에 `carve_boss_arena`가 참이면 `_carve_boss_arena(grid, slots)`를 호출한다.
순서가 중요하다 — 먼저 카빙하면 이후 장식/장애물 단계가 다시 덮어써 아레나가 더러워진다.

`_carve_boss_arena(grid, slots)`:
- 중앙 슬롯 `(slots/2, slots/2)`과 그 상하좌우 인접 슬롯(그리드 범위 밖이면 스킵) 각각의
  내부를 `_open_room_interior`로 FLOOR 재설정(PILLAR/LOW_WALL 제거).
- 중앙과 각 인접 슬롯 사이 경계를 `_open_full_wall`로 전체 폭(내부 7타일) 개방 — 기존
  `_carve_door`의 3타일 문과 달리 두 룸을 사실상 하나의 공간으로 합친다.
- 중앙 슬롯 중심 타일(`_slot_center`)을 `boss_anchor`로 반환.

3x3 청크(`generate_chunk`가 쓰는 `slots=3`)에서는 중앙(1,1)의 인접 4칸이 항상 그리드 범위
안이므로 코너 4룸을 제외한 5룸이 아레나가 된다. `generate()`(9x9 전체 던전, 현재 실제 플레이
경로에서는 쓰이지 않음)는 항상 `carve_boss_arena=false`로 호출해 동작이 바뀌지 않는다.

### 4.2 `world_stream.gd`

- `ACT_LEN := 3` 상수를 `main.gd`와 동일한 값으로 중복 선언(의존성 추가 없이 독립적으로
  보스 여부를 계산하기 위함). `_is_boss_floor() -> bool`은 `main.gd:_level_in_act()`와
  동일한 공식(`((floor_id - 1) % ACT_LEN) + 1 == ACT_LEN`)을 `floor_id`로 계산한다.
- `_append_chunk`: `carve_boss := sequence == 0 and _is_boss_floor()`를 계산해
  `LevelGen.generate_chunk(seed, act, mode, carve_boss)`에 전달하고, 반환된 `boss_anchor`를
  청크 딕셔너리에 저장한다.
- `restore()`: 각 청크를 시드로부터 재생성할 때도 동일하게 `carve_boss`를 다시 계산해
  전달한다. 저장 데이터에 아레나 관련 필드를 추가하지 않는다 — `floor_id`/`act`/`seed`/
  `sequence`만으로 결정론적으로 같은 아레나가 재생성된다.
- `compose_active_grid()`: 첫 청크(`first`)가 유효한 `boss_anchor`를 가지면 청크 원점을 더해
  전역 좌표로 변환해 `"boss_anchor"` 키로 반환(없으면 `Vector2i(-1,-1)`).

### 4.3 `main.gd`

- `_boss_anchor_cell` 멤버 변수를 `_apply_dungeon_layout(lvl)`에서 매 레이아웃 적용마다
  `lvl.get("boss_anchor", Vector2i(-1,-1))`로 갱신(초기 생성·스트리밍 전환·저장 복원 세
  호출 경로 전부 이 함수 하나를 거치므로 별도 분기 불필요).
- `_spawn_dungeon_monsters()`의 보스 분기: `_boss_anchor_cell`이 유효하고(`(-1,-1)` 아님)
  현재 그리드 범위 안의 FLOOR 타일이면 그 칸에 스폰, 아니면 기존 `_random_floor_cell()`로
  대체.
- 오토퀴트 한정으로 `[BOSS_ROOM] anchor=.. boss_cell=.. used_arena=.. verdict=..`를 출력하고
  `_boss_room_selftest_ok`(아레나가 있는데 쓰지 못한 경우에만 FAIL)를 최종 `ok` 집계에 포함.
