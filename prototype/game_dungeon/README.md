# 게임 던전 (Game Dungeon) — 캡스톤: 랜덤 던전 크롤러

모든 시스템의 캡스톤 통합: **랜덤 던전 생성 + A* 내비게이션 + 전투 + 드롭/크래프트 +
출구 워프(다음 레벨)**. 저사양 실기에서 도는 D2형 던전 크롤러.

## 실행
```
godot --path . --rendering-driver opengl3 -- barb    # 바바리안
godot --path . --rendering-driver opengl3 -- sorc    # 소서리스
```
- 조이스틱 이동, 스킬 버튼, Bag. 붉은 타일(출구)에 도달하면 **다음 던전 레벨로 워프**.
- 3레벨부터 보스(안다리엘) 등장.

### 검증 (자동 플레이)
```
godot --path . --rendering-driver opengl3 -- autoquit barb
godot --path . --rendering-driver opengl3 -- autoquit sorc
```

## 통합된 전체 루프
1. `level_gen`으로 **랜덤 던전 생성**(레벨별 결정론 시드) + AStarGrid2D 구축
2. 플레이어 = 입구, 몬스터 = 랜덤 바닥칸(JSON 정의), 보스 = 3레벨+
3. **A* 내비게이션**: 플레이어(자동)·몬스터가 경로 따라 이동(400ms 캐시)
4. 전투(Part 1/5 공식), 드롭→줍기→장착(Part 3), 크래프트(Part 4)
5. **출구 도달 → `_next_level()`**: 던전 재생성 + 몬스터 재배치

## 실측 (2026-09-20, HD 4000, 결정론 시드)
```
arcanist: dungeon_level=2 levels_cleared=1 kills>0                verdict=PASS
warden:   dungeon_level=2 levels_cleared=1 kills>0                verdict=PASS
```

저장은 모바일 설정 패널의 `게임 저장`/`불러오기` 또는 키보드 F5/F9로 사용한다. 앱 pause, 포커스 상실, 종료 요청에서도 자동 저장한다. `save_store.gd`가 임시 파일 검증 후 원자 교체하며, 스키마 마이그레이션, 손상 시 직전 백업 복구, 중단된 임시파일 격리를 담당한다.

무기와 방어구는 물리 명중·피격 시 내구도가 감소한다. 0이 되면 베이스 피해·방어와 접사가 비활성화되며 상인 패널에서 장착 장비를 골드로 일괄 수리할 수 있다. 내구도 필드가 없는 이전 저장 아이템은 완전 수리 상태로 이관된다.

온라인 권위 계층은 `online_authority.gd`에 분리되어 세션 재접속, 위치 시퀀스와 이동 한도, 소유권·잔액 기반 멱등 에스크로를 검증한다. 자동 검사는 유실된 시퀀스·중복 패킷과 100계정 거래 보존성을 포함한다. 실제 ENet 검사는 서버와 두 클라이언트를 별도 프로세스로 실행하여 서로의 월드 스냅샷 수신까지 확인한다.

`data/coverage.json`은 클래스·스킬·몬스터·아이템·제작·진행의 최소 역할 구성을 선언한다. `coverage.gd`가 시작 시 실제 데이터와 대조하므로 콘텐츠 제거 또는 역할 누락은 최종 PASS를 차단한다.

`data/quests.json`은 3개 액트에 걸친 6개 독자 퀘스트와 선행 조건·처치 목표·보상을 정의한다. 진행은 HUD에 표시되고 보스 및 일반 처치 이벤트와 연결되며 저장 데이터 스키마 v3에 포함된다. 이전 v1/v2 저장은 빈 퀘스트 상태를 보완한 뒤 정의에 맞춰 정규화한다.

50초 엄격 실행은 `performance_budget.gd` 기준으로 실제 논리 틱을 25Hz±5%로 유지하고, 활성 게임 객체 128개 이하, 정적 메모리 증가 64MiB 이하인지 측정한다. 초과 시 최종 결과가 실패한다.

Web preset은 설치 가능한 PWA를 생성한다. 독자 앱 아이콘은 `assets/app_icon_source.png`에서 `tools/icon_builder.gd`로 144/180/512 크기를 만들며, release pack은 개발용 `tools`, 로그, UID, 고해상도 원본을 제외한다.

### Web/PWA 릴리스 검증

저장소 루트 또는 다른 경로에서 다음 스크립트를 실행하면 빈 임시 디렉터리에 release export를 만들고 필수 PWA 파일, 1.5 MiB PCK 예산, 개발 도구·샘플·원본 아이콘의 패키지 제외를 한 번에 검증한다. Godot 로그에 export 오류가 있으면 프로세스 종료 코드가 0이어도 실패한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File prototype/game_dungeon/tools/release_check.ps1
```

Android 네이티브 출시는 Web/PWA와 별도이며 필요한 SDK와 실기기 완료 기준은 `docs/ANDROID_EXPORT_REQUIREMENTS.md`에 기록한다.

```powershell
godot_console --headless --path . res://tools/network_harness.tscn -- net_server net_multi
godot_console --headless --path . res://tools/network_harness.tscn -- net_client net_multi
godot_console --headless --path . res://tools/network_harness.tscn -- net_client2 net_multi
```
→ 두 클래스 모두 **다층 던전 클리어→워프** 동작, 런타임 에러 0.

## 정식화
- 몬스터 A* 부하 최적화(관심영역), 던전 내 몬스터 밀도·묶음(pack) 배치
- 프리셋 청크 다양화, 특수룸/보스룸, 미니맵, 웨이포인트, 난이도 스케일링
- 세이브(현재 레벨/캐릭터), 저항·블록 전투 심화, 인벤 그리드 UI
