# 자동 장착 등급 설정 활성화

작성일: 2026-10-04
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

`prompt_diablo.md`(설계 원문) 11~12번 항목 "장비 자동 장착 / 자동 장착 등급 설정"은
절반만 살아 있었다. 자동 장착 자체(`_auto_equip()`)는 동작하지만, UI의 "Cycle Auto
Equip" 버튼이 바꾸는 `_automation.equip_min` 값은 어디에서도 읽히지 않는다 —
`Automation.should_equip()`에 등급 체크가 구현되어 있지만 `_auto_equip()`은 이를
호출하지 않고 독자적인 파워 비교만 수행한다. 플레이어가 버튼을 눌러도 체감되는 동작
변화가 전혀 없는 "죽은 토글"이다.

## 2. 원인

`_auto_equip()`(main.gd:3772)은 `Item.can_equip()`(요구 스탯)만 걸러내고, 이후
`before_power`/`after_power` 비교로만 교체 여부를 정한다. `Automation.should_equip()`
(automation.gd:80, 등급 체크 포함)은 유닛 테스트에서만 호출되고 실제 장착 경로와는
분리되어 있다.

## 3. 완료 조건

1. **빈 슬롯**은 등급과 무관하게 즉시 장착된다(초반 맨손 상태 방지 — 기존 동작 유지).
2. **이미 장착된 아이템을 교체**하는 경우에만 `rank(it.quality) >= rank(equip_min)`을
   추가로 요구한다. 등급 미달이면 파워가 더 높아도 교체하지 않는다("KEPT_LOWER_POWER").
3. 등급 미달로 교체되지 않은 아이템은 기존 `should_auto_sell`/인벤토리 보관 경로를
   그대로 탄다(새 분기 없음).
4. 자동 판매(`auto_sell_max_quality`), 자동 습득(`pickup_min`), 경매(`auction_min`) 경로는
   건드리지 않는다.

## 4. 범위와 비범위

### 범위
- `main.gd`: `_auto_equip()`에 교체 전 등급 게이트 1줄 추가.
- `_run_auto_equip_sell_test()`: 등급 미달 고파워 아이템이 교체되지 않음 → `equip_min`을
  낮춘 뒤 동일 아이템이 교체됨, 두 단계를 확인하는 체크 추가.

### 비범위
- `Automation.should_equip()`/`item_score()` 자체는 수정하지 않는다(여전히 유닛 테스트
  전용 보조 함수로 남음 — 실제 장착 경로는 `_power_with_item`/`_loadout_combat_power`
  기준의 기존 파워 비교를 그대로 사용).
- 빈 슬롯 채우기에 등급 게이트를 적용하는 것(초반 UX 저해, 설계 비범위로 명시).

## 5. 검증

- `_run_auto_equip_sell_test()`: equip_min="rare" 상태에서 normal 등급 고파워 아이템이
  장착된 rare를 교체하지 않음(`grade_gate_blocked`) → `equip_min`을 "normal"로 낮춘 뒤
  동일 계열 아이템이 정상 교체됨(`grade_gate_released`) 확인.
- barb/sorc 표준 오토퀴트 + `tools/progression_combat_test.gd` 재실행으로 회귀 없음 확인.
