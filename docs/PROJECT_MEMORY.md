# 프로젝트 메모리

최종 갱신: 2026-10-01 (몬스터 pack 군집 배치 배포)

## 맵 생성 상태

- 실제 플레이는 `WorldStream` 기반 단일 활성 청크 구조를 사용한다.
- 각 재생성 청크는 시드 기반으로 시작점과 목표점을 독립 랜덤 지정한다.
- 시작점과 목표점은 중복되지 않는다.
- 생성 모드는 직선형, 랜덤형, 장애물 랜덤형을 순환한다.
- 장애물 배치 후 시작점에서 목표점까지 타일 경로를 검사한다.
- 경로가 끊기면 장애물을 제거하며, 모든 방 중심이 이동 가능한지 검증한다.
- 저장/복원 시 청크별 시작점·목표점과 생성 모드를 유지한다.

## 검증 결과

- `MAP_VARIANTS`: PASS
- `STREAM`: PASS
- `SYSTEM`: 108 checks PASS (큐브·감정·저항 효과 회귀 포함, 실행 횟수 자동 집계)
- `SAVE`: 22 checks PASS
- Web 릴리스 검사: PASS
- 원격 PCK 해시 일치 확인: PASS

## 배포 정보

- 플레이 URL: https://jflakeee.github.io/diablo/
- 배포 표시 시각: `2026-10-01 22:53 KST`
- 소스 커밋: 몬스터 pack 군집 배치(본 커밋)
- 최신 배포 커밋: `7082c49` (gh-pages)
- Pages 빌드 상태: `built` (`gh api repos/jflakeee/diablo/pages/builds/latest`), 루트 HTTP 200 확인
- 원격 기본 URL의 PCK SHA-256: `b69ec2e5436e283933be2128532354fc252707a96814b728da1e55f90211cb2f`
- 원격 PCK 1,244,572 bytes 및 로컬 빌드 해시 일치 확인.

## 다음 점검 항목

- 모바일·PC 브라우저에서 재생성 직후 입구와 목표 마커의 시각적 분리 확인
- 장애물 랜덤형 맵에서 시작점→목표점 실제 이동 확인
- 강제 업데이트 후 캐시가 새 PCK를 수신하는지 확인

## 2026-10-01 미착수 작업 진행 (원격 배포 완료)

- 가방 → `Crafting Cube`: 재료 수량/결과 표시, 동일 보석·각인 3개 → 다음 등급 1개.
- 몬스터 재료 드롭에 Ahn/Vey 각인 추가. 기존 보석 ID와 재료 저장소 호환 유지.
- 재료 부족·최고 등급·잘못된 ID·중복 입력 시 재료 소모 방지.
- 양 클래스 `autoquit strict_assets`: PASS. 최신 `SYSTEM` 108개, `SAVE` 22개 PASS.
- `tools/cube_ui_test.gd`: 실제 버튼/중복 입력, 부족/빈 상태, 320/640px 및 큰 글씨 레이아웃 PASS.
- Web release 검사 PASS. 큐브·감정·저주/오라 변경을 위의 배포 커밋으로 원격 반영했다.
- 맵 생성 자동 검사 PASS. Orca 브라우저 snapshot/screenshot은 `runtime_unavailable`
  (런타임이 응답 전에 연결 종료)로 실패하여 브라우저 시각/캐시/직접 이동 점검은 완료 처리하지 않았다.
- 레어 몬스터 드롭의 미감정 상태, 가방 무료 감정, 감정 전 장착/판매/경매 보호 구현.
  기존 장비는 감정 완료로 취급하며 감정 시 옵션을 다시 생성하지 않는다.
- Storm Lance에 6초 원소 저항 감소 저주, Iron Chant에 6타일·시야 제한 오라 연결.
  원래 면역인 적은 합산 저항 감소량의 1/5만 적용하고 100 미만일 때 면역 해제.
  적의 75~99 저항도 실제 피해에 반영하도록 적 피해 계산 상한을 99로 조정했다.
- 저주 막대/오라 고리, 스킬 설명 및 현재 층 저주·Iron Chant 잔여시간 저장/복원 연결.
- `tools/progression_combat_test.gd`: 실제 감정 버튼·중복 입력·장착/판매 제한,
  실제 시전·면역·거리·벽·마나·시전자 사망·저주 만료·스냅샷 검사 PASS.
- 후속: 콘텐츠 확장 범위/수량 정의, Android 실기기와 온라인 WAN/장시간 검증.

## 2026-10-01 몬스터 pack 군집 배치 (원격 배포 완료)

- 설계 문서: `docs/superpowers/specs/2026-10-01-monster-pack-placement-design.md`.
- `_spawn_dungeon_monsters()`를 몬스터 1마리 단위 랜덤 루프에서 pack 단위 루프로 교체.
  pack은 같은 몬스터 타입 2~4마리, anchor 주변 반경 3타일 내 바닥 타일에 모여 배치되고
  실패 시 기존 전역 랜덤 바닥칸으로 폴백한다.
- 챔피언/유니크 등급 롤을 pack당 1회로 변경(확률은 기존과 동일: 오토퀴트 첫 pack 강제
  유니크, 그 외 5%/10%). 롤 성공 시 pack 전체가 같은 등급과 동일한 `UNIQ_MODS` 모디파이어를 공유.
  `_spawn_one`/`_apply_rank`에 `forced_rank`/`forced_mod`/`pack_id` 인자 추가.
- 신규 `_pack_selftest()`: `pack_id` 메타로 몬스터를 그룹화해 군집 거리와 등급/모디파이어
  일치를 검증, `[PACK] packs=N min_size=.. max_size=.. verdict=..` 출력을 최종 `ok` 집계에 포함.
- 양 클래스 `autoquit` 실행: `[PACK] packs=5 min_size=2 max_size=3 verdict=PASS`(barb),
  `[PACK] packs=4 min_size=2 max_size=4 verdict=PASS`(sorc), 전체 `[GD][RESULT] verdict=PASS`.
- 보스 스폰과 저장 스키마는 변경하지 않음(런타임 스폰 로직만 변경).
- Web release export → gh-pages 배포 커밋 `7082c49`, Pages 빌드 `built`, 루트 HTTP 200,
  로컬/원격 PCK SHA-256 일치 확인.
