# 프로젝트 메모리

최종 갱신: 2026-10-04 (소켓 시스템 활성화 배포)

## 맵 생성 상태

- 실제 플레이는 `WorldStream` 기반 단일 활성 청크 구조를 사용한다.
- 각 재생성 청크는 시드 기반으로 시작점과 목표점을 독립 랜덤 지정한다.
- 시작점과 목표점은 중복되지 않는다.
- 생성 모드는 직선형, 랜덤형, 장애물 랜덤형을 순환한다.
- 장애물 배치 후 시작점에서 목표점까지 타일 경로를 검사한다.
- 경로가 끊기면 장애물을 제거하며, 모든 방 중심이 이동 가능한지 검증한다.
- 저장/복원 시 청크별 시작점·목표점과 생성 모드를 유지한다.

## 검증 결과

- `MAP_VARIANTS`: PASS
- `STREAM`: PASS
- `SYSTEM`: 112 checks PASS (큐브·감정·저항 효과·참 듀얼 슬롯 회귀 포함, 실행 횟수 자동 집계)
- `SAVE`: 24 checks PASS
- Web 릴리스 검사: PASS
- 원격 PCK 해시 일치 확인: PASS

## 배포 정보

- 플레이 URL: https://jflakeee.github.io/diablo/
- 배포 표시 시각: `2026-10-04 16:04 KST`
- 소스 커밋: 소켓 시스템 활성화(본 커밋)
- 최신 배포 커밋: `dd82494` (gh-pages)
- Pages 빌드 상태: `built` (`gh api repos/jflakeee/diablo/pages/builds/latest`), 루트 HTTP 200 확인
- 원격 기본 URL의 PCK SHA-256: `7ac8ffb0f9755cb43e3d2ceffd930ecb5b278fa0ed92a7e9fe883bcfc7a9a443`
- 원격 PCK 1,267,932 bytes 및 로컬 빌드 해시 일치 확인.

## 다음 점검 항목

- 모바일·PC 브라우저에서 재생성 직후 입구와 목표 마커의 시각적 분리 확인
- 장애물 랜덤형 맵에서 시작점→목표점 실제 이동 확인
- 강제 업데이트 후 캐시가 새 PCK를 수신하는지 확인

## 2026-10-01 미착수 작업 진행 (원격 배포 완료)

- 가방 → `Crafting Cube`: 재료 수량/결과 표시, 동일 보석·각인 3개 → 다음 등급 1개.
- 몬스터 재료 드롭에 Ahn/Vey 각인 추가. 기존 보석 ID와 재료 저장소 호환 유지.
- 재료 부족·최고 등급·잘못된 ID·중복 입력 시 재료 소모 방지.
- 양 클래스 `autoquit strict_assets`: PASS. 최신 `SYSTEM` 108개, `SAVE` 22개 PASS.
- `tools/cube_ui_test.gd`: 실제 버튼/중복 입력, 부족/빈 상태, 320/640px 및 큰 글씨 레이아웃 PASS.
- Web release 검사 PASS. 큐브·감정·저주/오라 변경을 위의 배포 커밋으로 원격 반영했다.
- 맵 생성 자동 검사 PASS. Orca 브라우저 snapshot/screenshot은 `runtime_unavailable`
  (런타임이 응답 전에 연결 종료)로 실패하여 브라우저 시각/캐시/직접 이동 점검은 완료 처리하지 않았다.
- 레어 몬스터 드롭의 미감정 상태, 가방 무료 감정, 감정 전 장착/판매/경매 보호 구현.
  기존 장비는 감정 완료로 취급하며 감정 시 옵션을 다시 생성하지 않는다.
- Storm Lance에 6초 원소 저항 감소 저주, Iron Chant에 6타일·시야 제한 오라 연결.
  원래 면역인 적은 합산 저항 감소량의 1/5만 적용하고 100 미만일 때 면역 해제.
  적의 75~99 저항도 실제 피해에 반영하도록 적 피해 계산 상한을 99로 조정했다.
- 저주 막대/오라 고리, 스킬 설명 및 현재 층 저주·Iron Chant 잔여시간 저장/복원 연결.
- `tools/progression_combat_test.gd`: 실제 감정 버튼·중복 입력·장착/판매 제한,
  실제 시전·면역·거리·벽·마나·시전자 사망·저주 만료·스냅샷 검사 PASS.
- 후속: 콘텐츠 확장 범위/수량 정의, Android 실기기와 온라인 WAN/장시간 검증.

## 2026-10-01 몬스터 pack 군집 배치 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-01-monster-pack-placement-design.md`.
- `_spawn_dungeon_monsters()`를 몬스터 1마리 단위 랜덤 루프에서 pack 단위 루프로 교체.
  pack은 같은 몬스터 타입 2~4마리, anchor 주변 반경 3타일 내 바닥 타일에 모여 배치되고
  실패 시 기존 전역 랜덤 바닥칸으로 폴백한다.
- 챔피언/유니크 등급 롤을 pack당 1회로 변경(확률은 기존과 동일: 오토퀴트 첫 pack 강제
  유니크, 그 외 5%/10%). 롤 성공 시 pack 전체가 같은 등급과 동일한 `UNIQ_MODS` 모디파이어를 공유.
  `_spawn_one`/`_apply_rank`에 `forced_rank`/`forced_mod`/`pack_id` 인자 추가.
- 신규 `_pack_selftest()`: `pack_id` 메타로 몬스터를 그룹화해 군집 거리와 등급/모디파이어
  일치를 검증, `[PACK] packs=N min_size=.. max_size=.. verdict=..` 출력을 최종 `ok` 집계에 포함.
- 양 클래스 `autoquit` 실행: `[PACK] packs=5 min_size=2 max_size=3 verdict=PASS`(barb),
  `[PACK] packs=4 min_size=2 max_size=4 verdict=PASS`(sorc), 전체 `[GD][RESULT] verdict=PASS`.
- 보스 스폰과 저장 스키마는 변경하지 않음(런타임 스폰 로직만 변경).
- Web release export → gh-pages 배포 커밋 `7082c49`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256 일치 확인.

## 2026-10-01 보스룸 전용 아레나 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-01-boss-room-arena-design.md`.
- `level_gen.gd`: `generate_chunk`에 `carve_boss_arena` 인자 추가. 참이면 테마 장식·장애물
  배치가 전부 끝난 뒤 3x3 룸 그리드의 중앙 룸과 상하좌우 인접 4룸 사이 벽을 전체 폭으로
  열어 십자(+) 모양 개활지를 만들고, 내부 PILLAR/LOW_WALL도 FLOOR로 되돌려 `boss_anchor`
  (중앙 타일)를 반환한다.
- `world_stream.gd`: `_is_boss_floor()`가 `floor_id`/`act`에서 보스 여부를 그때그때 재계산
  (저장된 플래그 없음). 입구 청크(`sequence==0`)에만 아레나를 적용하며 `restore()`에서도
  동일하게 재도출해 저장/불러오기 후 동일한 아레나가 재생성됨을 보장. `compose_active_grid()`가
  전역 좌표 `boss_anchor`를 노출.
- `main.gd`: `_boss_anchor_cell`을 모든 레이아웃 적용 경로(`_apply_dungeon_layout`)에서 갱신,
  보스 스폰 시 아레나 중심을 우선 사용(무효하면 기존 `_random_floor_cell()` 폴백).
- 셀프테스트: `level_gen.selftest()`가 3개 액트 테마 + blocked_random 모드에서 아레나가
  깨끗한지, `world_stream.selftest()`가 보스 층 스냅샷/복원 후 동일 아레나·비보스 층 아레나
  부재를 검증. 오토퀴트 `[BOSS_ROOM] anchor=(13, 13) boss_cell=(13, 13) used_arena=true
  verdict=PASS`를 양 클래스에서 확인, 전체 `[GD][RESULT] verdict=PASS`.
- Web release export → gh-pages 배포 커밋 `481a74d`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`f7754bc4...`) 일치 확인.

## 2026-10-01 프리셋 룸 다양화 + act3 연결성 복구 버그 수정 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-01-preset-room-variety-design.md`.
- `level_gen.gd _apply_room_preset`: 룸마다 무장식(50%)/안쪽 5x5 모서리 4기둥(25%)/안쪽
  5x5 변 중앙 4기둥(25%) 중 하나를 결정론적으로 롤. 테두리 1칸과 중심 타일의 상하좌우
  이웃은 항상 비워 둬 문 위치·연결 그래프와 무관하게 우회로를 보장.
- 부수 발견: 프리셋이 RNG 소비 시점을 바꾸면서 act3(pillar_plains)의 전역 기둥 산포가
  입구-출구 경로를 끊을 수 있는 **기존 잠재 버그**(`MODE_BLOCKED_RANDOM`과 달리 연결성
  복구 루프가 없었음)가 테스트에서 드러남 — `[MAP_VARIANTS] selftest verdict=FAIL`로 검출.
  동일한 복구 패턴을 act3 산포에도 적용해 수정(act3를 쓰는 모든 생성 경로에 적용되는
  일반적인 안전성 개선, 프리셋 전용 수정 아님).
- 셀프테스트: 시드 5001~5006(act1) 연결성+프리셋 등장 확인, 시드 6001~6006(act3) 연결성
  회귀 감시. 양 클래스 `autoquit`에서 `[MAP_VARIANTS] selftest verdict=PASS` 포함 전체
  `[GD][RESULT] verdict=PASS` 재확인(최초 수정 전 FAIL 재현 후 수정 확인 과정 거침).
- Web release export → gh-pages 배포 커밋 `f01fefb`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`3813252a...`) 일치 확인.

## 2026-10-01 몬스터 AI 관심영역 컬링 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-01-monster-ai-interest-area-culling-design.md`.
- 목격된 일반 몬스터(보스 제외)가 플레이어로부터 `AI_INTEREST_RADIUS`(6타일) 밖이면 그
  프레임의 AI(`_melee_ai`/`_ranged_ai`, 내부 A* 경로탐색 포함)를 건너뛴다. 플레이어 자신의
  이동은 몬스터 AI와 무관해 접근하면 정상적으로 재가동된다.
- 처음 14타일로 시도했으나 오토퀴트 실측상 플레이어의 최근접 교전 AI가 항상 목격된
  몬스터를 빠르게 처리해 관측 최대 거리가 7.8타일을 넘지 않아 한 번도 발동하지 않음을
  확인 → 목격 반경(8) 바로 아래인 6으로 조정.
- 계측: `_astar_calls`(실제 A* 호출), `_ai_culled_far`(컬링 발동 횟수), `_witness_max_dist_sq`
  (진단용). `[AI_CULL] astar_calls=.. culled_far=.. witness_max_dist=.. verdict=..` 출력,
  컬링이 실제로 발동했는지(`culled_far>0`)를 최종 `ok` 집계에 포함.
- 검증: barb `astar_calls=218 culled_far=61 witness_max_dist=7.4 verdict=PASS`, sorc
  `astar_calls=572 culled_far=321 witness_max_dist=11.4 verdict=PASS`, 양 클래스
  `[GD][RESULT] verdict=PASS`, `[PERF]` 50초 예산 유지.
- Web release export → gh-pages 배포 커밋 `94228cb`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`0536ec3f...`) 일치 확인.

## 2026-10-01 인벤토리 그리드 Bag UI (원격 배포 완료 — 미착수 백로그 전체 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-01-inventory-grid-ui-design.md`.
- 가방(Bag) 뷰를 "아이템마다 전체 액션 행 세로 나열"에서 "64x64+ 탭 타일 격자 + 선택된
  1개의 상세 패널"로 교체(`main.gd _rebuild_inv()`, `_selected_inventory_item` 신규 상태).
  장착/감정/Keep/Merc/Stash/Sell/Protected 기존 핸들러는 전부 그대로 재사용 — 렌더링만
  변경, 로직 변경 없음. 인벤토리가 비어있지 않으면 항상 하나가 선택되어(기본 0번) 1개짜리
  인벤토리도 탭 없이 바로 상세 패널이 보인다.
- **명시적 비범위**: D2식 W×H 칸 드래그앤드롭 격자는 포함하지 않음 — 이 프로젝트 정의상
  UI는 D2와 동일할 필요가 없고(각색 대상), 드래그 제스처·칸수 데이터·격자 충돌은 한 사이클로
  끝낼 수 없는 다단계 작업이라 미완성 위험이 큼. 탭-격자로 백로그 항목을 완결된 형태로 충족.
- cube/collection/item_log 뷰는 전혀 건드리지 않음.
- 검증: `tools/progression_combat_test.gd`(Identify (Free) 버튼 재귀 탐색 계약) PASS,
  `tools/cube_ui_test.gd`(cube 뷰 무관 확인) PASS, `auto_equip_sell_test` cmdline
  (`_inv_vbox` 직계 자식 "RECENT ITEM LOG" Label 계약) `history_view=true verdict=PASS`,
  양 클래스 `autoquit` `[GD][RESULT] verdict=PASS`.
- Web release export → gh-pages 배포 커밋 `2fbdee2`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`5287701e...`) 일치 확인.
- 2026-10-01 "미착수 작업 확인" 세션에서 식별한 5개 항목(pack 배치·보스룸·프리셋 룸·
  A* 컬링·인벤토리 그리드) 전부 완료.

## 2026-10-02 보물방 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-02-treasure-room-design.md`. 보스룸 설계 당시
  "별도 미착수 항목"으로 분리해 둔 특수룸(보물방)을 이번에 구현.
- `level_gen.gd`: `carve_treasure_room` 인자 추가. 보스 아레나 카빙 뒤, 입구/출구가 아닌
  임의 슬롯 하나를 `_open_room_interior`로 비워 `treasure_anchor` 반환.
- `world_stream.gd`: 청크마다(입구 청크 한정 아님, 스트리밍 후속 청크 포함) 그 청크 자신의
  시드로 독립 판정(`_rolls_treasure`, 25%), 보스 층은 전면 배제. `compose_active_grid()`가
  "현재(=유일한) 활성 청크" 기준 `treasure_anchor`를 전역 좌표로 노출(보스 아레나는 항상
  "첫 청크" 기준이었던 것과 차이).
- `main.gd`: `_treasure_anchor_cell`/`_treasure_looted_cell` 상태, `_spawn_treasure_loot()`
  (레어 3개 + 골드 150+dlevel*40)를 몬스터가 새로 스폰되는 모든 지점(최초 진입·다음 층·
  웨이포인트/포탈 이동·저장 불러오기·스트리밍 신규 청크)에 연결. `_player`가 아직 없는
  매우 초기 호출 경로를 피하려 `_generate_dungeon()` 자체가 아니라 그 호출부들에 개별 연결.
- 검증: `level_gen.selftest()`(5개 시드/액트/모드에서 입구·출구 비겹침·내부 청결·연결성)와
  `world_stream.selftest()`(비보스 100청크 중 최소 1회 등장, 보스 층 전무) 둘 다 기존
  `[MAP_VARIANTS]`/`[SYSTEM]` 집계에 자동 편입. 오토퀴트는 게임플레이 경로 의존적이라
  최종 verdict에 묶지 않고 진단 출력만: barb/sorc 둘 다 `[TREASURE] rooms_spawned=2`,
  `[GD][RESULT] verdict=PASS`.
- README `정식화` 섹션이 수차례 세션 동안 완료 항목을 제거하지 않아 낡아 있던 것을 정리.
  다음에 미착수 작업을 찾을 때는 이 메모리 파일과 코드를 직접 대조할 것(README 정식화는
  더 이상 신뢰할 소스가 아니었음을 교훈으로 남김).
- Web release export → gh-pages 배포 커밋 `bc86c9e`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`2c70669e...`) 일치 확인.

## 2026-10-02 용병 종류 다양화 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-02-mercenary-type-variety-design.md`. 용병이
  "Ember Scout"(원거리 화염) 1종으로 고정되어 있던 것을 상인 패널에서 순환 전환 가능한
  3종(Ember Scout/Iron Guard 근접/Frost Acolyte 냉기+슬로우)으로 확장.
- `mercenary.gd`: `TYPES`/`TYPE_ORDER` 스탯 템플릿, `normalize_type`/`next_type`, `stats()`에
  `merc_type` 인자, `selftest()`(기본값 폴백·순환 순서·가드 탱크 특성·냉기 슬로우 플래그 검증).
- `main.gd`: `_merc_type` 상태 + 상인 패널 "Mercenary: <종류> (Cycle)" 버튼(`_cycle_merc_type`,
  레벨/장비/킬 수/부활 타이머 유지하고 스탯·아트만 재적용), `_merc_ai`가 종류 템플릿의
  사거리/쿨다운을 읽어 근접(`_merc_melee`)/원거리(`_merc_fire`, 원소 부가피해) 분기.
- `save_store.gd`: 스키마 v15→v16, `merc_type` 기본값 "scout" 마이그레이션(checks 22→23).
- 검증: `[MERC_TYPE] selftest verdict=PASS` + `[SAVE] checks=23`가 오토퀴트 최종 `ok` 집계에
  편입됨(barb/sorc 둘 다 PASS). 종류 전환 자체는 상인 패널 UI 경로라 인벤토리 그리드 UI 때와
  동일하게 오토퀴트 최종 verdict에는 묶지 않음.
- Web release export → gh-pages 배포 커밋 `48985e7`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`8cc24f8d...`) 일치 확인.

## 2026-10-02 참(Charm) 아이템 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-02-charm-items-design.md`. advisor 자문으로
  "참은 D2식 가방 패시브로 만들지 말 것"을 확정 — 이 프로젝트 Bag은 탭 그리드라 공간 비용이
  없어 가방 패시브는 공짜로 쌓이는 스탯이 된다. 반지(`ring_left`/`ring_right`)와 동일하게
  전용 슬롯 2개(`charm_left`/`charm_right`)로 구현.
- `item.gd`: `CHARM_BASES`(2종) 추가, `indestructible`/`identify()` 허용 슬롯에 "charm"
  추가, `roll_drop()` 베이스 버킷 재분배(무기38%/방어34%/장신구14%/참14%, 기존 42/42/16에서
  참 몫 분리).
- `main.gd`: `EQUIPMENT_SLOTS`/`_equipped`에 참 슬롯 추가, `_equipment_slot_for_item`을
  반지/참이 공유하는 `_dual_slot_for_item` 헬퍼로 일반화(빈 슬롯 우선, 둘 다 차면 전투력
  비교). `_recompute_player()`/`_loadout_combat_power`가 이미 `EQUIPMENT_SLOTS`를 순회하는
  구조라 참 접사가 스탯·자동장착 비교에 추가 코드 없이 자동 편입됨. 도박/보물방 드롭
  테이블에도 참 추가.
- `save_store.gd`: 스키마 v16→v17, 구 세이브는 빈 참 슬롯으로 마이그레이션(checks 23→24).
- `Coverage.validate()`의 베이스/슬롯 집계는 `data.gd`의 별도 정적 샘플만 보는 구조라
  `item.gd` 런타임 테이블 변경과 무관함을 확인(변경 불필요, advisor가 짚은 위험 지점이었음).
- 검증: `[SYSTEM] checks=112`(참 생성·감정·내구도 면제·듀얼 슬롯 접사 합산·용병 비장착
  검증 추가), `[SAVE] checks=24` 둘 다 barb/sorc 오토퀴트 최종 `ok`에 PASS로 편입.
- Web release export → gh-pages 배포 커밋 `48c9043`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`08756363...`) 일치 확인.

## 2026-10-02 스탯/스킬 리스펙 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-02-respec-design.md`. advisor 자문으로 확정한
  백로그 2건(용병 종류 다양화·참 아이템) 완료 후 다시 자문해 확정한 3번째 항목.
- 핵심 설계 결정: 스킬을 전부 레벨 0으로 되돌리지 않는다. `_spend_skill`은
  `skill_level(id) <= 0`이면 버튼이 막혀, 레벨 0인 스킬은 스킬북을 다시 주워야만 재투자
  가능하다(`_make_skill_book`/`_next_skill_book_drop`). 전부 0으로 리셋하면 환불받은
  포인트를 스킬북이 다시 나올 때까지 못 쓰는 회귀가 생긴다. 그래서 "해금된(레벨>=1) 스킬은
  레벨 1로, 미해금(레벨 0) 스킬은 그대로"로 리셋하고 1을 넘는 투자분만 환불한다.
- `main.gd`: `_class_base_stats()`(클래스 기준 스탯, `_start_game`이 재사용하도록 리팩터),
  `_respec_cost()`(`300 + 레벨*60`), `_respec()`(실제 분배 기록에서 환불량 계산 — 레벨
  공식 재추정 금지, 퀘스트 보상 스킬포인트까지 정확히 보존), 상인 패널 버튼.
- 전용 검증 모드 `_run_respec_test()` + cmdline `respec_test`(경제/자동장착 테스트와 동일한
  독립 모드 패턴). 첫 구현 때 `_act_reward_selftest()`가 이미 `_auto_spend_points()`로 다른
  스킬에도 포인트를 써둔 상태였다는 걸 놓쳐, 테스트가 "스타터 스킬 하나만 환불된다" 가정으로
  실패했음 — 전체 스킬 슬롯 합산으로 수정 후 PASS. (실제 `_respec()` 로직은 처음부터 맞았고
  테스트의 가정이 틀렸던 사례.)
- 검증: barb/sorc 둘 다 `respec_test` 전용 모드에서 `[RESPEC] ... verdict=PASS`, 표준
  50초 오토퀴트도 `[SYSTEM] checks=112`/`[SAVE] checks=24` 그대로 PASS(세이브 스키마
  변경 없음 확인).
- Web release export → gh-pages 배포 커밋 `6cdef64`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`2ad39584...`) 일치 확인.

## 2026-10-02 호라드릭 큐브 리롤 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-02-cube-reroll-design.md`. advisor 자문으로
  확정한 백로그 3건(용병 종류 다양화·참 아이템·리스펙) 완료 후 자문한 4번째이자 이번
  라운드의 마지막 항목.
- `item.gd`: `generate()`의 품질별 접사 롤 로직을 `_apply_quality_roll()`로 추출(재사용),
  `reroll()` 추가(같은 품질·아이템레벨로 접사 재굴림, 미감정/normal/set/unique 제외).
- `craft.gd`: `REROLL_CATALYST`("topaz", 소켓 효과가 0이라 다른 쓸모가 없던 재료에 새
  용도 부여)/`REROLL_COST`(3), `can_reroll()`/`reroll()`.
- `main.gd`: `_rebuild_cube()`에 REROLL 섹션(가방의 감정된 매직/레어 아이템마다 버튼),
  `_reroll_inventory_item()`.
- 발견 및 수정: `_craft_selftest()`가 지금까지 `[P4][RESULT]`를 출력만 하고 최종
  `[GD][RESULT] ok` 집계에는 전혀 묶이지 않고 있었다(pack/waypoint/boss room은 이미
  묶여 있었는데 craft만 빠짐 — MAP_VARIANTS 교훈과 같은 종류의 숨은 FAIL 위험). 리롤
  체크를 추가하는 김에 `_craft_selftest_ok` 멤버 변수를 신설해 최종 ok 체인에 합류시켰다.
- `tools/cube_ui_test.gd` 확장: 처음엔 리롤 버튼을 `HBoxContainer` 행 안에 넣어 UI 테스트의
  "panel 직계 자식만 검사" 가정과 충돌해 FAIL이 났다 — 기존 "Combine" 버튼처럼 라벨/버튼을
  평평하게(직계 자식으로) 배치하도록 수정 후 PASS.
- 검증: `[P4] reroll: ... : true` + `[P4][RESULT] craft_selftest verdict=PASS`가 barb/sorc
  둘 다 최종 `ok`에 영향(이제 craft FAIL 시 전체 verdict도 FAIL), `[CUBE_UI] ... reroll=true
  verdict=PASS`.
- Web release export → gh-pages 배포 커밋 `d647c3f`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`525a6e6d...`) 일치 확인.

## 2026-10-04 Hell 원소 면역 활성화 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-04-hell-elemental-immunity-design.md`.
  advisor 자문으로 "이미 만들어졌지만 실전에서 발동 안 하는 시스템"을 찾아 활성화한 사례
  — AI_CULL 반경, craft_selftest 미집계와 같은 종류. 저주/오라 면역돌파(`reduced_resistance`,
  Storm Lance/Iron Chant)는 완전히 구현·단위테스트까지 돼 있었지만, 실제 면역(저항≥100)이
  나는 원소가 독(poison) 하나뿐이라 두 클래스 모두 한 번도 발동시킬 수 없는 죽은 코드였다.
- `combat.gd diff_monster_resist_bonus`: Hell 값만 50→70으로 조정(Normal/NM은 그대로).
  기존 몬스터 데이터(`data/monsters.json`) 기준 Hell에서 fire(ash_caller)/cold(bone_guard,
  bone_marksman)/light(horned_marauder) 전부 100 이상으로 면역 — 기존 50은 fire/cold를
  정확히 100(여유 없음)만 만들고 light는 90으로 못 미쳤던 것을 70으로 여유 있게 만듦.
  Brood Matron의 불 약점(-50)이 Hell에서만 -50+70=20(약한 저항)으로 사라지는 부작용은
  D2 원작도 고난이도일수록 보스 고유 약점이 희석되는 경향이 있어 의도적으로 수용.
- `main.gd`: `_immune_selftest()` 추가 — `Data.monsters()`를 3개 난이도로 정적 스캔해
  Hell=fire/cold/light 전부 면역, Normal/NM=전부 비면역을 검증, 최종 `ok` 집계에 편입.
- `reduced_resistance()`/`apply_resistance()`의 경계값 자체는 이미 `system_tests.gd`에
  단위테스트돼 있어 재작성하지 않음 — 이번 작업은 숫자 하나만 조정해 기존에 완성된
  파이프라인을 실전에서 처음으로 타게 만든 것.
- 검증: barb/sorc 표준(Normal) 오토퀴트 PASS(회귀 없음) + `autoquit barb hell`/
  `autoquit sorc hell` 스모크 테스트로 실제 Hell 던전에서 크래시 없이 진행 확인,
  `[IMMUNE] ... verdict=PASS` 전부.
- Web release export → gh-pages 배포 커밋 `81ceb88`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`6814ffe8...`) 일치 확인.

## 2026-10-04 소켓 시스템 활성화 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-04-socket-activation-design.md`. Hell 원소
  면역과 같은 라운드에서 advisor가 지목한 두 번째 "이미 만들어졌지만 실전에서 발동 안
  하는 시스템". `make_socketed()`/`socket_insert()` 호출부가 `_craft_selftest()` 말고는
  전혀 없었다 — 소켓/보석/룬/룬워드 전체가 실제 플레이에서 한 번도 닿을 수 없었다.
- `craft.gd`: `SOCKET_CATALYST`("skull", 토파즈와 같은 이유로 소켓 효과 0이라 쓸모없던
  재료를 돌림)/`SOCKET_COST`(3)/`SOCKET_COUNT`(2), `can_add_sockets()`/`add_sockets()`
  (제자리 변형 — `make_socketed()`는 새 아이템을 만들어 가방 아이템엔 못 씀).
- `main.gd`: 스컬을 몬스터 드롭 재료 풀에 추가, `_rebuild_cube()`에 "ADD SOCKETS"/
  "INSERT INTO SOCKET" 두 섹션(리롤 때처럼 버튼을 평평하게 직계 자식으로 배치),
  `_add_sockets_to_item()`/`_insert_material_into_item()`, `_craft_selftest()` 6번째
  체크(스컬 소비→소켓 2개→Vey+Ahn 삽입→Tempered Edge 룬워드 매칭까지 한 번에 확인).
- `tools/cube_ui_test.gd` 확장: "Add 2 Sockets"/"Insert ..." 버튼 탐지·클릭·재료소비
  검증 추가.
- 비범위로 명시: 소켓 개수 가변화, 보석 품질별 효과 차등화(기존 `GEM_STATS`가 품질
  무관 고정값인 한계를 그대로 둠), Gloom Crown 룬워드(헬름 슬롯 자체가 없어 도달
  불가능 — 건드리지 않음).
- 검증: `[P4] socket: ... : true` + `[P4][RESULT] craft_selftest verdict=PASS`가
  barb/sorc 둘 다 최종 ok에 영향(지난 라운드에 이미 `_craft_selftest_ok`로 편입해둠),
  `[CUBE_UI] ... socket=true verdict=PASS`.
- Web release export → gh-pages 배포 커밋 `dd82494`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`7ac8ffb0...`) 일치 확인.
