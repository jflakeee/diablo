# 보물방(특수룸) 설계

작성일: 2026-10-02
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

보스룸 아레나(`2026-10-01-boss-room-arena-design.md`) 작업 당시 "보스 외 특수룸(보물방 등)"을
별도 미착수 항목으로 분리해 뒀다. 이번에 그 특수룸을 구현한다: 보스와 무관하게, 비보스 층의
청크마다 일정 확률로 방 하나를 비워 보너스 아이템과 골드를 떨어뜨리는 보물방을 만든다.

## 2. 완료 조건

1. 비보스 층에서 생성되는 모든 청크(입구 청크 포함, 스트리밍으로 이어지는 후속 청크 포함)는
   25% 확률로 보물방을 가진다. 보스 층에는 전혀 생기지 않는다(보스 아레나와 겹치지 않도록
   완전히 배제).
2. 보물방은 그 청크의 입구/출구 방이 아닌 임의의 방 하나이며, 내부 PILLAR/LOW_WALL 장식이
   전부 제거된 깨끗한 FLOOR다.
3. 플레이어가 보물방이 있는 청크에 처음 들어서면(몬스터가 갓 스폰되는 시점과 동일하게) 레어
   아이템 3개 + 보너스 골드(`150 + dlevel*40`)가 방 중심 근처에 떨어지고, 같은 방에 중복
   스폰되지 않는다.
4. 던전 연결성(입구→출구, 모든 룸 중심 도달 가능)은 보물방이 있어도 깨지지 않는다.
5. 저장/불러오기 시에도 `floor_id`/`act`/`seed`로부터 동일하게 재도출되어 같은 자리에 같은
   보물방이 재생성된다(영속 데이터 없음, 보스 아레나와 동일한 원칙).

## 3. 범위와 비범위

### 범위
- `level_gen.gd`: `carve_treasure_room` 인자, `_carve_treasure_room`(함수 내부에 인라인),
  `_room_obstacle_count` 헬퍼, `treasure_anchor` 반환값
- `world_stream.gd`: 청크별 독립 판정(`_rolls_treasure`), 보스 층 전면 배제,
  `compose_active_grid()`의 `treasure_anchor` 노출(현재 활성 청크 기준)
- `main.gd`: `_treasure_anchor_cell`/`_treasure_looted_cell` 상태, `_spawn_treasure_loot()`,
  몬스터가 새로 스폰되는 모든 지점(최초 진입/다음 층/웨이포인트·포탈 이동/저장 불러오기/
  스트리밍 신규 청크)에 연결

### 비범위
- 보물방 전용 가디언 몬스터나 함정 등 특수 기믹(단순 보너스 드롭 공간)
- 유니크 확정 드롭(보스 전용 보상과 차별화하기 위해 레어 등급으로 제한)
- 저장 스키마 변경(보스 아레나와 동일하게 항상 재도출)

## 4. 상세 설계

### 4.1 생성 (`level_gen.gd`)

보스 아레나 카빙 **뒤**, 반환 직전에 실행한다. 입구(`start`)·출구(`exit_slot`) 슬롯을 피해
임의의 슬롯을 뽑고 `_open_room_interior`(보스 아레나가 이미 쓰던 헬퍼)로 비운다. 순서상
테마 장식·blocked_random 장애물보다 뒤이므로 어떤 액트·모드에서도 내부가 항상 깨끗하다.

### 4.2 판정 (`world_stream.gd`)

청크마다 `_append_chunk`/`restore()`에서 `carve_boss`를 계산하는 바로 옆에 `carve_treasure`를
계산한다: 보스 층이면 무조건 false, 아니면 그 청크의 시드로 독립된 `RandomNumberGenerator`를
만들어 `randf() < 0.25`로 판정한다. 같은 시드로 항상 같은 결론이 나오므로 `setup()`과
`restore()`가 일치하고, LevelGen 내부 rng와는 별개 인스턴스라 생성 시퀀스에 영향을 주지 않는다.

`MAX_ACTIVE_CHUNKS == 1`이라 활성 청크는 항상 하나뿐이다. `compose_active_grid()`는 보스
아레나처럼 "첫 청크"가 아니라 **현재(=마지막=유일한) 청크**의 `treasure_anchor`를 전역 좌표로
노출한다 — 보물방은 입구 청크로 한정되지 않고 스트리밍 중 어떤 청크에도 생길 수 있어서다.

### 4.3 스폰 (`main.gd`)

`_apply_dungeon_layout()`이 매번 `_treasure_anchor_cell`을 갱신한다(초기 생성·스트리밍
전환·저장 복원 세 경로가 전부 이 함수를 거침). `_spawn_treasure_loot()`는 몬스터가 새로
스폰되는 모든 지점(`_spawn_dungeon_monsters()` 호출 3곳 + 스트리밍 신규 청크 1곳) 옆에
연결했다 — 몬스터 스폰이 "이 청크는 처음 본다"의 기존 신호이므로 그대로 재사용했다.
`_treasure_looted_cell`로 같은 좌표에 중복 스폰하지 않는다.

### 4.4 검증

- `level_gen.selftest()`: 5개 시드/액트/모드 조합에서 보물방이 입구·출구와 겹치지 않고,
  내부가 깨끗하고, 연결성이 유지되는지 확인.
- `world_stream.selftest()`: 비보스 층(floor_id=2) 100개 청크 생성 중 적어도 한 번은
  보물방이 등장하는지, 보스 층 입구 청크에는 전혀 생기지 않는지 확인.
- 오토퀴트(진단용, 게임플레이 경로 의존적이라 최종 verdict에는 묶지 않음): barb/sorc 둘 다
  `[TREASURE] rooms_spawned=2`, 전체 `[GD][RESULT] verdict=PASS`.
