# 프로토타입 진행 기록

개발/검증 머신: **i5-3360M(2C/4T) · 8GB · Intel HD 4000 · Win10** (최저사양 타깃).
엔진: **Godot 4.7.2**, Compatibility(OpenGL3 → 자동 ANGLE → Direct3D11).

| 단계 | 프로토타입 | 검증(실측) | 상태 |
|------|-----------|-----------|------|
| P0 렌더 | `p0_render_smoke` | 아이소+y-sort 826 스프라이트 **avg 145 / min 116 fps** | ✅ PASS |
| P0 입력/루프 | `p0_input_loop` | 25Hz 논리틱 **rate 25.14/s**, 조이스틱+스킬 탭/홀드 | ✅ PASS |
| Phase 1 | `phase1_arena` | 맵+충돌+몬스터AI+전투공식, **attacks 27 / hits 26 / life 94-157** | ✅ PASS |
| Phase 2 | `phase2_skills` | 캐릭터(AR/Def/Life/Mana 산출)+스킬(Bash/Berserk/BO/Mastery)+레벨링, **Lv3/kills3/BO: life 157→217/mastery3** | ✅ PASS |
| Phase 3 | `phase3_items` | 아이템/접사/드롭/인벤토리/장착, **kills5/drops2/picked2, 방어구 장착 def 21→47** | ✅ PASS |

> **🏁 수직 슬라이스(Phase 0~3) 완성** — 로드맵의 "게임이 돈다"(이동→전투→드롭→장착) 지점 도달.

| Phase 4 | `phase4_craft` | 소켓/보석/룬워드/큐브, **Ruby+38life · Steel(Tir+El) · 순서검증 · El×3→Eld** | ✅ PASS |
| Phase 5 | `phase5_boss` | 몬스터 AI(근접/원거리/보스)+안다리엘 3패턴, **melee9/nova3/spray1** | ✅ PASS |
| Phase 6 | `phase6_sorc` | 추가 클래스(소서리스)+투사체 스펠(behavior 추상화), **kills4/spells6/hits5** | ✅ PASS |
| Phase 7 | `phase7_online` | 온라인(계정/위치동기화/에스크로 거래), 서버+클라 2프로세스 **server+client PASS** | ✅ PASS |

> **✅ 설계된 전체 Phase(0~7) 실기 검증 완료** — 로드맵 P0~P13 시스템이 저사양 실기(HD4000)에서 전부 동작 확인됨.

| 통합 | `integrated` | 클래스선택+맵+몬스터+보스+드롭+인벤+크래프트, **barb PASS / sorc 보스처치 PASS** | ✅ PASS |

> **🎮 통합 심화:** 단계별 프로토타입 → 단일 플레이 프로젝트로 병합(공용 모듈 1벌, 바바리안·소서리스 클래스 선택). 정식화 백로그는 [검증 상태 종합 §3](../docs/superpowers/specs/2026-09-20-prototype-verification-status.md).

| 데이터구동 | `data_driven` | 몬스터/아이템/접사 JSON 로드, **monsters=6 로드 PASS, JSON몹 전투 PASS** | ✅ PASS |

> **🗃️ 데이터 파이프라인 심화:** 콘텐츠를 코드→JSON 분리. 몬스터 추가 = JSON 편집. 정식화 시 원본 txt→JSON 임포트로 대량 콘텐츠 수용.

| 랜덤던전 | `level_gen` | 프리셋룸+스패닝트리 연결+A* 경로, **3시드 완전연결 PASS, 45×45 렌더 OK** | ✅ PASS |

> **🗺️ 랜덤 던전 심화(D2 인스턴트 맵):** 시드 기반 매번 다른 완전연결 던전, 입구→출구 A* 경로 검증. 정식화 시 고정 아레나 → 이 생성기로 교체.

| 게임던전 | `game_dungeon` | 랜덤던전+A*내비+전투+드롭+출구워프, **sorc 레벨1→2 / barb 레벨1·2클리어→3(보스)** | ✅ PASS |

> **🏰 캡스톤:** 전 시스템 통합 던전 크롤러. 생성→내비→전투→드롭/크래프트→출구워프→다음레벨. 두 클래스 다층 클리어 실기 검증(HD4000).

| UI심화 | `ui_polish` | 인벤 그리드+장비슬롯+드래그&드롭+캐릭터화면(스탯/스킬 배분)+툴팁, **UI셀프테스트 PASS** | ✅ PASS |

> **🖥️ UI 심화(P9):** D2식 인벤토리 그리드(드래그&드롭 장착), 장비 슬롯, 캐릭터 화면(포인트 배분), 툴팁. inv_cell/equip_slot 독립 유닛.

| 전투심화 | `combat_deep` | 저항/면역/약점·블록·흡혈·크러싱블로우·캡, **공식 셀프테스트 PASS + 게임연동** | ✅ PASS |

> **⚔️ 전투 심화(B):** Part 5/6 메커니즘 구현·검증. 파이어볼 화염저항(안다리엘 -50% 약점), 바바리안 블록/흡혈/크러싱블로우.

| 세이브 | `save_system` | 캐릭터/인벤/장비/진행 JSON 저장·로드, **라운드트립 PASS** | ✅ PASS |

> **💾 세이브 심화(P10):** JSON 직렬화 저장/로드 라운드트립. **이로써 로드맵 P0~P13 전 시스템 프로토타입·실기검증 완료.**

| 자산제작기 | `asset_gen` | JSON→atlas+12애니 게시/소비, 플레이어·용병 실측 4방향 전환·폴백·품질게이트 PASS | ✅ PASS |
| 미적용연구 | `research_applied` | FCR/FHR 브레이크포인트 + 난이도(NM/Hell) 스케일링, Normal 클리어/Hell 사망 | ✅ PASS |

> **⚙️ 미적용 연구 적용:** 브레이크포인트(FCR 프레임→시전속도)·난이도 스케일링(몹 HP/저항·플레이어 저항페널티·Hell 물리바닥). 비교분석의 `❌미적용` → `적용`.

## 🕹️ game_dungeon D2 콘텐츠 심화 (정본 · 전부 라이브 배포)

정본 `game_dungeon`에 D2 핵심 시스템을 순차 추가·실기검증(HD4000, 헤드리스 autoquit `verdict=PASS`)·배포(https://jflakeee.github.io/diablo/). 2026-09-21 기준:

| 시스템 | 파일/마커 | 실측 |
|--------|-----------|------|
| 4속성 저항/상성 + 무기 속성뎀 | `combat.apply_resistance`, `_target_resist`, fdmg/cdmg/ldmg | 약점/면역/슬로우 동작 |
| 절차 사운드 | `sfx_gen.gd`(코드 PCM) | 6/6 생성, attack 4410B |
| 유니크 아이템 | `item.UNIQUES`(6종) | The Gnasher 등 금색 고정스탯 |
| 챔피언/유니크 몬스터 팩 | `_apply_rank`, `UNIQ_MODS`(6) | champs/uniques 스폰·인챈트 |
| 포션 & 벨트 | `_belt_hp/_mp`, `_quaff_*` | barb 자동포션 3회 생존 |
| 용병(Rogue Scout) | `_spawn_merc`, `_merc_fire` | 화염화살 아군 3킬·HP스케일 |
| 골드/상인/도박 | `_gold`, `_vendor_*`, `_gamble` | gold 1475·판매·도박2회 |
| 스탯/스킬 육성 | `_stat_points`, `_spend_*` | 힘42/활력43·화염구9 |
| 자동 지도(미니맵) | `minimap.gd`(텍스처1회+동적점) | tex 생성·grid 전달 |
| 액트/보스/퀘스트 | `_is_boss_level`, `_complete_act`(ACT_LEN=3) | 보스층 출구잠금·보상 [ACTTEST] PASS |
| 파밍 자동화 | `automation.gd`(품질필터/스택/포션교체/자동장착/경매·분해) | 결정론 셀프테스트 `[AUTO] PASS` + 런타임 PASS |

> **🎯 D2 핵심 8축 라이브:** 전투·파밍·생존·동료·경제·성장·탐색·진행 구조가 하나의 순환으로 맞물림. 저사양 최적화(미니맵 텍스처 블릿, 25Hz 논리틱)로 HD4000 유지.

> **🧹 배포 통합(2026-09-21):** 뒤처진 병렬 빌드 `/integrated/`를 gh-pages에서 삭제. **루트(`/diablo/`)가 유일 정본**.

## 핵심 검증 결론
- HD 4000에서 Godot이 자동 ANGLE(→D3D11) 전환 → **OpenGL 3.3 불완전 우려 무력화**. Godot 3.6 폴백 불필요.
- 렌더 헤드룸 충분(원작 규모 근사 826개서 116fps 최저).
- 원작 프레임 모델(25Hz 논리틱) 정확 동작 → 브레이크포인트 재현 기반 확보.
- 딥리서치 전투 공식(명중률·물리데미지·바바리안 Life)이 실제 게임 루프에서 작동.

## GDScript 함정 로그 (재발 방지 · 경고=에러 프로젝트)
- Dictionary 값은 `d["key"]` (점 접근 불가)
- `abs()`는 Variant 반환 → `absf()`/`absi()`
- `dict.get(k, default)`는 Variant 반환 → `var x: int = int(table.get(...))` 명시 타입
- 배열 리터럴 인덱싱 `["a","b"][i]`도 추론 실패 → 명시 타입
- 신규 프로젝트에서 `class_name` 전역 등록 불안정 → **`preload()` 상수 + 타입 힌트로 사용**
- 동적 멤버(Node/Variant) 산술은 `:=` 추론 실패 → **명시 타입** 또는 스크립트 타입(`ActorScript`)으로 선언
- 미사용 지역변수도 경고→에러 (셀프테스트 print에 임시 var 남기지 말 것)

## 다음 후보 (미착수 D2 시스템)
- 커스/오라(면역 돌파 — Lower Resist/Conviction)
- 스킬 시너지 + 스킬 트리 확장
- 호라드릭 큐브 제작 UI 노출(`craft.gd`는 구현됨, 미노출)
- 웨이포인트(빠른 이동) · 아이템 감정(미감정 레어)
- `monstats.txt` 임포트 → 대량 몬스터 콘텐츠
