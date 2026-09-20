# UI 심화 (P9) — 인벤토리 그리드 + 캐릭터 화면

통합본 위에 D2식 UI를 심화: 인벤토리 그리드(드래그&드롭) + 장비 슬롯 + 캐릭터
화면(스탯/스킬 포인트 배분) + 툴팁.

## 실행
```
godot --path . --rendering-driver opengl3 -- barb    # 또는 -- sorc
```
- **Bag (I키):** 인벤토리 패널 — 좌측 장비 슬롯(무기/방어구), 우측 아이템 그리드.
  - 아이템 **클릭 = 장착**, **드래그 → 슬롯 = 장착**, 슬롯 **클릭 = 해제**. 마우스 오버 = **툴팁**.
- **Char (C키):** 캐릭터 화면 — 스탯(str/dex/vit/energy)·스킬 레벨 + **[+] 버튼으로 포인트 배분**.
- 레벨업 시 스탯 +5 / 스킬 +1 포인트 획득.

## 구조 (독립 UI 유닛)
- `inv_cell.gd` — 인벤토리 셀: 표시 + 클릭(`clicked`) + 드래그 소스(`_get_drag_data`)
- `equip_slot.gd` — 장비 슬롯: 표시 + 클릭 해제 + 드롭 타겟(`_can_drop_data`/`_drop_data`, 슬롯 타입 일치만 수용)
- `main.gd` — `_rebuild_inv`(그리드+슬롯), `_rebuild_char`(배분 UI), `_equip`(스왑), `_unequip`, `_alloc_stat`, `_alloc_skill`

## 검증 (UI 로직 자체검증 = headless 가능)
```
equip: def 21→47 bag 1→0             (인벤→장비, 스탯 반영)
unequip: armor cleared, bag=1        (장비→인벤)
alloc stat: str 30→31 pts→2          (스탯 배분)
alloc skill: bash 1→2 pts→1          (스킬 배분)
[UI][RESULT] ui_selftest verdict=PASS
```
→ 장착 스왑·해제·포인트 배분 로직 검증, 창 렌더 에러 0.

## 정식화
- 진짜 D2 그리드(아이템 크기 1x1~2x4 셀 점유), 창고/큐브/거래 창, 벨트
- 스킬트리 시각화(트리 배치·선행조건·시너지 표시), 마우스오버 상세 툴팁(스탯 색상)
