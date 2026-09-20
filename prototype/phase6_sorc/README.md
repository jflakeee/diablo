# Phase 6 — 콘텐츠 확장: 추가 클래스 (소서리스)

디아블로2 클론 Phase 6: **두 번째 클래스**로 스킬 behavior 추상화(Part 4 §1)를 실증.
바바리안(근접)과 달리 소서리스는 **투사체 스펠**을 사용.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3               # 소서리스 플레이
godot --path . --rendering-driver opengl3 -- autoquit   # 12초 자동 전투 검증
```

## 딥리서치 → 코드
- **소서리스 파생**(Part 1 §2): Life 40+2·Vit+1·Lv=81, Mana 35+2·En+2·Lv=107, Def 18
- **스킬 behavior**(Part 4 §1): 
  - **Fireball** — 투사체(behavior=projectile): 대상 추적 후 명중 시 원소 데미지. **스펠은 AR 무시**(저항만 적용)
  - **Static Field** — 즉시(behavior=instant): 대상 현재 생명 25% 감소
  - **Teleport** — 순간이동(behavior=blink)
- 클래스 추가로 `_recompute_player`가 클래스별 파생식 분기 → 시스템이 다중 클래스 지원.

## 실측 (2026-09-20, HD 4000)
```
class=sorceress level=3 kills=4 spells_cast=6 spell_hits=5   verdict=PASS
```
→ 투사체 스펠 시전·명중·처치, 레벨링 크로스클래스 동작, 에러 0.

## 액트 2~5 확장에 대해
액트 확장은 **콘텐츠·데이터**(새 타일셋·몬스터·스토리·퀘스트)이며, 이미 검증된
맵/몬스터/드롭/전투 시스템에 데이터를 얹는 작업이다. 본 프로토타입은 더 어려운
**"새 클래스(시스템)" 확장**을 실증했다. 정식화: 7클래스 210스킬 임포트,
액트별 구역/워프/보스, 난이도(NM/Hell) 스케일링(Part 2 §3).
