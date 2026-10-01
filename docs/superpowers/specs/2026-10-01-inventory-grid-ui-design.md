# 인벤토리 그리드 UI 설계

작성일: 2026-10-01
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

가방(Bag) 보기는 지금까지 아이템마다 이름·파워·접사·요구치 텍스트 버튼 + 감정 버튼 +
(Keep/Merc/Stash/Sell/Protected) 액션 행 전체를 세로로 펼쳐 보여줬다. 아이템이 늘수록
스크롤이 길어지고 한눈에 훑기 어렵다. 아이템을 격자 타일로 보여주고, 탭한 하나만 상세
패널(기존 전체 액션 버튼)을 펼치는 구조로 바꾼다.

**명시적 비범위**: D2 정본처럼 아이템이 W×H 칸을 차지하는 드래그앤드롭 격자는 이번 범위에
넣지 않는다. 이 프로젝트의 정의 자체가 "디자인 제외 모든 요소는 D2와 동일, UI는 각색"이라
UI까지 D2와 동일할 필요가 없고([[project-diablo2-clone]]), 드래그 제스처·아이템 칸수
데이터(현재 아이템 데이터에 없음)·격자 충돌 처리는 한 번의 검증→배포→커밋 사이클로 끝낼 수
없는 다단계 작업이라 미완성 상태로 남길 위험이 크다. 탭-격자는 이번 백로그 항목("인벤토리
그리드 UI")을 완결된 형태로 충족한다.

## 2. 완료 조건

1. 가방 보기에서 각 아이템은 64x64 이상(터치 타겟 48px 규칙 충족) 격자 타일로 표시되고,
   타일 텍스트는 베이스 이름(`it["name"]`), 색상은 품질색, 전체 이름은 툴팁으로 노출한다.
2. 타일을 탭하면 그 아이템이 선택되고, 선택된 아이템 하나에 대해서만 기존 상세 패널
   (장착 버튼, 미감정 시 Identify (Free), Keep/Merc/Stash/Sell/Protected 액션 행)이
   그대로 펼쳐진다 — 기존 버튼 로직/핸들러는 전부 재사용(렌더링만 바뀜, 로직 변경 없음).
3. 인벤토리가 비어 있지 않으면 항상 정확히 하나가 선택된 상태를 유지한다(처음엔 0번,
   장착/판매/스택/보관 등으로 선택 아이템이 사라지면 다음 재구성 때 자동으로 0번 재선택).
   아이템이 1개뿐인 상황(예: 자동화 테스트 픽스처)에서도 탭 없이 바로 상세 패널이 보인다.
4. 가방 외 다른 뷰(`cube`, `collection`, `item_log`)는 전혀 건드리지 않는다.
5. 기존 자동화 스크립트가 찾는 UI 요소가 그대로 발견된다:
   - `tools/progression_combat_test.gd`: `_inv_vbox`의 자손 어디서든 "Identify (Free)"
     버튼을 재귀 탐색(`_find_button`)해 찾는다 — 1개짜리 인벤토리가 자동 선택되므로 그대로
     통과.
   - `_run_auto_equip_sell_test`(`auto_equip_sell_test` cmdline): `_inv_vbox`의 **직계
     자식**으로 "RECENT ITEM LOG"로 시작하는 Label을 찾는다 — `item_log` 뷰 렌더링은
     손대지 않았으므로 영향 없음.
   - `tools/cube_ui_test.gd`: `cube` 뷰 전용, 가방 변경과 무관.

## 3. 범위와 비범위

### 범위
- `main.gd _rebuild_inv()`의 가방(`"bag"`) 분기에서 아이템별 전체 상세 행 반복 렌더링을
  "격자 + 선택된 1개의 상세 패널"로 교체
- `_selected_inventory_item` 상태 추가

### 비범위
- 드래그앤드롭, W×H 칸 점유, 소켓형 배치(위 비범위 설명 참고)
- cube/collection/item_log 뷰, 가방 외 다른 패널
- 저장 스키마 변경(선택 인덱스는 영속화하지 않음 — 패널을 열 때마다 0번부터 자연스럽게
  재선택되는 것으로 충분)

## 4. 검증

- `tools/progression_combat_test.gd`: `[PROGRESSION_COMBAT] ... verdict=PASS`
- `tools/cube_ui_test.gd`: `[CUBE_UI] click=true stale_input=true widths=320/640 verdict=PASS`
- `auto_equip_sell_test` cmdline: `[AUTO_EQUIP_SELL] ... history_view=true verdict=PASS`
- 양 클래스 `autoquit`: `[GD][RESULT] verdict=PASS` (가방 UI는 오토퀴트 경로 자체를 거의
  타지 않으므로 위 세 스크립트가 실질적 판별 기준).
