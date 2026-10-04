# 난이도별 보상 스케일링 (아이템레벨 + 경험치)

작성일: 2026-10-04
대상: `prototype/game_dungeon`
상태: 구현 기준 확정

## 1. 목표

몬스터 HP(`diff_monster_hp_mult`)와 저항(`diff_monster_resist_bonus`, 2026-10-04 Hell
면역 작업)은 난이도별로 스케일링되지만, 몬스터 "레벨" 자체(`m.level`)는 난이도와 무관하게
`data/monsters.json`의 고정값이었다. 그 결과 드롭 아이템레벨(`Item.roll_drop(_rng, mlvl,
mf)`의 `mlvl`)과 킬 경험치(`target.level * 40`)가 Normal/NM/Hell에서 전부 동일했다 —
Hell이 위험만 늘고 보상은 하나도 안 느는 상태였다.

## 2. 왜 몬스터 레벨 자체를 올리지 않는가

`m.level`은 `CombatLib.chance_to_hit(ar, defense, alvl, dlvl)`의 양쪽(공격자 alvl, 수비자
dlvl)에 전부 들어간다. 몬스터 레벨을 올리면 명중률 균형 전체가 바뀌어 버리고, 실측으로도
위험하다: Hell 오토퀴트 스모크 로그(2026-10-04 면역 작업)가 이미 barb kills=4, sorc
kills=1(50초)로 낮았다 — 여기서 몬스터 레벨까지 올리면 Hell 오토퀴트가 거의 킬 0으로
퇴화할 위험이 있다. 그래서 "위험"(HP/저항/명중 균형)은 그대로 두고 "보상"(드롭
아이템레벨/경험치)만 난이도에 비례해 올린다.

## 3. 완료 조건

1. 드롭 아이템레벨에 난이도 보너스(`diff_reward_ilvl_bonus`: Normal+0/NM+4/Hell+8)가
   더해진다 — 챔피언/유니크의 기존 ilvl 보너스(+2/+3)와 누적된다.
2. 몬스터를 처치할 때 얻는 경험치에 난이도 배율(`diff_xp_mult`: Normal x1.0/NM x1.25/
   Hell x1.5)이 적용된다. 경험치를 주는 **모든** 경로(플레이어 근접/투사체/스톰랜스,
   용병 원거리/근접 킬 — 총 5곳)에 빠짐없이 적용한다.
3. Normal(난이도 0)은 두 함수 모두 항등(보너스 0 / 배율 1.0)이라 기존 오토퀴트 baseline과
   완전히 동일하게 동작한다.
4. 몬스터 레벨(`m.level`)과 그에 따른 명중률 계산은 전혀 건드리지 않는다.

## 4. 범위와 비범위

### 범위
- `combat.gd`: `diff_reward_ilvl_bonus(diff)`, `diff_xp_mult(diff)` 순수 함수 2개
- `main.gd`: `_kill_xp(level)` 헬퍼(5개 경험치 지급 지점이 전부 이걸 거치도록 교체),
  몬스터 사망 시 드롭 롤의 `mlvl` 계산에 `diff_reward_ilvl_bonus` 가산
- `system_tests.gd`: 두 순수 함수의 경계값 단위테스트(자동으로 최종 ok에 집계)

### 비범위
- 몬스터 레벨/명중률 스케일링(위 2절 — 의도적으로 손대지 않음)
- 퀘스트 보상 골드/스킬포인트 난이도 스케일링(이미 `_act * 300` 형태로 액트에 비례,
  난이도와는 별개 축이라 이번 범위 밖)
- NM/Hell 보너스 수치의 정밀 밸런싱(합리적 기본값만 설정 — 플레이 테스트로 추후 조정
  가능하도록 순수 함수로 분리해 둠)

## 5. 검증

- `system_tests.gd`: `diff_reward_ilvl_bonus(0/1/2)==0/4/8`, `diff_xp_mult(0/1/2)==
  1.0/1.25/1.5` 경계값 확인(`_check()` 자동 집계, 최종 `[SYSTEM] ok`에 이미 편입된 구조라
  별도 배선 불필요).
- barb/sorc 표준(Normal) 오토퀴트로 baseline 동작 불변 확인(배율 1.0/보너스 0이므로
  결과가 이전과 동일해야 함).
- `autoquit barb hell`/`autoquit sorc hell` 재실행으로 보상 경로가 실제로 작동하고
  크래시 없는지 확인.
- `tools/progression_combat_test.gd`(통합 회귀 검사)를 이번 라운드부터 매 기능 검증
  사이클에 포함하기로 함(README에 "통합 회귀 검사"로 문서화돼 있었지만 이 세션의 지난
  6개 기능 라운드 동안 한 번도 실행되지 않았던 검증 부채를 이번에 처음 재발견·실행).
