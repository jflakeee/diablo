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

저장은 모바일 설정 패널의 `게임 저장`/`불러오기` 또는 키보드 F5/F9로 사용한다. `save_store.gd`가 `user://ashen_depths_save.json`을 임시 파일 검증 후 원자 교체하며, 스키마 마이그레이션과 손상 파일 거부를 담당한다.

온라인 권위 계층은 `online_authority.gd`에 분리되어 세션 재접속, 위치 시퀀스와 이동 한도, 소유권·잔액 기반 멱등 에스크로를 검증한다. 자동 검사는 유실된 시퀀스·중복 패킷과 100계정 거래 보존성을 포함한다. 실제 ENet 검사는 서버와 두 클라이언트를 별도 프로세스로 실행하여 서로의 월드 스냅샷 수신까지 확인한다.

`data/coverage.json`은 클래스·스킬·몬스터·아이템·제작·진행의 최소 역할 구성을 선언한다. `coverage.gd`가 시작 시 실제 데이터와 대조하므로 콘텐츠 제거 또는 역할 누락은 최종 PASS를 차단한다.

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
