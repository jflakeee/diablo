# 통합 프로토타입 (Integrated) — Phase 0~6 + 보스 통합

단계별 프로토타입을 **하나의 플레이 가능한 게임**으로 통합. 클래스 선택 + 맵 +
다양한 몬스터 + 안다리엘 보스 + 드롭 + 인벤토리 + 크래프팅.

## 실행
```
godot --path . --rendering-driver opengl3            # 기본 바바리안
godot --path . --rendering-driver opengl3 -- sorc    # 소서리스
godot --path . --rendering-driver opengl3 -- barb    # 바바리안
```
- **이동:** 조이스틱. **스킬:** 바바리안 Bash/Berserk/BO · 소서리스 Fire/Static/Teleport. **가방:** Bag.
- 몬스터 처치 → 드롭 → 줍기 → Bag에서 장착. 안다리엘(3패턴) 보스전.

### 검증
```
godot --path . --rendering-driver opengl3 -- autoquit barb   # 15초 자동전투
godot --path . --rendering-driver opengl3 -- autoquit sorc
```

## 통합된 시스템 (공용 모듈 1벌)
- `combat.gd` 전투 공식 · `item.gd` 아이템/접사/드롭 · `skills.gd` 바바리안 스킬 ·
  `craft.gd` 소켓/룬워드/큐브 · `actor.gd` 엔티티 · 입력 유닛 · `main.gd` 오케스트레이션
- 클래스 분기: 파생 스탯·스킬·입력·AI가 `_class`로 분기(바바리안 근접 / 소서리스 투사체+카이팅)

## 실측 (2026-09-20, HD 4000)
```
barbarian: kills=3 boss_hp=446/500 life=55/214       verdict=PASS  (탱커 생존)
sorceress: kills=6 boss_hp=0/500  life=23/85         verdict=PASS  (카이팅 보스 처치)
```
→ 두 클래스 뚜렷한 정체성으로 아레나+보스 동작, 런타임 에러 0.

## 정식화 (검증 상태 §3 백로그)
데이터 임포트(monstats/skills/items txt) · 전투 심화(저항/블록/브레이크포인트) ·
콘텐츠(랜덤던전·액트·나머지 5클래스) · UI(그리드 인벤·스킬트리) · 세이브/오디오 · 온라인 결합.
