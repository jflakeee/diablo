# 보석 품질별 소켓 효과 차등화

작성일: 2026-10-04
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

소켓 시스템 활성화(2026-10-04 앞선 라운드) 설계 문서에 "보석 품질별 효과 차등화는 별도
확장"이라고 명시해 둔 항목을 이번에 처리한다. 지금까지는 "Perfect Ruby"든 "Normal Ruby"든
소켓에 끼우면 완전히 동일한 효과(`life +38`)를 냈다 — 5단계 승급 체인(chipped→flawed→
normal→flawless→perfect, `transmute()`)이 게임플레이 가치를 전혀 만들지 못하는 또 다른
"죽은 트리거" 사례였다.

## 2. 원인

`_insert_material_into_item()`이 삽입 시 `material_id.split(":")[0]`로 품질 접미사를
잘라냈고, `Craft.gem_stat(gem, slot)`도 품질과 무관하게 `GEM_STATS`의 고정값만 반환했다.
`GEM_STATS`의 값은 주석대로 **Perfect 등급 기준**이라, 사실상 모든 등급이 Perfect 효과를
받고 있었다.

## 3. 완료 조건

1. 소켓에 보석을 끼울 때 품질 접미사(`:quality`)가 보존된다.
2. `Craft.gem_stat()`이 품질별 배율을 적용한다: chipped .4 / flawed .55 / normal .7 /
   flawless .85 / perfect 1.0(정수 반올림, 값이 큰 등급일수록 항상 같거나 더 큰 효과).
3. 접미사 없는 베어 id(구버전 세이브/기존 셀프테스트 호환)는 normal(.7)로 취급한다.
4. 룬/룬워드 경로는 전혀 건드리지 않는다(룬은 품질 등급이 없다).

## 4. 범위와 비범위

### 범위
- `craft.gd`: `GEM_QUALITY_SCALE` 상수, `gem_stat()`을 `name:quality` 파싱 + 배율 적용으로
  재작성
- `main.gd`: `_insert_material_into_item()`이 보석은 전체 id(품질 포함)를 그대로
  `Item.socket_insert()`에 전달(룬은 `rune_` 접두사만 제거하는 기존 방식 유지)
- `_craft_selftest()` 7번째 체크, `tools/cube_ui_test.gd`에 "Perfect Ruby"가 삽입 후
  `socketed[0].id == "ruby:perfect"`로 유지되는지 확인

### 비범위
- chipped/flawed를 드롭 테이블에 추가(드롭은 normal에서 시작해 위로만 업그레이드하는
  기존 설계 유지 — 콘텐츠 확장이지 이 버그 수정의 범위가 아님). 두 등급의 배율은 정의만
  해 둔다(큐브로 normal 이하로 내리는 경로는 없지만, 향후 레거시 데이터 호환을 위해
  테이블에 남겨둠).
- 룬 품질 체계(원래 이 프로젝트의 룬은 등급이 없음, D2 원작과 다른 의도적 단순화 유지).

## 5. 소급 적용에 대한 메모

이미 소켓에 끼워진 보석이 있다면(이 기능은 이틀 전에 막 생긴 기능이라 실제로는 거의
없겠지만), 이번 변경으로 효과가 재계산된다 — `Item.effective_affixes()`는 저장된 배율이
아니라 매번 `socketed[i].id`에서 실시간으로 다시 계산하므로, 코드 배포 즉시 모든 소켓
효과가 새 배율로 조정된다. 별도 마이그레이션 불필요.

## 6. 검증

- `_craft_selftest()` 7번째 체크(`[P4] gem_quality: ...`): Perfect Ruby의 `life` 효과가
  Normal Ruby보다 크고, 0보다 큼을 확인.
- `tools/cube_ui_test.gd`: "Insert Perfect Ruby" 버튼을 찾아 클릭한 뒤
  `socketed[0].id == "ruby:perfect"`로 품질이 보존되는지 확인.
- barb/sorc 표준 오토퀴트 + `autoquit barb/sorc hell` + `tools/progression_combat_test.gd`
  재실행으로 회귀 없음 확인(이번 라운드부터 통합 회귀 검사를 매 기능 사이클에 포함).
