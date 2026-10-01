# 참(Charm) 아이템 설계

작성일: 2026-10-02
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

반지/목걸이 외에 새 장비 카테고리인 참(Charm)을 추가한다. 드롭/도박/감정/장착 비교/세이브
전부 기존 장비 파이프라인에 자연스럽게 편입시킨다.

## 2. 핵심 설계 결정: 가방 패시브가 아니라 전용 슬롯

D2 원작의 참은 인벤토리 그리드 공간을 소모하는 것 자체가 밸런스 장치다. 이 프로젝트의 Bag은
탭 선택 그리드로 공간 비용이 없으므로, 그대로 "가방에 들고만 있으면 효과 적용"으로 만들면
무제한으로 쌓아 공짜 스탯을 얻는 디제너러시가 생긴다. 따라서 반지(`ring_left`/`ring_right`)와
동일한 패턴으로 전용 슬롯 2개(`charm_left`/`charm_right`)를 추가해 장착 개수를 제한한다.

## 3. 완료 조건

1. 참 베이스 2종(`item.gd CHARM_BASES`, slot "charm", req_level만 요구)이 몬스터 드롭/도박/
   보물방 드롭 테이블에 참여한다.
2. 참은 반지/목걸이처럼 내구도 없음(indestructible), 감정 필요(매직/레어일 때).
3. 캐릭터는 참을 좌/우 전용 슬롯 2개까지 장착 가능. 장착 규칙은 반지와 동일(빈 슬롯 우선,
   둘 다 차 있으면 전투력 비교로 교체 여부 결정).
4. 참의 접사는 기존 `_recompute_player()`의 장비 순회에 자동 편입되어 스탯/저항에 반영된다.
5. 세이브 스키마가 v16→v17로 올라가며, 구 세이브는 빈 참 슬롯으로 마이그레이션된다.

## 4. 범위와 비범위

### 범위
- `item.gd`: `CHARM_BASES`, `indestructible`/`identify()` 허용 목록에 "charm" 추가,
  `roll_drop()` 베이스 버킷에 참 추가(기존 버킷 비율 재분배: 무기 38%/방어 34%/장신구 14%/
  참 14%)
- `main.gd`: `EQUIPMENT_SLOTS`/`_equipped`에 `charm_left`/`charm_right`, `_equipment_slot_for_item`을
  반지/참 공통 `_dual_slot_for_item` 헬퍼로 일반화, 도박(`_gamble`)·보물방(`_spawn_treasure_loot`)
  드롭 테이블에 참 추가, 캐릭터 패널에 좌/우 참 표시
- `save_store.gd`: 스키마 v16→v17 마이그레이션
- `system_tests.gd`: 참 생성/감정/내구도 면제/듀얼 슬롯 접사 합산/용병 비장착 검증

### 비범위
- 참 전용 고유(유니크)/세트 아이템(`UNIQUES`/`SETS`에 참 항목 미등록 — 일반/매직/레어까지만)
- 참 3종(소형/중형/대형) 크기 구분이나 각인 스킬(D2 고유 기능, 이 프로젝트에는 미이식)
- 참을 가방에서 "소지"만 해도 발동하는 패시브 경로(의도적으로 배제, 위 2절 참고)

## 5. 상세 설계

### 5.1 장착 라우팅

`_equipment_slot_for_item`은 item_slot이 "ring"이면 `ring_left`/`ring_right`, "charm"이면
`charm_left`/`charm_right`로 위임하는 얇은 분기만 남기고, 실제 선택 로직은 새 헬퍼
`_dual_slot_for_item(it, left, right)`로 추출했다(반지 로직을 그대로 복사하지 않고 공유).

### 5.2 스탯 반영

`_recompute_player()`는 이미 `EQUIPMENT_SLOTS`를 순회하며 `Item.effective_affixes()`를
합산하므로, 배열에 `charm_left`/`charm_right`를 추가한 것만으로 참의 접사(str/dex/ar/ed/
life/mana/def/res_all/개별 저항)가 자동으로 적용된다. `_loadout_combat_power`/`_auto_equip`/
`_power_with_item`도 동일한 배열을 쓰므로 자동 장착 비교·전투력 표시에도 그대로 편입된다.

### 5.3 드롭/도박 참여

`item.gd roll_drop()`과 `main.gd _gamble()`의 베이스 버킷 확률을 무기 38% / 방어 34% /
장신구(반지+목걸이) 14% / 참 14%로 재분배했다(기존 42/42/16에서 참 몫을 분리). 보물방
(`_spawn_treasure_loot`)의 레어 드롭 풀에도 `CHARM_BASES`를 추가했다. 액트 보스 확정 유니크
드롭(`_complete_act`)은 참 유니크가 없으므로 그대로 둔다(비범위).

### 5.4 검증

- `item.gd`/`main.gd`/`save_store.gd` 변경은 모두 기존 `[SYSTEM]`/`[SAVE]` 집계에 자동
  편입(각각 `_check()` 호출 증가, schema 체크 23→24).
- `Coverage.validate()`의 베이스/슬롯 집계는 `data.gd`의 별도 정적 샘플을 보기 때문에
  `item.gd`의 런타임 테이블 변경과 무관하다(이미 분리되어 있던 설계, 확인 후 변경 없음).
- 오토퀴트(barb/sorc): 캐릭터 패널에 Left/Right Charm 표시, `[SAVE]`/`[SYSTEM]` PASS로
  충분(참 장착 자체는 가방 UI 경로라 인벤토리 그리드 UI 때와 동일하게 최종 verdict에
  게임플레이 의존 로그를 추가로 묶지 않음).
