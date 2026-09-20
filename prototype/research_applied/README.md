# 미적용 연구 적용 — 브레이크포인트 + 난이도 스케일링

비교 분석에서 `미적용`이던 연구 2건(Part 2 §1 브레이크포인트, §3 난이도)을 구현·연동·검증.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3 -- sorc            # Normal
godot --path . --rendering-driver opengl3 -- sorc nm         # Nightmare
godot --path . --rendering-driver opengl3 -- sorc hell       # Hell
godot --headless --path . --quit                             # 공식 자체검증
```

## 적용 내용 (`combat.gd`)
- **FCR 브레이크포인트**(소서리스 일반 스펠, Part 2 §1): `sorc_fcr_frames(fcr)` → 0:13 9:12 20:11 37:10 63:9 105:8 200:7 프레임. `frames_to_sec = frames/25`로 시전 쿨다운 산출.
- **FHR 브레이크포인트**(바바리안): `barb_fhr_frames`.
- **난이도 스케일링**(Part 2 §3):
  - `diff_monster_hp_mult` = [1.0, 1.8, 3.5]
  - `diff_monster_resist_bonus` = [0, 20, 50]
  - `diff_player_resist_penalty` = [0, -40, -100]  ← 저항 페널티
  - `diff_hell_physical_floor` = Hell 50% 물리 바닥
  - `monster_life_players` = X×(n+1)/2 (인원수)

## 게임 연동
- 파이어볼 쿨다운 = FCR 프레임(기존 고정 0.6 → FCR63시 0.36s)
- 몬스터 스폰: HP×난이도, 화염저항+난이도. 안다리엘 -50+Hell50=0(약점 상쇄)
- 플레이어 화염저항 += 난이도 페널티(Hell -100)
- 플레이어 물리뎀: Hell 물리 50% 바닥 적용

## 실측 (2026-09-21, HD 4000)
```
research_selftest verdict=PASS (FCR/FHR/난이도 공식 전부 일치)
Normal sorc: kills=6 life=62/85 res_fire=0    → 클리어·생존
Hell   sorc: kills=2 life=0/82 res_fire=-100  → 사망 (극악 난이도, 원작 재현)
```

## 정식화 잔여
- IAS(공속) 브레이크포인트를 무기별 WSM + 애니메이션 프레임에 완전 적용
- 냉/번/독 저항까지 4속성, 난이도별 몬스터 스킬레벨(+3/+7)·데미지 스케일
