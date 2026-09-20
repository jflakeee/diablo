# Phase 1 — 단일 맵 + 몬스터 + 기본 전투

디아블로2 클론 Phase 1 수직 슬라이스: **딥리서치에서 확보한 실제 D2 공식**으로
이동→전투→피해가 도는 최소 게임 루프.

## 실행
```
godot --path . --rendering-driver opengl3
```
- **이동:** 좌하단 가상 조이스틱(마우스 드래그, 터치 에뮬).
- **공격:** 우하단 Attack 버튼 탭 → 가장 가까운 몬스터 자동조준 근접 공격.
- 몬스터(Fallen×3, Zombie×2)가 추격해 공격. 벽/기둥은 충돌.

### 비대화식 검증
```
godot --path . --rendering-driver opengl3 -- autoquit   # 8초 후 결과 출력·종료
```

## 딥리서치 공식 연동 (`combat.gd`)
- **명중률**: `200 × AR/(AR+DR) × Alvl/(Alvl+Dlvl)`, 5~95% 클램프 (Part 1 §1)
- **물리 데미지**: `min~max × (1 + %ED/100)` (Part 5 §1)
- **바바리안 Life**: `55 + 4×Vit + 2×Level` (Part 1 §2) → L1/Vit25 = **157**

## 구조 (독립 유닛)
- `combat.gd` — 전투 공식(순수 static 함수, 테스트 가능)
- `actor.gd` — 엔티티(스탯/생명/HP바)
- `virtual_joystick.gd`, `skill_button.gd` — 입력
- `main.gd` — 맵/충돌/스폰/AI/전투/HUD 오케스트레이션

## 실측 (2026-09-20, HD 4000 / ANGLE→D3D11)
`attacks=27 hits=26 player_life=94/157 verdict=PASS`, 25Hz 논리틱, 런타임 에러 0.

## 다음(P2/P7 정식화 시)
- AR/Defense 정식 산출(dex·level·장비), 저항/블록/전투 모디파이어(Part 5),
  몬스터 스탯 `monstats.txt` 임포트, 사망/드롭 연결(P6), 스킬 시스템(P3).
