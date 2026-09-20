# Phase 4 — 소켓 + 보석 + 룬워드 + 큐빙

디아블로2 클론 Phase 4: 크래프팅 시스템(P5). Phase 3 위에 소켓/보석/룬/룬워드/큐브를 추가.

## 검증 (headless로 로직 자체검증 가능)
```
godot --headless --path . --quit            # 크래프팅 자체검증 [P4] 출력
godot --path . --rendering-driver opengl3    # 게임 실행(드롭/전투는 Phase3 그대로)
```

## 딥리서치 → 코드 (`craft.gd`)
- **룬 순서**(Part 2 §4): El…Zod 33개 서열, 룬워드는 **정확한 룬 순서 + 소켓수 + 베이스 타입** 일치 시 발동
- **룬워드**(부분집합): Steel(Tir+El, weapon2), Stealth(Tal+Eth, armor2), Nadir(Nef+Tir, helm2)
- **Perfect 보석 슬롯별 스탯**(Part 6 §2): Amethyst 무기+150AR / Ruby 갑옷+38Life / Diamond 갑옷+19전저항 등
- **큐브 룬 업그레이드**(Part 3 §3): 동일 하위 룬 3개 → 다음 룬 (El×3→Eld)
- **유효 스탯**(`item.effective_affixes`): 베이스 접사 + 소켓 + 룬워드 합산 → 장착 시 캐릭터 반영

## 자체검증 결과 (2026-09-20, HD 4000, headless+창 모두 PASS)
```
gem  : Ruby→armor +life=38 (>=38)            : true
rword: Tir+El → Steel (ed=20 ar=100)         : true
order: El+Tir → runeword='' (형성 안 됨)      : true   ← 순서 검증
cube : El×3 → Eld                            : true
[P4][RESULT] craft_selftest verdict=PASS
[P4B][RESULT] render+loop OK (no error)
```

## 다음 (정식화 시)
- 룬/보석/룬워드 전체 테이블 임포트, 소켓팅 UI(드래그), 큐브 UI(3x4 그리드)
- 이더리얼/업그레이드/크래프티드 레시피(Part 3 §3 전체)
