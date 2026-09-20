# Phase 3 — 아이템 + 접사 + 드롭 + 인벤토리 (수직 슬라이스 완성)

로드맵의 **"게임이 돈다"** 완성점: 이동 → 전투 → **드롭 → 줍기 → 장착 → 스탯 변화**.

## 실행
```
godot --path . --rendering-driver opengl3
```
- **이동:** 좌하단 조이스틱. **스킬:** Bash/Bsrk/BO. **가방:** 우상단 Bag 버튼.
- 몬스터 처치 시 아이템 드롭(색=품질: 흰 노멀 / 파랑 매직 / 노랑 레어).
- 아이템 위를 지나가면 **자동 획득**. Bag 열어 아이템 클릭 → **장착**(무기/방어구) → 스탯 즉시 변화.

### 비대화식 검증 (자동 파밍)
```
godot --path . --rendering-driver opengl3 -- autoquit   # 12초: 킬→드롭→줍기→자동장착
```

## 딥리서치 → 코드 (`item.gd`)
- **접사 규칙**(Part 1 §3): 매직 = 접미사만50%/접두사만25%/둘다25%, 레어 = pre 1~3 + suf 1~3
- **접사 테이블**(Part 3 §2): Jagged/Deadly/Vicious(%ED)·Bronze/Gold(+AR)·Sturdy(+Def) / of the Jackal·Wolf(+Life)·of Strength 등 (부분집합)
- **ilvl→alvl 필터**: 아이템 레벨 이하 접사만 등장
- **드롭/NoDrop**(Part 1 §4): 40% NoDrop + 품질 롤
- **MF 수확체감**(Part 5 §5): 레어 확률 = `4% × (1 + effMF/100)`, `effMF = MF×600/(MF+600)`

## 구조
`item.gd`(아이템/접사/드롭) · `combat.gd` · `skills.gd` · `actor.gd` · 입력 유닛 · `main.gd`
(드롭 스폰·줍기·인벤토리 UI·장착·스탯 재계산 `_recompute_player`).

## 실측 (2026-09-20, HD 4000)
`kills=5 drops=2 picked=2 bag=2, 방어구 장착으로 def 21→47, verdict=PASS`, 에러 0.

## 다음 (P4/P6/P9 정식화 시)
- 접사 전체 테이블 `MagicPrefix/Suffix.txt` 임포트, 접사 그룹/spawnWeight
- 트레저 클래스(TC) 트리 정식화, 유니크/세트, 소켓/룬워드(P5)
- 인벤토리 그리드(칸 배치·드래그&드롭), 장비 슬롯 확장, 저항 전투 반영
