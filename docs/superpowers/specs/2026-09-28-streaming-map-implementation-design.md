# 스트리밍 던전 및 테마 유지 재생성 상세 설계

작성일: 2026-09-28  
대상: `prototype/game_dungeon`  
상태: 구현 기준 확정

## 1. 목표

기존의 9×9 방, 81×81 타일 전체 생성 방식을 다음 구조로 교체한다.

- 최초에는 3×3 방으로 구성된 청크 하나만 생성한다.
- 현재 선두 청크에서 방 3개가 밝혀지면 다음 3×3 청크를 생성한다.
- 활성 청크는 원칙적으로 최대 3개, 즉 방 27개로 제한한다.
- 네 번째 청크가 추가되면 가장 오래된 청크를 제거한다.
- 청크 사이 이동 지점은 방 중앙의 별도 출구가 아니라 외곽 벽에 뚫린 통로다.
- 홈 포탈 복귀와 웨이포인트 이동은 과거 배치를 복원하지 않고 목적지 테마만 유지한 새 지형을 생성한다.
- 액트, 퀘스트, 보스 처치, 캐릭터 및 경제 진행은 지형 재생성과 분리하여 보존한다.

이 설계에서 `방`은 9×9 타일 공간, `청크`는 3×3 방(27×27 타일), `활성 창`은 최대 3개 청크를 뜻한다.

## 2. 완료 조건

1. 새 게임은 정확히 9개 방만 렌더링한다.
2. 선두 청크의 서로 다른 방 3개가 밝혀지기 전에는 다음 청크를 만들지 않는다.
3. 조건 충족 후 다음 9개 방이 결정론적으로 생성되고 기존 청크와 벽 통로로 연결된다.
4. 네 번째 청크 생성 직후 가장 오래된 9개 방과 그 런타임 노드가 제거된다.
5. 장시간 진행해도 활성 방은 27개, 활성 타일은 2,187개를 초과하지 않는다.
6. 청크 연결 방향은 상·하·좌·우를 사용할 수 있으며 활성 또는 과거 청크와 겹치지 않는다.
7. 홈 포탈과 웨이포인트 재입장 시 배치는 달라지지만 테마는 동일하다.
8. 맵 재생성으로 퀘스트 보상, 보스 보상 및 고정 보상을 중복 획득할 수 없다.
9. 생성·삭제 시 스킬 이펙트, 투사체, 궤적, 적, 바닥 아이템이 이전 좌표에 남지 않는다.
10. 기존 버전 저장 파일에서 캐릭터 진행은 보존되고 구형 맵 상태만 안전하게 폐기된다.

## 3. 범위와 비범위

### 범위

- 청크 생성, 연결, 방문 판정, 제거 및 좌표 재기준화
- 액트별 테마 유지
- 홈 포탈·웨이포인트 재생성
- 시야, 안개, 미니맵, A*, 몬스터, 바닥 아이템 연동
- 저장 스키마 마이그레이션
- 결정론·메모리 상한·보상 중복 자동 테스트

### 비범위

- 서버 권위형 멀티플레이 동기화
- 삭제된 일반 청크의 완전한 월드 상태 복원
- 홈 포탈을 통한 동일 배치 복귀
- 무제한 미니맵 상세 타일 보존

삭제된 청크는 상세 상태를 복원하지 않는다. 진행 이력과 테마, 완료 보상 원장만 남긴다.

## 4. 사용자 경험 규칙

### 4.1 최초 생성

- 플레이어는 첫 청크의 입구 벽 안쪽 2타일 지점에서 시작한다.
- 첫 청크에는 9개 방이 있고 다음 청크용 출구 벽은 처음에는 닫혀 있다.
- 출구 방향 후보는 현재 청크의 외곽 벽 네 방향이다.

### 4.2 방이 밝혀지는 기준

방의 중심 셀이 현재 시야에 처음 포함되면 해당 방을 `revealed`로 기록한다. 단순히 인접 방 벽이 안개에서 희미하게 보이는 것은 공개로 계산하지 않는다.

```text
room_x = floor(local_tile_x / 9)
room_y = floor(local_tile_y / 9)
room_id = chunk_id + ":" + room_x + "," + room_y
```

청크마다 공개된 방 ID 집합을 유지한다. 선두 청크에서 집합 크기가 3이 되는 순간 한 번만 `frontier_ready` 이벤트를 발생시킨다.

### 4.3 다음 청크 생성

`frontier_ready` 처리 순서는 다음과 같다.

1. 전투 프레임 종료까지 대기한다.
2. 다음 방향과 벽 통로 위치를 결정한다.
3. 새 청크 데이터를 생성한다.
4. 기존 선두 청크와 새 청크 양쪽 벽에 동일한 3타일 통로를 판다.
5. 합성 격자와 A*를 다시 만든다.
6. 새 청크의 타일, 안개, 몬스터를 생성한다.
7. 네 번째 활성 청크라면 가장 오래된 청크를 제거한다.
8. 미니맵과 저장 스냅샷을 갱신한다.

### 4.4 벽 통로

- 통로 폭은 3타일이다.
- 통로 중심은 연결 벽과 맞닿은 세 방 중 하나의 중심을 기준으로 선택한다.
- 중심에 `-1, 0, +1` 타일 변위를 적용할 수 있다.
- 모서리 2타일 이내에는 통로를 만들지 않는다.
- 양쪽 청크의 경계 셀과 경계 안쪽 한 셀을 모두 바닥으로 만든다.
- 통로가 열리기 전에는 벽이므로 이동, 직선 공격, 일반 투사체가 통과하지 못한다.
- 통로가 열린 뒤에는 기존 `_walkable()`과 LOS 규칙만으로 자연스럽게 통과한다.
- 별도 순간이동은 사용하지 않는다. 청크 전환은 벽 통로를 걸어서 넘는 연속 이동이다.

## 5. 청크 방향 선택

방향은 `NORTH`, `EAST`, `SOUTH`, `WEST` 네 종류다. 다음 가중치를 적용한다.

| 조건 | 가중치 |
|---|---:|
| 직전과 같은 방향 | 2 |
| 좌회전 또는 우회전 | 4 |
| 직전 방향의 반대 | 1 |
| 이미 사용한 청크 좌표 | 0 |
| 활성 청크와 겹침 | 0 |

후보가 모두 막힌 경우 다음 순서로 복구한다.

1. 과거 좌표와 겹치지 않는 후보 중 원점에서 가장 멀어지는 방향 선택
2. 그래도 없으면 선두 청크에서 빈 좌표까지 1개짜리 연결 청크를 삽입
3. 삽입 청크도 일반 9방 청크로 계산하고 동일한 제거 규칙을 적용

무한 진행에서 결정론을 유지하기 위해 선택 RNG는 프레임 RNG와 분리한다.

```text
chunk_seed = stable_hash(run_seed, floor_id, generation_epoch, sequence)
gate_seed  = stable_hash(chunk_seed, previous_chunk_id, direction)
```

언어 런타임의 가변 `hash()` 대신 고정 64비트 혼합 함수를 사용한다.

## 6. 데이터 모델

새 파일 `world_stream.gd`를 추가한다.

```gdscript
class_name WorldStream
extends RefCounted

const ROOM_SIZE := 9
const CHUNK_ROOMS := Vector2i(3, 3)
const CHUNK_TILES := Vector2i(27, 27)
const REVEAL_THRESHOLD := 3
const MAX_ACTIVE_CHUNKS := 1

var run_seed: int
var floor_id: int
var act: int
var theme_id: String
var generation_epoch: int
var next_sequence: int
var active_chunks: Array[Dictionary]
var used_chunk_coords: Dictionary
var reward_ledger: Dictionary
```

청크 레코드 형식:

```gdscript
{
    "id": "floor:epoch:sequence",
    "sequence": 0,
    "coord": Vector2i(0, 0),
    "seed": 12345,
    "theme_id": "cinder_catacombs",
    "entry_side": "west",
    "exit_side": "east",
    "gate_offset": 13,
    "revealed_rooms": {},
    "frontier_consumed": false,
    "grid": [],
    "monster_states": [],
    "ground_states": []
}
```

`main.gd`에는 다음 상태를 둔다.

```gdscript
var _world_stream: WorldStream
var _stream_grid_origin := Vector2i.ZERO
var _stream_generation_pending := false
var _stream_chunk_nodes := {}
```

## 7. LevelGen 변경

`level_gen.gd`의 책임을 두 단계로 분리한다.

### 7.1 `generate_chunk()`

```gdscript
static func generate_chunk(seed_value: int, act: int, theme_id: String) -> Dictionary
```

- 항상 3×3 방과 27×27 타일을 생성한다.
- 내부 9개 방은 무작위 DFS로 모두 연결한다.
- 내부 순환 연결을 1~3개 추가한다.
- 외곽 연결 통로는 만들지 않는다.
- 액트 테마에 따라 벽, 낮은 벽, 기둥 규칙을 적용한다.

### 7.2 `compose_active_grid()`

```gdscript
static func compose_active_grid(chunks: Array[Dictionary]) -> Dictionary
```

반환값:

```gdscript
{
    "grid": Array,
    "width": int,
    "height": int,
    "grid_origin": Vector2i,
    "chunk_rects": Dictionary
}
```

활성 청크의 전역 타일 좌표 경계 상자를 계산하고, 비어 있는 영역은 벽으로 채운다. 청크 타일을 복사한 뒤 연속 청크 사이의 벽 통로를 마지막에 판다.

## 8. 좌표 체계와 재기준화

세 가지 좌표를 구분한다.

- 청크 좌표: 무한 정수 격자상의 `Vector2i`
- 전역 타일 좌표: `chunk_coord * 27 + local_tile`
- 활성 격자 좌표: `global_tile - grid_origin`

현재 `Actor.gx/gy`, `_grid`, A*는 활성 격자 좌표를 계속 사용하여 기존 전투 코드를 최소 변경한다.

오래된 청크 삭제로 `grid_origin`이 바뀌면 다음 객체에 동일한 델타를 적용한다.

```text
delta = old_grid_origin - new_grid_origin
```

- 플레이어와 용병 `gx/gy`
- 생존 몬스터 좌표와 캐시된 A* 경로
- 바닥 아이템 `gx/gy` 메타데이터
- 시체 표식
- 투사체 노드와 궤적 포인트
- 카메라 위치
- 현재 보이는 셀과 탐험 셀 키

좌표 이동 중에는 `_stream_generation_pending`을 켜서 한 프레임 동안 이동·공격·AI 갱신을 중지한다.

## 9. 청크 제거

네 번째 청크가 추가된 뒤 제거 후보는 `active_chunks.front()`다.

제거 순서:

1. 후보 청크 범위에 플레이어가 없는지 확인한다.
2. 후보의 살아 있는 몬스터를 런타임에서 제거한다.
3. 후보의 미습득 바닥 아이템을 제거한다.
4. 후보에 속한 전투 이펙트와 투사체를 제거한다.
5. 타일 노드와 안개 상세 데이터를 제거한다.
6. 청크 요약을 `retired_chunks`에 기록한다.
7. 활성 목록에서 제거하고 합성 격자를 재구성한다.
8. 이전 청크 쪽 연결 벽을 봉쇄한다.

청크 요약에는 다음 값만 남긴다.

```gdscript
{
    "id": String,
    "coord": Vector2i,
    "theme_id": String,
    "revealed_count": int,
    "kills": int,
    "reward_ids": Array
}
```

일반 몬스터와 바닥 아이템은 복원하지 않는다. 자동 삭제 직전에 희귀 이상 아이템이 바닥에 있으면 5초 경고를 표시하되 진행을 막지는 않는다.

## 10. 시야와 안개

현재 `_explored_by_floor[floor_id]`의 평면 셀 사전을 청크별 구조로 교체한다.

```gdscript
explored_by_floor[floor_id] = {
    "generation_epoch": 4,
    "chunks": {
        chunk_id: {
            "cells": {},
            "rooms": {}
        }
    }
}
```

`_update_visibility()`는 다음을 수행한다.

1. 활성 격자 기준 가시 셀 계산
2. 셀을 전역 타일 좌표로 변환
3. 소속 청크와 방 계산
4. 해당 청크의 탐험 셀 기록
5. 방 중심 셀이 보이면 방 공개 처리
6. 선두 청크 공개 방이 3개면 지연 생성 요청

삭제된 청크의 상세 `cells`는 제거하고 `revealed_count`만 요약에 남긴다.

## 11. 몬스터와 바닥 아이템

몬스터 및 아이템은 생성 청크 ID를 메타데이터로 가진다.

```gdscript
node.set_meta("chunk_id", chunk_id)
```

새 청크 생성 시 해당 청크 내부에만 몬스터 무리를 생성한다. 입구와 출구 통로 6타일 이내에는 생성하지 않는다.

- 일반 청크: 4~8개 무리
- 무리당 일반 몬스터: 모바일 효과 품질에 따라 2~4마리
- 보스 청크: 일반 무리 수를 절반으로 줄이고 보스 공간 확보
- 목격 전 정지 규칙은 그대로 유지

청크 제거는 `chunk_id`로 필터링하므로 다른 활성 청크의 몬스터와 아이템에 영향을 주지 않는다.

## 12. 홈 포탈

홈 포탈은 동일 배치로 돌아가는 저장점이 아니다. 던전에서 마을로 이동할 때 다음 목적지 명세만 저장한다.

```gdscript
{
    "floor_id": int,
    "act": int,
    "theme_id": String,
    "difficulty": int,
    "return_epoch": int,
    "entry_side": String
}
```

마을에서 귀환 포탈을 사용하면:

1. 기존 활성 청크와 런타임 지형 상태를 폐기한다.
2. `generation_epoch`을 1 증가시킨다.
3. 같은 `floor_id`, `act`, `theme_id`, 난이도로 새 첫 청크를 생성한다.
4. 플레이어를 외곽 입구 벽 안쪽에 배치한다.
5. 완료된 퀘스트와 처치 완료 보스는 생성하지 않는다.
6. 귀환 포탈을 소비한다.

## 13. 웨이포인트

웨이포인트 목적지는 다음 값을 제공한다.

```gdscript
{
    "waypoint_id": String,
    "act": int,
    "floor": int,
    "theme_id": String,
    "entry_side": String
}
```

웨이포인트 이동도 새 `generation_epoch`을 사용하여 새 맵을 만든다. 동일 웨이포인트를 반복 사용해도 테마는 같고 방 배치, 내부 문, 기둥, 몬스터 위치는 달라진다.

웨이포인트 오브젝트는 첫 청크의 입구 벽 안쪽 안전 영역에 생성한다. 도착 직후 3초 동안 적을 생성하지 않는 안전 반경 6타일을 적용한다.

## 14. 테마 규약

테마는 지형 생성과 콘텐츠 선택의 불변 입력이다.

| Act | theme_id | 지형 규칙 | 기본 색상 |
|---:|---|---|---|
| 1 | `cinder_catacombs` | 높은 벽 중심 던전 | 녹색·회갈색 |
| 2 | `sunken_wilds` | 낮은 벽과 야외 공간 | 황토·갈색 |
| 3 | `storm_ossuary` | 평지와 기둥 | 청회색·보라색 |

재생성 시 유지되는 값:

- `theme_id`, 액트, 난이도, 층 단계
- 타일 팔레트와 장애물 유형
- 액트 몬스터 풀
- 퀘스트와 보스 완료 상태

재생성되는 값:

- 청크와 방 연결 구조
- 벽 통로 위치
- 기둥과 낮은 벽 위치
- 일반 몬스터, 상자 및 비고정 오브젝트 위치

## 15. 보상 중복 방지

재생성 가능한 일반 몬스터의 일반 드롭은 허용한다. 다음 보상은 영구 원장으로 한 번만 지급한다.

- 퀘스트 완료 보상
- 액트 보스 최초 처치 보상
- 웨이포인트 최초 발견 보상
- 고정 상자와 이벤트 보상
- 최초 클리어 스킬 포인트

보상 ID 형식:

```text
quest:{quest_id}
boss:{difficulty}:{act}:{boss_id}
waypoint:{waypoint_id}
event:{floor_id}:{event_id}
```

`reward_ledger`에 ID가 있으면 지형 오브젝트는 표시할 수 있지만 보상은 다시 지급하지 않는다.

## 16. 저장 스키마

`SaveStore.CURRENT_VERSION`을 15로 올린다.

추가 필드:

```gdscript
"world_stream": {
    "run_seed": int,
    "floor_id": int,
    "act": int,
    "theme_id": String,
    "generation_epoch": int,
    "next_sequence": int,
    "active_chunks": Array,
    "used_chunk_coords": Array,
    "reward_ledger": Dictionary
}
```

런타임 노드, 텍스처, 전체 합성 격자와 A*는 저장하지 않는다. 청크 시드와 공개 방 정보로 다시 만든다.

### v14 → v15 마이그레이션

- 캐릭터, 장비, 인벤토리, 골드, 퀘스트, 웨이포인트, 컬렉션은 유지한다.
- 기존 `floor_states`와 셀 단위 `explored_by_floor`는 구형 지형 좌표이므로 폐기한다.
- 현재 액트와 층을 기반으로 새 테마를 선택한다.
- `generation_epoch = 0`, `next_sequence = 1`인 첫 청크를 생성한다.
- 마이그레이션 완료 토스트를 한 번 표시한다.

## 17. 기존 함수 변경표

| 파일/함수 | 변경 |
|---|---|
| `level_gen.gd::generate()` | 호환 래퍼로 유지하고 내부적으로 청크 생성 API 사용 |
| `main.gd::_generate_dungeon()` | 스트림 초기화 또는 저장 스냅샷 복원 후 활성 격자 합성 |
| `main.gd::_update_visibility()` | 청크별 탐험 기록 및 3방 공개 트리거 추가 |
| `main.gd::_build_astar()` | 활성 합성 격자만 대상으로 재구축 |
| `main.gd::_spawn_dungeon_monsters()` | 전체 맵이 아니라 청크 단위 생성으로 분리 |
| `main.gd::_clear_map_effects()` | 제거 청크 범위 또는 전체 스트림 초기화 모드 지원 |
| `main.gd::_toggle_town_portal()` | 좌표 복귀 대신 동일 테마 새 세대 생성 |
| `main.gd::_travel_waypoint()` | 목적지 테마의 새 세대 생성 |
| `main.gd::_capture_floor_state()` | 청크 스트림 스냅샷과 보상 원장 저장 |
| `main.gd::_build_minimap_tex()` | 활성 청크만 합성하고 삭제 청크는 축약 흔적 처리 |
| `save_store.gd::_migrate()` | v15 스트림 상태 기본값 추가 |

## 18. 이벤트 순서와 동시성

맵 구조 변경은 `_process()` 또는 전투 콜백 중 즉시 실행하지 않는다.

```text
visibility update
  → request_chunk_generation
  → call_deferred(_apply_stream_transition)
  → input/AI lock
  → clear affected projectiles and FX
  → append/evict chunks
  → compose grid
  → rebase entities
  → rebuild A*
  → rebuild fog/minimap
  → spawn new chunk content
  → unlock input/AI
```

동일 프레임에서 여러 번 요청되어도 `_stream_generation_pending`으로 하나만 처리한다.

## 19. 실패 및 예외 처리

- 새 청크 생성 실패: 현재 출구 벽을 닫고 다음 프레임에 다른 방향으로 한 번 재시도
- 두 번 실패: 동일 방향의 기본 직선 청크 생성
- 합성 격자 연결성 실패: 새 청크를 롤백하고 오류 로그 출력
- 플레이어가 제거 후보에 있음: 제거를 보류하고 새 청크 생성도 보류
- 투사체가 제거 경계를 통과 중: 투사체와 독립 궤적을 함께 제거
- 포탈 전환 중 사망: 사망 처리를 먼저 완료하고 맵 재생성 취소
- 저장 중 전환 발생: 전환 완료 후 단일 스냅샷 저장
- 오래된 저장의 알 수 없는 테마: 액트 기본 테마로 대체

## 20. 자동 테스트

### 단위 테스트

- 청크가 정확히 27×27 타일과 9개 방을 생성한다.
- 내부 9개 방이 모두 연결된다.
- 같은 입력 시드가 같은 청크를 만든다.
- 연결 벽 양쪽에 정확히 3타일 통로가 생긴다.
- 네 방향 연결이 모두 경계 안쪽 바닥으로 이어진다.
- 3번째 방 공개 전에는 생성되지 않고 3번째 공개 직후 한 번만 생성된다.
- 네 번째 청크 추가 후 활성 청크 수가 3이다.
- 제거 후 활성 타일 노드가 2,187개 이하이다.

### 통합 테스트

- 100개 청크 연속 생성 후 겹침, 단절, 활성 개수 초과가 없다.
- 생성·삭제 100회 후 A*로 입구에서 선두 청크까지 도달한다.
- 재기준화 전후 플레이어, 용병, 몬스터의 상대 위치가 같다.
- 제거 청크의 투사체, 궤적, 스킬 이펙트가 0개다.
- 홈 포탈 복귀 전후 `theme_id`는 같고 청크 시드는 다르다.
- 웨이포인트 반복 이동 시 테마는 같고 배치는 달라진다.
- 보스 및 퀘스트 보상이 재생성 후 중복 지급되지 않는다.
- v14 저장을 불러오면 캐릭터 진행은 유지되고 새 스트림이 시작된다.

### 성능 기준

- 모바일 프로필 활성 타일: 최대 2,187
- 일반 전투 활성 객체: 기존 성능 예산 이내
- 청크 추가 프레임 정지: 데스크톱 50ms 이하, 모바일 목표 120ms 이하
- 100회 스트리밍 후 지속 메모리 증가: 8MiB 이하
- Web/PWA PCK: 기존 1.5MiB 상한 유지

## 21. 구현 순서

1. `world_stream.gd` 데이터 모델과 자체 테스트
2. `LevelGen.generate_chunk()` 및 벽 통로 생성
3. 3청크 합성 격자와 연결성 테스트
4. `main.gd` 최초 9방 시작 연결
5. 시야 기반 3방 공개 트리거
6. 새 청크 렌더링과 A* 갱신
7. 네 번째 청크 생성 및 첫 청크 제거
8. 좌표 재기준화와 런타임 노드 정리
9. 홈 포탈 동일 테마 재생성
10. 웨이포인트 동일 테마 재생성
11. 보상 원장과 저장 v15 마이그레이션
12. 100청크 장기 테스트, 모바일 시각 검증, Web/PWA 배포

## 22. 승인된 해석

“다음 27개 맵이 생성됐을 때 처음 생성된 9개 맵 삭제”는 다음처럼 해석한다.

- 9방 청크 세 개까지는 누적하여 27방을 유지한다.
- 네 번째 9방 청크를 만들 때 첫 청크를 제거한다.
- 이후에도 새 청크 하나를 만들 때 오래된 청크 하나를 제거한다.
- 결과적으로 준비 과정의 짧은 전환 구간을 제외하면 활성 방은 항상 최대 27개다.

“홈 포탈, 웨이포인트 사용 시 해당 맵 테마만 동일하게 맵 재생성”은 배치와 일반 콘텐츠 위치는 새로 만들고, 액트·테마·진행·고정 보상 완료 상태만 유지하는 것으로 해석한다.
