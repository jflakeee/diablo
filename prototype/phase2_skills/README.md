# Phase 2 — 캐릭터 + 바바리안 스킬트리

디아블로2 클론 Phase 2: 캐릭터 시스템(P2) + 스킬 시스템(P3)을 딥리서치 공식으로 구현.

## 실행
```
godot --path . --rendering-driver opengl3
```
- **이동:** 좌하단 가상 조이스틱.
- **스킬:** 우하단 **Bash**(근접+데미지/명중), **Bsrk**(Berserk: 큰 데미지·적 방어 무시), **BO**(Battle Orders: 최대 Life/Mana 버프).
- 킬로 **XP 획득 → 레벨업 → Mastery 자동 성장**(데모). Mastery는 패시브로 모든 공격에 +데미지/명중/데들리스트라이크.

### 비대화식 검증 (자동 전투)
```
godot --path . --rendering-driver opengl3 -- autoquit   # 10초: BO시전+자동Bash+레벨업
```

## 딥리서치 → 코드
- **파생 스탯**: 바바리안 Life `55+4·Vit+2·Lv`, Mana `10+En+Lv` (Part 1 §2); AR `Dex·5−35 ×(1+보너스%)`, Def `base+⌊Dex/4⌋` (Part 5, 근사)
- **스킬**(Part 3 §1): Bash·Berserk·Battle Orders·Sword Mastery — `skills.gd` 데이터+계수
- **데들리스트라이크**: Mastery 레벨 기반 물리 2배 확률 (Part 5 §4)
- **명중률/데미지**: Part 1 §1 / Part 5 §1 (`combat.gd`)

## 구조 (독립 유닛)
`combat.gd`(공식) · `skills.gd`(스킬 데이터/계수) · `actor.gd`(엔티티+마나+스킬레벨+버프) ·
`virtual_joystick.gd` · `skill_button.gd` · `main.gd`(오케스트레이션)

## 실측 (2026-09-20, HD 4000 / ANGLE→D3D11)
`level=3 kills=3 bo_casts=1 life=181/217 mastery=3 verdict=PASS` — BO가 max_life
157→217로 상승 확인, 레벨업 시 Mastery/스탯 성장. 런타임 에러 0.

## 다음 (정식화 시)
- 스킬 계수·마나코스트 `skills.txt` 임포트, 시너지(하드포인트) 정식 반영
- 스킬 포인트 수동 배분 UI(스킬트리 화면), 스탯 포인트 배분
- 저항/블록/전투 모디파이어 전면 적용(Part 5·6), 무기 기반 데미지/WSM
