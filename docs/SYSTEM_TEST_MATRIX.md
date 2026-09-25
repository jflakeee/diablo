# Ashen Depths 시스템 테스트 명세

기준일: 2026-09-23
실행 프로젝트: `prototype/game_dungeon`

## 실행 방법과 합격 조건

```powershell
godot_console --headless --path prototype/game_dungeon res://tools/asset_compiler.tscn -- autoquit verify publish
godot_console --verbose --headless --path prototype/game_dungeon -- autoquit strict_assets barb
godot_console --verbose --headless --path prototype/game_dungeon -- autoquit strict_assets sorc
```

## Jewelry regression coverage

The item regression suite covers the `ring` and `amulet` slots, authored unique
identity and fixed affixes, indestructible durability behavior, and zero repair
cost. Content coverage requires all four equipment slots and nine base items.
The current system suite reports 53 checks.

에셋 컴파일은 `[AG][RESULT] verdict=PASS`, 두 클래스 실행은 `[SYSTEM] ... verdict=PASS`와 최종 `[GD][RESULT] verdict=PASS`를 모두 출력해야 한다. `strict_assets`에서는 누락 목록이 비어 있고 `fallback_count=0`이어야 한다. 테스트 프로세스 종료 시 누수·고아 리소스 경고가 없어야 한다.

## 자동 검증 행렬

| 영역 | 요구 동작 | 자동 검증 근거 | 현재 판정 |
|---|---|---|---|
| 전투 명중 | 명중률 5~95% 제한 | `system_tests.gd`: 극단 AR/방어력 | PASS |
| 속성 저항 | 면역, 음수 저항, 상한 적용 | `system_tests.gd`: 100%/−50% 사례 | PASS |
| 전투 시간 | 25 fps 프레임 환산과 시전 구간 | `system_tests.gd`: 25프레임=1초, 13~7프레임 | PASS |
| 난이도 | 저항 페널티, Hell 물리 저항 바닥 | `system_tests.gd`: −100, 50 검증 | PASS |
| 캐릭터 | Iron Warden 생명/마나 공식 | `system_tests.gd`: Vit 25/Lv 1 | PASS |
| 스킬 | 독자 스킬 ID, 비용, 요구 레벨·선행 스킬·20레벨 상한·6개 시너지, 투자 거부 | `[SYSTEM]` 트리/시너지 경계, 양 클래스 50초 실행 | PASS |
| 아이템 | 고유·세트 장비명, 고정 옵션, 품질 색, 2부위 세트 보너스, 파손 비활성화 | `system_tests.gd`: Rift Cleaver, Ember Oath | PASS |
| 제작 | 각인 순서, 역순 거부, 승급 | `system_tests.gd`, `[P4][RESULT]` | PASS |
| 던전 | 27×27, 9방/8문, 결정성, 연결성 | `system_tests.gd`: BFS 및 동일 시드 | PASS |
| 모바일 UI | safe area, 4:3~20:9, 터치 크기 | `[MOBILE_UI]` | PASS |
| 접근성 | UI 80~140%, 큰 글씨, 설정 영속화 | `[ACCESS]` | PASS |
| 에셋 | 28 정적, 24 애니메이션 품질·결정성 | 에셋 컴파일러 및 런타임 카탈로그 | PASS |
| 정체성 | 프로젝트명, 몬스터 12종, 금지명 | `[IDENTITY]` | PASS |
| 진행/보스 | 보스 처치 시 출구·보상·Act 진행 | `[ACTTEST]` | PASS |
| 퀘스트 캠페인 | 3개 액트·6개 독자 퀘스트, 선행 조건, 처치 역할, 보상, HUD, 저장 | `[SYSTEM]` 퀘스트 연쇄/복원, `[COVERAGE] quests=6`, `[QUEST]` 런타임 진행 | PASS |
| 웨이포인트 | 3개 액트·9개 지점, 층 진입 해금, 현재 액트 순환 이동, 잠금/타 액트 거부, 저장 | `[SYSTEM]` 이동 경계/복원, `[COVERAGE] waypoints=9`, `[WAYPOINT]` 런타임 해금 | PASS |
| 동료/경제 | Ember Scout 전투, 골드·판매·도박·장비 내구도·수리 | 양 클래스 자동 플레이, `[SYSTEM]` 파손/비활성/수리비/구형 저장 호환 검사 | PASS |
| 동료 장비 | 무기·방어구 장착, 전투 능력치 반영, 파손 제외, 저장·복원 | `[SYSTEM]` 동료 슬롯/스케일링 검사, `[SAVE] checks=13` | PASS |
| 달리기/스태미나 | 활력 기반 최대치, 방어구 중량별 소모, 고갈 시 보행, 정지 회복, HUD | `[SYSTEM]` 최대치·소모·중량·고갈·회복 검사 | PASS |
| 사망/시체 | 난이도별 경험치 손실, 소지 골드 손실, 체크포인트 부활, 시체 회수 반경·HUD | `[SYSTEM]` 손실 공식·시체 상태·회수 경계 검사 | PASS |
| 개인 보관함 | 48칸 용량, 가방 양방향 이동, 가득 참·중복 이동 거부, 모바일 버튼 | `[SYSTEM]` 입출고·용량·정규화 검사 | PASS |
| 저장 | 원자 교체, 왕복, v1→v8 이관, 퀘스트·웨이포인트·동료 장비·스태미나·시체·보관함 상태, 손상 거부·백업 복구·중단 격리 | `[SAVE] checks=13` | PASS |
| 온라인 권위 | 세션 재접속, 시퀀스/이동 검증, 멱등 에스크로, 100계정 보존성 | `[ONLINE] checks=8`, ENet 3프로세스 하네스 | PASS |
| 콘텐츠 커버리지 | 클래스·스킬 역할/속성·트리/시너지, 적 역할/저항, 고유·세트 장비·접사·제작·진행·퀘스트·웨이포인트 최소 구성 | `[COVERAGE] checks=28` | PASS |
| 런타임 예산 | 25Hz±5%, 활성 객체 128 이하, 50초 메모리 증가 64MiB 이하 | `[PERF]` 양 클래스 계측 | PASS |
| Web/PWA 배포 | release export, 독자 144/180/512 아이콘, manifest/service worker, 개발 도구 제외 | Web 산출물·PCK 내용 게이트 | PASS |

Web/PWA 행은 `prototype/game_dungeon/tools/release_check.ps1`로 재검증한다. 스크립트는 새 출력 디렉터리만 허용하고, 필수 산출물 8개, PCK 1.5 MiB 상한, 개발 도구·샘플·고해상도 원본의 패키지 제외, Godot 로그 기반 실패 감지를 모두 통과해야 `[RELEASE] verdict=PASS`를 출력한다.

Android 네이티브 export와 실기기 검증은 Web/PWA 판정에 포함하지 않는다. 필요한 외부 도구와 완료 조건은 `docs/ANDROID_EXPORT_REQUIREMENTS.md`를 따른다.

## 아직 독립 합격으로 볼 수 없는 범위

| 영역 | 현재 수준 | 완료 조건 |
|---|---|---|
| 전체 콘텐츠 규모 | 대표 수직 슬라이스 | 독자 Act·퀘스트·클래스·적·장비의 목표 수량 정의와 커버리지 빌드 검사 |
| 온라인 | 정식 권위 모델, 2클라이언트 월드 스냅샷, 유실·중복 회귀와 100계정 보존성 | 실서비스 전 실제 WAN 지연·장시간 soak·최대 동시 접속 인프라 검증 |
| 저장/마이그레이션 | 원자 저장·v1→v2 이관·손상 백업 복구·중단 임시파일 격리 | 장기 버전 간 호환성 실기기 검사 |
| 모바일 실기기 | 논리 레이아웃과 pause/focus-out/close 자동 저장 처리 | Android/iOS 저사양 기기 성능, 발열, OS 강제 종료·노치·회전 실기기 행렬 |
| 상업 배포 IP | 독자 명칭·자체 생성 에셋 정책 적용 | 출시 전 독립 법률 검토와 결과 기록 |

참조 게임은 메커니즘 비교 기준일 뿐 제품 정체성이나 콘텐츠 복제 기준이 아니다. 원본 파일·명칭·스토리·대사·외형·맵·음원·아이콘·수치표의 직접 복제는 완료 조건에서 제외한다.
