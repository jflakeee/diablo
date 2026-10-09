# 프로젝트 메모리

최종 갱신: 2026-10-09 (아이템 스크랩북 + 유니크/세트 수치 범위화)

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
- `SYSTEM`: 120 checks PASS (큐브·감정·저항 효과·참 듀얼 슬롯·난이도 보상·유니크 드롭-once·제작 아이템·유니크/세트 범위 롤 회귀 포함, 실행 횟수 자동 집계)
- `SCRAPBOOK`: selftest PASS(티켓 발급/비용 공식/복원/저장-복원 라운드트립), 최종 ok 집계에 배선됨
- `SAVE`: 24 checks PASS
- `PROGRESSION_COMBAT`(통합 회귀): PASS
- Web 릴리스 검사: PASS
- 원격 PCK 해시 일치 확인: PASS

## 배포 정보

- 플레이 URL: https://jflakeee.github.io/diablo/
- 소스 커밋: 아이템 스크랩북(소모형 복원 티켓) + 유니크/세트 접사 범위 롤 도입
  (장비 습득 시 기존 자동감정/자동장착 흐름은 불변, 티켓은 골드로 새로 굴린
  사본을 수동 장착 전제로 추가 제공)
- 최신 배포 커밋: `bf55731` (gh-pages)
- Pages 빌드 상태: `built`, 루트 HTTP 200 확인
- 원격 PCK SHA-256: `d219a6bdd87ed0a70a9b6574fe25cab23cfb17bc07556dd043582531ad5b8efe`, 로컬 빌드 해시 일치 확인(curl로 직접 fetch)
- 시각 검증: playwright로 루트 접속 → 클래스 선택 화면 정상 렌더링,
  `DEPLOYED 2026-10-09 11:47 KST` 표시 확인.

## 설계 원문(`prompt_diablo.md`) 대비 구현 현황 (2026-10-04 작성)

사용자가 저장소 루트에 남긴 `prompt_diablo.md`(미추적 파일)를 "설계된 내용"의 원본으로
확인하고 전체 22개 항목을 구현 상태별로 분류했다. 이 표가 비워질 때까지 "다음 미착수
작업"을 계속 이어간다.

| # | 항목 | 상태 | 근거 |
|---|------|------|------|
| 1 | 아이템 자동 습득 | 구현됨 | `Automation.accepts()`, `_pickup()`에서 호출 |
| 2 | 자동 습득 등급 설정 | 구현됨 | `pickup_min` + "Cycle Auto Pickup" UI |
| 3 | 동일 아이템 무한 겹침 | 미착수 | 장비(무기/방어구/반지/부적)는 각 1슬롯씩 `_inventory.append()`로만 쌓임 — 동일 판정(같은 접두/접미사) 겹침 로직 없음. 단, 모든 장비가 랜덤 롤 옵션을 가지는 구조라 "동일 아이템" 자체가 드물어 실제로 의미 있는 기능인지 재검토 필요 |
| 4 | (구분선) | - | - |
| 5 | 포션 자동 습득 | 구현됨 | `accepts()` slot="potion" 무조건 true |
| 6 | 상위 포션으로 자동 교체 | 구현됨 | `Automation.potion_upgrade()` |
| 7 | (구분선) | - | - |
| 8 | 재료아이템 자동 습득 | 구현됨 | `accepts()` slot="material" 무조건 true |
| 9 | 보석류 무한 겹침 | 구현됨 | `_automation.materials[id]` 정수 카운트, 품질 접미사별 분리 키로 캡 없음 |
| 10 | (구분선) | - | - |
| 11 | 장비 자동 장착 | 구현됨 | `_auto_equip()`, 파워 비교 기반 |
| 12 | 자동 장착 등급 설정 | **2026-10-04 활성화** | 기존엔 `equip_min` UI 토글이 `_auto_equip()`에서 전혀 읽히지 않는 죽은 토글이었음 — 교체 시에만 등급 게이트 적용하도록 수정(빈 슬롯은 등급 무관 유지) |
| 13 | (구분선) | - | - |
| 14 | 장비 해제한 아이템 경매장에 자동 등록 | 구현됨 | `_equip_from_inventory()`/`_auto_equip()`에서 `Automation.list_auction()` 호출 |
| 15 | 경매장 자동 등록 등급 설정 | 구현됨 | `auction_min` + "Cycle Auto Auction" UI |
| 16 | (구분선) | - | - |
| 17 | 경매장 등록 기간 초과시 자동 재료 분해 | 구현됨 | `Automation.expire_auctions()` → `salvage` 누적, 매 틱 `_process`에서 호출 |
| 18 | 분해 금지 아이템 설정 | 구현됨 | `salvage_protected` 플래그, 컬렉션 보관 시 자동 설정 |
| 19 | (구분선) | - | - |
| 20 | 디자인 리소스 직접 생성 | 구현됨(진행형) | `art/art_recipes.json` + `tools/asset_compiler.gd` 파이프라인으로 전체 아이콘/애니메이션 자체 생성, 외부 에셋 없음 |
| 21 | UI를 디아블로 이모탈 모바일 버전으로 최적화 | 부분 구현(2026-10-04 갱신) | `mobile_ui.gd layout()`에 이모탈식 스킬 버튼 부채꼴 좌표 계산을 추가했지만, **스킬 버튼 자체가 2026-09-29 사용자 결정(`aaac80b`)으로 게임에서 완전히 제거되어 있어 이 좌표를 소비할 코드가 없다** — 현재 조작 모델은 "자동전투(기본 공격) + 수동 포션/저장/전체화면"뿐, 수동 스킬 발동 UI는 존재하지 않음. 이모탈 대조 작업을 더 진행하려면 먼저 "수동 스킬 조작을 다시 넣을지"부터 사용자와 합의해야 함(단순 UI 배치 문제가 아님) |
| 22 | 모든 시스템/콘텐츠를 D2와 동일하게 구현 | 진행형(지속 목표) | 이번 세션에서 소켓/룬워드/보석 품질/원소 면역/난이도 보상 등 다수 "죽은 시스템"을 활성화하며 지속 수렴 중 — 완료 기준 없음, 매 라운드 격차 탐색으로 계속 좁혀감 |

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

## 2026-10-04 난이도별 보상 스케일링 + 자산 파이프라인 결함 수정 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-04-difficulty-reward-scaling-design.md`.
  advisor 자문 전 검증 부채 점검에서 "통합 회귀 검사"(`tools/progression_combat_test.gd`)가
  이번 세션 6개 기능 라운드 내내 한 번도 실행되지 않았던 것을 발견 → 재실행 후 PASS
  확인, 앞으로 매 기능 사이클에 포함하기로 메모리(`deployment-workflow`)에 기록.
- 몬스터 레벨(`m.level`)은 난이도와 무관하게 고정값(명중률 alvl/dlvl 균형을 건드리지
  않기 위해 의도적으로 유지)인데, 드롭 아이템레벨과 킬 경험치가 거기 묶여 있어 Hell이
  "위험만 늘고 보상은 그대로"였다. `combat.gd`에 `diff_reward_ilvl_bonus`(0/4/8)와
  `diff_xp_mult`(1.0/1.25/1.5) 순수 함수 추가, `main.gd _kill_xp()` 헬퍼로 경험치
  지급 5곳(플레이어 근접/투사체/스톰랜스, 용병 원거리/근접)을 전부 교체, 드롭 롤의
  `mlvl`에 보너스 가산.
- **부수 발견(실제 버그)**: 검증 중 sorc 오토퀴트가 `[ASSET] ... "ok": false, "missing":
  ["icon/skull","static/skull"]`로 최종 verdict=FAIL — 지난 라운드(소켓 시스템 활성화)에서
  드롭 재료 풀에 추가한 "skull"이 사전 컴파일 아틀라스(28개 고정 항목)에 없어서 생긴
  결함이었다. `grep -i fail`로는 소문자 `"ok": false`를 못 잡는다는 것도 이때 실측으로
  확인(앞으로 전체 로그를 직접 훑거나 `[GD][RESULT] verdict=` 최종 줄을 반드시 확인).
  `art/art_recipes.json`에 skull 아이콘 레시피 추가 → `tools/asset_compiler.tscn`을
  `-- autoquit verify publish`로 재실행해 아틀라스 재생성(28→29 항목) → 하드코딩된
  항목 수 단언(`asset_catalog.gd`/`tools/asset_compiler.gd`)도 28→29로 함께 수정.
- 검증: `system_tests.gd`에 두 순수 함수 경계값 테스트 추가(checks 112→114, 최종 ok에
  자동 편입). barb/sorc 표준 오토퀴트 + `autoquit barb/sorc hell` + 통합 회귀 검사
  전부 PASS, `[ASSET] ... "ok": true` 확인.
- Web release export → gh-pages 배포 커밋 `8cf0984`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`6ee54f81...`) 일치 확인.

## 2026-10-04 보석 품질 소켓 효과 차등화 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-04-gem-quality-socket-effects-design.md`.
  소켓 시스템 활성화 때 "별도 확장"으로 미뤄둔 항목 — Perfect든 Normal이든 소켓에
  끼우면 완전히 동일한 효과였다(`_insert_material_into_item`이 품질 접미사를 잘라내고,
  `GEM_STATS`가 품질 무관 고정값이었음 — 전부 Perfect 등급 값). 5단계 승급 체인
  (`transmute`)이 소켓 게임플레이에 아무 가치도 안 만들던 또 다른 죽은 트리거였다.
- `craft.gd`: `GEM_QUALITY_SCALE`(chipped .4/flawed .55/normal .7/flawless .85/perfect
  1.0, GEM_STATS는 perfect 기준값), `gem_stat()`을 `name:quality` 파싱+배율 적용으로
  재작성. 베어 id(접미사 없음)는 normal(.7) 취급 — 소급 적용되지만 `effective_affixes()`가
  매번 실시간 재계산이라 마이그레이션 불필요.
- `main.gd`: `_insert_material_into_item()`이 보석은 품질 접미사를 보존한 전체 id를
  그대로 전달(룬은 `rune_` 접두사만 제거하는 기존 방식 유지). `_craft_selftest()`
  7번째 체크 추가 — 그리고 **기존 1번째 체크(`[P4] gem`)가 베어 "ruby"로 38 life를
  기대하던 게 이제 27이 되어 FAIL** — 그 테스트의 주석이 원래부터 "Perfect Ruby"였으므로
  버그가 아니라 테스트가 새 설계(베어=normal)를 반영하도록 `":perfect"`를 명시하는
  수정이 맞았다.
- `tools/cube_ui_test.gd`: "Insert Perfect Ruby" 버튼 클릭 후 `socketed[0].id ==
  "ruby:perfect"`로 품질이 보존되는지 확인.
- 검증: barb/sorc 표준 오토퀴트(`[P4][RESULT] craft_selftest verdict=PASS`, checks
  변화 없음 — 이번엔 print 체크만 추가) + `autoquit barb/sorc hell` +
  `tools/progression_combat_test.gd` 전부 PASS.
- Web release export → gh-pages 배포 커밋 `0c35a2e`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`cbab9664...`) 일치 확인.

## 2026-10-04 자동 장착 등급 게이트 활성화 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-04-auto-equip-grade-gate-design.md`.
  저장소 루트의 설계 원문 `prompt_diablo.md`를 이번에 처음 읽고 전체 22개 항목 대비
  구현 현황 표를 작성했다(위 "설계 원문 대비 구현 현황" 참고) — 11/12번 "장비 자동 장착 /
  자동 장착 등급 설정" 중 12번이 또 다른 죽은 토글이었다: UI의 "Cycle Auto Equip" 버튼이
  바꾸는 `_automation.equip_min`을 `_auto_equip()`이 전혀 읽지 않고 순수 파워 비교만으로
  교체 여부를 정했다.
- `main.gd _auto_equip()`: 이미 장비가 있는 슬롯을 **교체**할 때만
  `rank(it.quality) >= rank(equip_min)`를 추가로 요구하도록 1줄 게이트 추가. 빈 슬롯
  채우기는 등급 무관하게 즉시 장착되는 기존 동작을 그대로 유지(초반 맨손 상태 방지는
  비범위로 명시).
- `_run_auto_equip_sell_test()`(cmdline `auto_equip_sell_test`): 등급 미달 고파워
  아이템이 장착된 rare를 교체하지 않음(`grade_gate_blocked`, `salvage_protected`로
  자동판매 분기까지 결정론적으로 차단) → `equip_min`을 낮춘 뒤 동일 계열 아이템이 정상
  교체됨(`grade_gate_released`) 두 체크 추가, 최종 `ok`에 합류.
- **디버깅 메모**: 전용 테스트 모드를 cmdline 토큰만으로(`-- auto_equip_sell_test`)
  단독 실행하면 `_ready()`가 `barb`/`sorc`/`autoquit` 토큰 부재로 `_show_class_select()`
  메뉴에서 headless 상태로 영원히 대기한다(로그엔 엔진 헤더 한 줄만 출력) — 코드 문제가
  아니라 invocation 문제였음을 `autoquit barb`(전체 PASS)와의 교차 비교로 확인.
  `-- barb auto_equip_sell_test` 형태로 클래스 토큰을 반드시 함께 줘야 한다(세션 메모리
  `deployment-workflow`에 영구 기록).
- 검증: barb(`auto_equip_sell_test` 전용 모드, `edited_barb.log` 표준 오토퀴트 둘 다),
  sorc 표준 오토퀴트, `tools/progression_combat_test.gd`(114+24 checks) 모두 PASS,
  전체 로그 `verdict=FAIL`/`"ok": false` 스윕 0건.
- Web release export → gh-pages 배포 커밋 `c818776`, Pages 빌드 `built`(commit 일치
  확인), 루트 HTTP 200, 로컬/원격 PCK SHA-256(`9d857f2f...`) 일치 확인. 추가로 이번
  라운드부터 **배포 후 시각 검증**을 도입 — playwright로 실제 배포 URL 접속, 클래스 선택
  화면 렌더링과 콘솔 에러 0건을 스크린샷+로그로 확인(서비스워커 캐시 우회를 위해
  `?v=<commit>` 쿼리 사용).

## 2026-10-04 모바일 스킬 버튼 부채꼴 배치 로직 + "스킬 버튼 자체가 죽은 배선" 발견

- 설계 문서: `docs/superpowers/specs/2026-10-04-immortal-style-skill-arc-design.md`.
  `prompt_diablo.md` 21번 "UI를 디아블로 이모탈 모바일 버전으로 최적화"는 범위가 넓어
  한 사이클로 끝낼 수 없음(인벤토리 그리드 UI 라운드의 D2식 격자 비범위 처리와 동일
  판단) — 가장 식별력 있는 단일 시각 요소인 "스킬 버튼 사각 그리드 → 부채꼴" 배치
  하나만 이번 라운드 범위로 잡았다.
- `mobile_ui.gd layout()`: 모바일 프로필에서 `skill_primary`는 기존 모서리 위치
  그대로 유지(엄지 안착점), 나머지 3개 버튼만 같은 피벗 중심 180°(왼쪽)~270°(위쪽)
  호에 부채꼴 배치(`radius = skill_size.x * 1.5`). 데스크톱은 기존 가로줄 유지.
- **설계 반복 기록**: 처음엔 4개 버튼 전부를 호에 균등 배치하는 안을 구현했으나
  기존 `validate()`(AABB 경계 박스 겹침 검사, 새 테스트 추가 없이 그대로 재사용)가
  중간 두 버튼의 겹침을 즉시 잡아냄 — 정사각 버튼은 45° 대각 간격이 축 방향 간격보다
  체감상 좁아(cos45°배) 비겹침에 필요한 반지름이 2.7배 이상으로 커지는데, 그 반지름이
  최소 가로모드 뷰포트(640x360, 가용 높이 328px)에서 화면 밖으로 넘어가 버려 해가
  없는 제약이었다. primary 고정 + 3버튼 호의 2단 구조로 바꾸자 모든 쌍이 여유를 두고
  통과(대각 쌍 최소 여유 6.8px).
- **더 큰 발견(배포 후 시각 검증 중)**: Android UA로 실제 배포 URL을 열어 HUD를
  스크린샷해보니 스킬 버튼이 하나도 안 보였다. 추적 결과 `layout()`이 계산하는
  4개 좌표를 실제로 읽어 버튼을 만드는 코드가 `main.gd _ready()`에 없었다 —
  `_add_skill_button()`은 정의만 있고 호출부가 없는 죽은 함수. `git log
  -S"_add_skill_button(ui"`로 추적하니 이건 버그가 아니라 **2026-09-29 사용자 직접
  커밋 `aaac80b "Remove skill controls and pause on modal UI"`**의 의도적 제거였다
  — 같은 커밋이 숫자키 스킬 단축키, WASD, 클래스별 자동전투 스킬 로직(소서리스
  주문순환/카이팅, 바바리안 Iron Chant 자동시전)까지 함께 제거하고 모달 열림 시
  게임을 멈추는 일시정지를 추가 — "수동 스킬 조작 제거 + 기본 공격 자동전투 +
  모달 일시정지"로 가는 일관된 설계 변경이었다.
- **사용자 확인 결과**: 9/29 결정 유지, 스킬 버튼 재연결 안 함. 임시로
  `_add_skill_button()` 호출부를 `_ready()`에 추가해 전체 체인
  (barb/sorc 표준 오토퀴트 + `-- barb skill_visual_test`, `[SKILL_VISUAL]
  slots=4 verdict=PASS`)으로 배선 자체가 정상 동작함은 확인했으나, 사용자 결정에
  따라 그 호출부는 다시 제거했다 — `mobile_ui.gd`의 부채꼴 좌표 계산만 남기고
  (기존 그리드도 어차피 미소비 상태였으므로 "더 나빠진 것" 없음), README에
  "레이아웃만 준비, 미연결" 경고를 명시했다(향후 세션이 착각하지 않도록).
- 검증: barb/sorc 표준 오토퀴트 `[MOBILE_UI] verdict=PASS` 포함 전체 PASS,
  `tools/progression_combat_test.gd` PASS, 전체 로그 스윕 0건(부채꼴 좌표 계산
  로직만 남은 최종 상태 기준).
- Web release export 전 `DEPLOYED_AT_KST` 상수 갱신(지난 라운드에 기록한 워크플로
  규칙 최초 적용) → gh-pages 배포 커밋 `dc1d8a9`(이 배포 시점엔 아직 버튼 호출부를
  추가하기 전이라 실질적으로 "레이아웃 로직만" 배포된 상태와 동일), Pages 빌드
  `built`, 루트 HTTP 200, 로컬/원격 PCK SHA-256(`c6e2c26c...`) 일치 확인.
  Playwright 시각 검증은 `playwright_custom_user_agent`를 **첫 navigate 이전에**
  설정해야 한다는 점을 실측으로 확인(이미 한 번 navigate한 세션에서는 UA를
  바꿀 수 없음 — "Page was already initialized with a different User Agent"
  에러) — 일반 데스크톱 UA/뷰포트 리사이즈만으로는 `prefer_mobile()`이 계속
  데스크톱 프로필로 판정됨.

## 2026-10-08 유니크 1게임 1드롭 제한 + 리롤 비용 품질별 분리 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-08-unique-drop-limit-and-reroll-cost-design.md`.
  `classic.battle.net/diablo2exp/items/`와 Tistory 호라드릭 큐브 레시피 블로그를
  리서치해 `docs/research/d2-item-system-reference.md`,
  `docs/research/d2-horadric-cube-recipes.md`(둘 다 이전 라운드에 커밋 완료)의
  "대조용 체크리스트"를 이번 라운드에서 반영했다.
- 체크리스트 중 3개 항목(소켓 촉매=해골 역할 유지, 소켓 레시피 장비별 세분화,
  노말/익셉셔널/엘리트 베이스 체계)은 AskUserQuestion으로 확인해 전부 "현재
  유지/보류"로 확정, 3개 항목(매직 접두/접미사 25/25/50 분할, 접사 그룹 배타,
  세트 부분 보너스 인프라)은 코드 확인 결과 이미 구조적으로 충족돼 변경 불필요—
  실제 구현 범위는 (A) 유니크 1게임 1드롭 제한, (B) 리롤 비용 품질별 분리(매직
  3/레어 6, 원작 비율 유지하되 재료는 토파즈로 유지) 두 가지로 좁혔다.
- `item.gd roll_drop()`에 `dropped_uniques: Dictionary` 선택 인자 추가 — 이미
  드롭된 유니크 베이스는 유니크 판정에서 제외되고 기존 `elif` 캐스케이드가
  자연히 레어/매직/노말로 떨어뜨린다. `main.gd`에 세션 스코프 `_dropped_uniques`
  멤버 추가(저장/로드 영속화 없음, 몬스터 처치 드롭 경로 1곳만 배선).
- `craft.gd REROLL_COST`를 고정값에서 `{"magic": 3, "rare": 6}` 딕셔너리로 교체,
  `can_reroll()`/`reroll()`이 아이템 품질로 비용을 조회하도록 수정.
- **구현 중 발견한 회귀와 수정**: 5b(레어 리롤 비용) 테스트를
  `main.gd _craft_selftest()`에 추가한 직후 `autoquit barb`가 `kills=0`으로
  실패(재현 실행도 동일 결과 — 플레이키 아님). 스태시 베이스라인 대조로
  확인한 원인: `_craft_selftest()`가 처음부터(5/6/7번 항목) 라이브 던전과
  같은 `_rng`를 공유해 왔고, `autoquit`은 `_rng.seed = 42`로 고정되는데
  `_start_game()` 이전에 실행되는 이 함수가 소비하는 난수 횟수가 바뀌면
  이후 던전의 몬스터 스폰·챔피언 구성까지 전부 다른 분기로 틀어진다 — 신규
  5b 항목의 `generate`+`reroll` 호출 쌍 하나가 seed=42 한정으로 50초
  오토퀴트 창 안에 몬스터를 한 번도 마주치지 못하는 레이아웃을 만들어냈다.
  수정: `_craft_selftest()` 전체가 라이브 `_rng` 대신 함수 스코프의
  `test_rng`(별도 시드)를 쓰도록 변경해 던전 RNG 스트림과 격리 — 이후
  동일 시드 재검증에서 `kills=15 verdict=PASS`. **교훈**: pre-game
  셀프테스트가 라이브 RNG를 공유하는 구조는 테스트 추가/수정마다 같은
  사고를 반복시킨다. 상세: `[[dead-system-caution]]`과 별개로 새 교훈으로
  별도 메모리에 기록.
- 검증: `system_tests.gd` 유니크 드롭-once 체크 신규 추가(`checks=114→115`),
  barb/sorc 표준 오토퀴트 `verdict=PASS`, `tools/progression_combat_test.gd`
  PASS, `tools/cube_ui_test.gd` PASS(리롤 버튼 라벨 변경 반영 확인), 전체 로그
  `verdict=FAIL`/`"ok": false` 스윕 0건.
- `DEPLOYED_AT_KST` 갱신 후 Web release export → gh-pages 배포 커밋 `a22e59d`,
  Pages 빌드 `built`(commit 일치 확인), 루트 HTTP 200, 로컬/원격 PCK
  SHA-256(`b43c6350...`) 일치 확인, playwright로 클래스 선택 화면 렌더링과
  새 타임스탬프 표시 확인.

## 2026-10-08 죽은 함수 정리 (소스만 커밋, 재배포 없음)

- 2026-10-04에 보류됐던 죽은 함수 감사(`online_authority.gd`/`world_stream.gd`/
  `level_gen.gd`/`data.gd`의 단일/0회 grep 후보 6개)를 재개. `main.gd` 범위로
  좁힌 grep은 false positive를 낼 수 있어 저장소 전체 재검색 + `git log -S`로
  재검증.
- **살아있는 코드로 판명(변경 없음)**: `account_id_for_token`/`world_snapshot`
  (`online_authority.gd`)은 `tools/network_harness.gd`에서, `monster_art_errors`
  (`data.gd`)는 `tools/asset_compiler.gd`에서 사용 중 — 둘 다 `main.gd` 밖의
  별도 빌드/네트워크 테스트 툴이라 처음 grep에서 놓쳤다.
- **삭제(저장소 전체 기준 0회 참조 확인)**: `world_stream.gd`의
  `reveal_global_tile`(초기 스트리밍 구현부터 한 번도 호출된 적 없는 죽은
  편의 래퍼), `_retire_oldest`(`retire_farthest`가 범용 `_retire_at(index)`로
  리팩터되며 생긴 부산물), `_carve_entry`(`2ecff97`에서 청크별
  entrance_cell/exit_cell 방식으로 의도적으로 대체), `level_gen.gd`의
  `_farthest_slot`(`243b797`에서 `_slot_distance` 방식으로 의도적으로 대체).
  뒤 2개는 사용자의 의도적 설계 변경으로 대체된 경우지만, "제거된 기능
  재연결"이 아니라 "이미 대체되고 남은 죽은 헬퍼 삭제"라 사용자 확인 없이
  진행(스킬 버튼 사례와는 성격이 다름).
- 검증: barb/sorc 표준 오토퀴트 PASS(`[MAP_VARIANTS]` 포함), `[SYSTEM]
  checks=115`(스트리밍 청크 라이프사이클 셀프테스트는 이 집계에 포함돼 있어
  별도 확인 불필요), `tools/progression_combat_test.gd` PASS, 전체 로그
  `verdict=FAIL`/`"ok": false` 스윕 0건. 소스 커밋 `2e2bceb`, 웹 동작 변경이
  전혀 없는 self-test 전용 변경이라 정직 원칙에 따라 gh-pages 재배포 생략.

## 2026-10-08 제작(Crafted) 아이템 큐브 레시피 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-08-crafted-items-design.md`.
  `d2-item-system-reference.md` §8 체크리스트의 마지막 미반영 항목을 반영 —
  연구 문서 §4(베이스=매직, 고정 속성 3~4개 + ilvl 구간별 랜덤 접사 1~4개,
  접사레벨 공식)를 이 프로젝트 구조에 맞게 근사. 레시피 4계열(Hit Power/
  Blood/Caster/Safety Items)은 미조사 상태라 단일 범용 레시피로 범위를
  좁혔고, 신규 주얼류 아이템 타입은 도입하지 않음(드롭/아틀라스 확장 회피).
- 레시피: 매직 weapon/armor 1개 + Saal 시길 1개 + Perfect Ruby 1개(큐브) →
  "crafted" 품질로 제자리 변환. 고정 접사 2개(weapon: ar+20~40/cdmg+3~8,
  armor: def+10~20/res_all+5~10, 전부 combat.gd에서 이미 실전 소비되는 기존
  스탯 키 재사용) + ilvl 구간별 확률표로 뽑은 랜덤 접사 1~4개(절반은
  접두사풀/절반은 접미사풀, 기존 `_roll_affixes()` 재사용). 접사레벨 공식은
  원문의 `ilvl=int(0.5*clvl)+int(0.5*base_ilvl)` 가중평균만 적용하고 qlvl
  보정은 0으로 근사(이 프로젝트가 qlvl을 모델링하지 않음 — qlvl=0을 원문
  공식에 대입하면 사실상 항등이 되므로 의미 없는 분기를 코드에 남기지 않음).
- **재료 선택 중 발견한 함정 회피**: 처음엔 `diamond:perfect`를 보석 촉매로
  검토했으나 `diamond`/`amethyst`는 `GEM_STATS`에 스탯만 정의돼 있고
  `art_recipes.json`에 아이콘이 없어(컴파일된 보석 아이콘은 ruby/sapphire/
  topaz/emerald/skull 5종뿐) 쓰면 2026-10-04의 `[ASSET] "ok": false` 함정을
  재현할 뻔했다 — 이미 드롭·아이콘·5단계 승급 체인이 전부 작동하는
  `ruby:perfect`로 교체. 룬은 `Saal`(어떤 룬워드에도 안 쓰임)을 선택했는데,
  몬스터 드롭 풀(`main.gd`의 `gems` 배열)이 지금까지 `rune_Ahn`/`rune_Vey`만
  포함해 획득 경로가 아예 없었다는 것도 함께 발견 — 룬 아이콘은 이름 무관
  범용이라 아틀라스 작업 없이 드롭 풀에 `rune_Saal`만 추가해 해결.
- **품질 등급 테이블 누락 발견**: "crafted"를 신규 품질 문자열로 도입하며
  하드코딩된 품질 순서/배율 테이블 3곳이 누락되면 실질 버그가 생긴다는 것을
  확인 — `automation.gd QUALITY_RANK`(없으면 자동 장착/판매/경매 게이트가
  crafted를 normal과 동급 취급, 2026-10-04에 활성화한 등급 게이트와 충돌),
  `main.gd _item_value`(판매가 표 누락 시 기본값으로 저평가), `main.gd
  _cycle_automation`의 `levels` 배열(UI 순환에서 crafted가 아예 안 보임).
  전부 rare와 set 사이에 삽입(rank 3, 판매가 160, 등급 순환 노출).
- **cube_ui_test.gd 실측 중 발견한 버그**: 새 Craft 버튼 핸들러가
  `_player.level`을 참조했는데, 이 테스트 하네스는 `Main.new()`를
  `_start_game()` 없이 직접 생성해 `_player`가 Nil — `_player != null`
  가드(기존 `main.gd:3010`과 동일 패턴) 추가로 수정, 실제 플레이에서는
  `_player`가 항상 존재해 영향 없음.
  `game._automation.materials["ruby:perfect"] = 1`로 명시 재설정
  필요(이전 INSERT 단계에서 소진됨) — 이 또한 cube_ui_test에서 CRAFT 섹션을
  양성 테스트(버튼 활성화 확인 + 실제 클릭 → 품질 전환/재료 소모 검증)로
  추가하며 드러남.
- 검증: barb/sorc 표준 오토퀴트 PASS(`[P4] craft: ... : true` 포함),
  `[SYSTEM] checks=115→119`, `tools/progression_combat_test.gd` PASS,
  `tools/cube_ui_test.gd` PASS(1차 실행에서 `_player` Nil 크래시로 FAIL →
  수정 후 재실행 PASS), 전체 로그 `verdict=FAIL`/`"ok": false` 스윕 0건.
- `DEPLOYED_AT_KST` 갱신 후 Web release export → gh-pages 배포 커밋
  `db13b7e`, Pages 빌드 `built`(commit 일치 확인), 루트 HTTP 200,
  로컬/원격 PCK SHA-256(`aec08dac...`) 일치 확인(이번엔 `curl`로 원격 pck를
  직접 fetch해 해시 — 로컬 두 사본끼리 비교하지 않도록 주의), playwright로
  클래스 선택 화면 렌더링과 새 타임스탬프 표시 확인.
- **배포 후 advisor 리뷰로 발견한 실버그**: `craft.gd can_craft()`가
  감정 여부를 안 걸러서, 미감정 매직 아이템에 큐브 재료(Saal 시길+Perfect
  Ruby)를 써도 `Craft.craft()`가 재료를 먼저 소모한 뒤 `Item.craft()`가
  실패해 아이템은 그대로인데 재료만 사라지는 결함이 있었다(`can_reroll()`은
  처음부터 `item_script.is_identified(it)` 가드가 있었는데 `can_craft()`만
  빠뜨림). 실전 영향은 제한적(큐브 UI 필터가 감정된 아이템만 노출하고,
  `roll_drop()`은 rare만 미감정으로 생성해 현재 드롭 경로로는 미감정 매직
  아이템이 안 나옴)이었지만 가드 자체는 계약을 어긴 결함이라 즉시 수정 —
  `can_craft()`에 동일 가드 추가, `system_tests.gd`에 "미감정 아이템은 재료
  소모 없이 거부" 회귀 추가(`checks=119→120`). 같은 리뷰에서
  `automation.gd expire_auctions()`가 rank를 서수가 아니라 수량으로 쓰는
  유일한 소비처라 set/unique 만료 경매 보상이 조용히 +1씩 올랐다는 것도
  확인(허용 가능한 수준이라 별도 수정 없음, 기록만).

## 2026-10-09 아이템 스크랩북 + 유니크/세트 수치 범위화 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-09-item-scrapbook-design.md`,
  구현 계획: `docs/superpowers/plans/2026-10-09-item-scrapbook-plan.md`.
  사용자가 "아이템습득시 인벤토리 대신 스크랩북에 기록, 골드로 복원"을
  제안했는데, 브레인스토밍 중 사용자가 직접 정정 — 실제 요구는 "기존
  습득→자동감정→자동장착 흐름은 그대로 두고, 스크랩북은 같은 종류를 나중에
  골드로 하나 더 뽑는 별도 소모형 티켓 시스템"이었다. AskUserQuestion으로
  8차례 확인(범위=장비만, ilvl=드롭 시점 고정, 등급=기록 시점 확정, 복원 후
  자동장착 안 함(수동), 티켓=소모형(카탈로그 아님), 유니크 중복 지급은 의도된
  우회, 유니크/세트 수치 범위화도 이번 라운드에 포함)를 거쳐 설계 확정.
- 구현: `item.gd`의 `UNIQUES`/`SETS` 접사가 고정 정수에서 `[min,max]` 범위로
  바뀌어 `generate()`가 매번 범위 내 랜덤값을 뽑는다(드롭·스크랩북 복원
  공통 적용 — 스크랩북 전용 변경 아님). `find_base(name, slot)` 헬퍼 신규
  추가(스크랩북 티켓이 베이스 딕셔너리 전체가 아니라 이름만 저장하므로
  복원 시 역조회 필요). 신규 `scrapbook.gd`(`craft.gd`와 동일한 의존성 주입
  패턴 — `item_script: GDScript`를 받아 `item.gd`를 직접 preload하지 않음):
  `add_ticket`/`cost`/`can_restore`/`redeem`/`snapshot`/`restore`/`selftest`.
  `_pickup()` 장비 분기 끝에 `_scrapbook.add_ticket(...)` 한 줄만 추가(기존
  자동감정/자동장착/자동판매 로직 완전히 불변). 저장 스키마에 `"scrapbook"`
  키 추가(기존 `collection_book` 패턴과 동일한 additive 방식). 가방 옆에
  "Scrapbook" 패널 신설(기존 Collection/Cube 패널과 동일 구조).
- **유니크 1게임 1드롭 제한과의 관계(의도된 우회)**: `redeem()`은
  `roll_drop()`의 `_dropped_uniques` 추적을 거치지 않고 `generate()`를 직접
  호출하므로, 2026-10-08에 추가한 "유니크 1게임 1드롭" 제한을 구조적으로
  우회한다 — 자연 드롭에만 적용되는 제한이고, 골드를 내는 별도 경로의 중복
  지급은 사용자가 명시적으로 승인한 설계.
- 검증: `scrapbook.gd` 자체 `selftest()`를 `Mercenary.selftest()`와 동일한
  패턴(완전히 로컬 RNG만 써서 라이브 `_rng`와 무관 — `test_rng` 래퍼 불필요)
  으로 최종 `ok` 집계에 직접 연결, `[SCRAPBOOK] selftest verdict=` 출력
  추가. `system_tests.gd`의 유니크/세트 고정값 단언 4건을 범위 검사로 전환
  (`checks=120` 유지, 신규 체크 추가가 아니라 기존 체크의 조건만 변경).
  barb/sorc/progression/cube_ui 전부 PASS. 중간에 `[PERF] logic_hz` 1회
  FAIL이 있었으나 재실행에서 24.56으로 정상 — RNG 결정론과 무관한 머신 부하
  플레이키로 판정(재실행 1회로 즉시 확인, [[shared-rng-selftest-pitfall]]의
  "지문 비교" 절차와는 다른 카테고리의 플레이키라는 점도 기록).
- `DEPLOYED_AT_KST` 갱신 후 Web release export → gh-pages 배포 커밋
  `bf55731`, Pages 빌드 `built`, 루트 HTTP 200, 로컬/원격 PCK
  SHA-256(`d219a6bd...`) 일치 확인(curl로 원격 pck 직접 fetch), playwright로
  클래스 선택 화면 렌더링과 새 타임스탬프 표시 확인.
- 브레인스토밍→writing-plans→executing-plans 스킬 체인을 이 세션에서 처음
  정식으로 사용(이전 라운드들은 설계 문서만 쓰고 바로 구현하는 경량 패턴이었음)
  — 신규 게임플레이 시스템(죽은 코드 삭제나 버그 수정이 아니라 플레이어가
  체감하는 새 기능)이라 브레인스토밍의 "일단 설계부터" 게이트가 정당하게
  작동한 사례. 플랜 자체 점검(self-review)에서 `scrapbook.gd`의
  `selftest()`를 작성만 하고 실제로 아무데서도 호출하지 않는 배선 누락을
  실행 전에 미리 잡아냈다 — 이 프로젝트가 반복적으로 겪어온 "셀프테스트
  추가했는데 최종 ok에 안 묶임" 패턴([[systems-built]] 참고)이 계획 단계에서
  선제적으로 방지된 첫 사례.
