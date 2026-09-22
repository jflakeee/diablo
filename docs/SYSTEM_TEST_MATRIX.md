# Ashen Depths 시스템 테스트 명세

기준일: 2026-09-23
실행 프로젝트: `prototype/game_dungeon`

## 실행 방법과 합격 조건

```powershell
godot_console --headless --path prototype/game_dungeon res://tools/asset_compiler.tscn -- autoquit verify publish
godot_console --verbose --headless --path prototype/game_dungeon -- autoquit strict_assets barb
godot_console --verbose --headless --path prototype/game_dungeon -- autoquit strict_assets sorc
```

에셋 컴파일은 `[AG][RESULT] verdict=PASS`, 두 클래스 실행은 `[SYSTEM] ... verdict=PASS`와 최종 `[GD][RESULT] verdict=PASS`를 모두 출력해야 한다. `strict_assets`에서는 누락 목록이 비어 있고 `fallback_count=0`이어야 한다. 테스트 프로세스 종료 시 누수·고아 리소스 경고가 없어야 한다.

## 자동 검증 행렬

| 영역 | 요구 동작 | 자동 검증 근거 | 현재 판정 |
|---|---|---|---|
| 전투 명중 | 명중률 5~95% 제한 | `system_tests.gd`: 극단 AR/방어력 | PASS |
| 속성 저항 | 면역, 음수 저항, 상한 적용 | `system_tests.gd`: 100%/−50% 사례 | PASS |
| 전투 시간 | 25 fps 프레임 환산과 시전 구간 | `system_tests.gd`: 25프레임=1초, 13~7프레임 | PASS |
| 난이도 | 저항 페널티, Hell 물리 저항 바닥 | `system_tests.gd`: −100, 50 검증 | PASS |
| 캐릭터 | Iron Warden 생명/마나 공식 | `system_tests.gd`: Vit 25/Lv 1 | PASS |
| 스킬 | 독자 스킬 ID, 비용, 레벨 스케일 | `system_tests.gd`, 양 클래스 50초 실행 | PASS |
| 아이템 | 고유 장비명, 고정 옵션, 품질 색 | `system_tests.gd`: Rift Cleaver | PASS |
| 제작 | 각인 순서, 역순 거부, 승급 | `system_tests.gd`, `[P4][RESULT]` | PASS |
| 던전 | 27×27, 9방/8문, 결정성, 연결성 | `system_tests.gd`: BFS 및 동일 시드 | PASS |
| 모바일 UI | safe area, 4:3~20:9, 터치 크기 | `[MOBILE_UI]` | PASS |
| 접근성 | UI 80~140%, 큰 글씨, 설정 영속화 | `[ACCESS]` | PASS |
| 에셋 | 28 정적, 24 애니메이션 품질·결정성 | 에셋 컴파일러 및 런타임 카탈로그 | PASS |
| 정체성 | 프로젝트명, 몬스터 12종, 금지명 | `[IDENTITY]` | PASS |
| 진행/보스 | 보스 처치 시 출구·보상·Act 진행 | `[ACTTEST]` | PASS |
| 동료/경제 | Ember Scout 전투, 골드·판매·도박 | 양 클래스 자동 플레이 결과 | PASS(스모크) |
| 저장 | 원자 교체, 왕복, v1→v2 이관, 손상 거부 | `[SAVE] checks=4` | PASS |
| 온라인 권위 | 세션 재접속, 시퀀스/이동 검증, 멱등 에스크로, 100계정 보존성 | `[ONLINE] checks=8`, ENet 3프로세스 하네스 | PASS |
| 콘텐츠 커버리지 | 클래스·스킬 역할/속성, 적 역할/저항, 장비·접사·제작·진행 최소 구성 | `[COVERAGE] checks=17` | PASS |

## 아직 독립 합격으로 볼 수 없는 범위

| 영역 | 현재 수준 | 완료 조건 |
|---|---|---|
| 전체 콘텐츠 규모 | 대표 수직 슬라이스 | 독자 Act·퀘스트·클래스·적·장비의 목표 수량 정의와 커버리지 빌드 검사 |
| 온라인 | 정식 권위 모델, 2클라이언트 월드 스냅샷, 유실·중복 회귀와 100계정 보존성 | 실서비스 전 실제 WAN 지연·장시간 soak·최대 동시 접속 인프라 검증 |
| 저장/마이그레이션 | 정식 프로젝트 원자 저장·v1→v2 마이그레이션·손상 거부 통합 | 장기 버전 간 호환성과 플랫폼 중단 복구 실기기 검사 |
| 모바일 실기기 | 논리 레이아웃 자동 검사 | Android/iOS 저사양 기기 성능, 발열, 중단/복귀, 노치·회전 실기기 행렬 |
| 상업 배포 IP | 독자 명칭·자체 생성 에셋 정책 적용 | 출시 전 독립 법률 검토와 결과 기록 |

참조 게임은 메커니즘 비교 기준일 뿐 제품 정체성이나 콘텐츠 복제 기준이 아니다. 원본 파일·명칭·스토리·대사·외형·맵·음원·아이콘·수치표의 직접 복제는 완료 조건에서 제외한다.
