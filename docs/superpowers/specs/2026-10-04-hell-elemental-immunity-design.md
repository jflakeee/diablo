# 난이도별 몬스터 원소 면역 활성화

작성일: 2026-10-04
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

저주/오라 면역돌파 시스템(`combat.gd reduced_resistance`, Storm Lance hex / Iron Chant
aura, "Immunity: 1/5 effect" 문구)은 이미 완전히 구현·단위테스트까지 되어 있었지만,
실제로 면역(저항 100 이상)이 발생하는 원소가 독(poison) 하나뿐이었다 — 두 클래스 모두
독 데미지를 쓰지 않으므로 이 시스템은 실전에서 한 번도 발동하지 않는 죽은 코드였다.
난이도 저항 보너스(`CombatLib.diff_monster_resist_bonus`)는 이미 존재·연결되어 있었으니,
숫자만 조정해 Hell에서 fire/cold/light 면역이 실제로 나오게 한다.

## 2. 조사 결과 (왜 숫자만 바꾸면 되는가)

- `combat.gd apply_resistance`: 저항 100 이상이면 데미지 0(토큰 데미지 없음, 완전 면역).
- `combat.gd reduced_resistance`: 기준 저항이 100 이상일 때만 저주+오라 감소량을 1/5로
  깎는 "면역 돌파" 공식. 경계값까지 `system_tests.gd`에 이미 전부 단위테스트되어 있음.
- `main.gd _target_resist()`: 몬스터 전투 데미지 계산 경로(파이어볼/프로스트/스톰랜스/
  용병 원소뎀 전부)가 이미 `reduced_resistance(base, curse, aura)`를 거친다.
- `main.gd` 몬스터 스폰: `m.res_fire = int(md.get("res_fire",0)) + rbonus` 식으로 난이도
  보너스가 이미 적용되고 있었다.
- 즉 파이프라인 전체가 이미 올바르게 연결돼 있었고, 유일한 문제는 `diff_monster_resist_bonus`
  의 Hell 값(기존 50)이 보유 몬스터 데이터(`data/monsters.json`)와 맞물려 fire/cold만
  정확히 100(여유 없음)을 만들고 light는 90으로 끝내 면역에 못 미쳤다는 것.

## 3. 변경 내용

`combat.gd diff_monster_resist_bonus`: `[0, 20, 50]` → `[0, 20, 70]`(Normal/NM은 그대로,
Hell만 상향). 결과(현재 `data/monsters.json` 기준):

- Hell(+70): ash_caller fire 50→120, bone_guard/bone_marksman cold 50→120,
  horned_marauder light 40→110, venom_husk fire 40→110 — fire/cold/light 모두 여유 있게
  면역.
- NM(+20): fire 최대 70, cold 최대 70, light 최대 60 — 전부 100 미만(면역 없음, 설계대로).
- Normal(+0): 변화 없음(기존 오토퀴트 baseline과 동일).

**Brood Matron의 불 약점(-50)이 Hell에서 -50+70=20(약간 저항)으로 바뀐다.** Normal(-50)/
NM(-30)에서는 약점이 그대로 유지되고, Hell에서만 사라진다 — D2 원작도 고난이도일수록
보스 고유 약점이 상대적으로 희석되는 경향이 있어 이 각색을 의도적으로 받아들인다(별도
보정 없음).

## 4. 범위와 비범위

### 범위
- `combat.gd`: `diff_monster_resist_bonus` Hell 값 조정
- `main.gd`: `_immune_selftest()`(정적 데이터로 Hell=fire/cold/light 전부 면역,
  Normal/NM=전부 비면역을 검증) + 최종 `ok` 집계 편입

### 비범위
- 물리 면역(별도 저항 채널이 없어 새 전투 버킷 도입 필요 — 더 큰 변경)
- 몬스터 데이터/룬워드 확장(콘텐츠 저작, 시스템 활성화가 아님)
- NM 보너스 조정(기존 20으로도 "NM은 면역 없음" 목표를 이미 만족하므로 손대지 않음)

## 5. 검증

- `_immune_selftest()`: `Data.monsters()`를 3개 난이도 기준으로 정적 스캔해 Hell에서
  fire/cold/light 전부 최소 1개 몬스터가 면역(>=100)인지, Normal/NM에서는 전부 면역이
  아닌지 확인. `[IMMUNE] ... verdict=` 출력 + 최종 `ok`에 편입.
- `reduced_resistance()`/`apply_resistance()`의 경계값 자체는 이미 `system_tests.gd`에
  단위테스트되어 있어 재작성하지 않음.
- 오토퀴트 스모크 테스트: `autoquit barb hell`/`autoquit sorc hell`로 실제 Hell 던전에서
  크래시 없이 진행되는지 확인(기존 "hell" cmdline 플래그 재사용, 새 플래그 없음).
- 표준 `autoquit barb`/`autoquit sorc`(Normal)로 기존 동작에 회귀가 없는지 확인.
