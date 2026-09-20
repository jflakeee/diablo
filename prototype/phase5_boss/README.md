# Phase 5 — 몬스터 다양화 + AI + 보스 (P7+P8)

디아블로2 클론 Phase 5: 몬스터 AI 유형 분화 + **액트1 보스 공격 루틴 상태머신**.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3               # 직접 플레이
godot --path . --rendering-driver opengl3 -- autoquit   # 14초 자동 보스전 검증
```

## 딥리서치 → 코드
- **몬스터 AI 유형**(P7): `kind` 메타로 분기
  - `melee` — 추격 후 근접(Fallen, Zombie)
  - `ranged` — 사거리(5)까지 접근 후 원거리 공격(Spike Fiend)
  - `boss` — 상태머신
- **보스 공격 루틴**(P8, Part 3 §4 안다리엘): 3패턴
  - **독노바**(4초 주기, 반경 내 AoE)
  - **근접**(인접 시)
  - **독분사**(원거리, 2.5초 CD)
- 명중률/데미지는 Part 1/5 공식(`combat.gd`) 그대로 사용.

## 실측 (2026-09-20, HD 4000)
```
boss_hp=434/500  melee=9  nova=3  spray=1  kills=3   verdict=PASS
```
→ 3패턴 모두 발동, 원거리 AI 작동, 런타임 에러 0.

## 참고
- 보스 HP는 프로토타입용 축소(500). 정식 안다리엘 Normal HP=1024 (Part 3 §4).
- 정식화 시: 독 DoT(지속 피해), 페이즈 전환, 소환, 액트1 다구역+워프 연결, `monstats.txt` 임포트.
