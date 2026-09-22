# 디자인 리소스: 직접 제작 vs 제작기(절차 생성) 검토 + PoC

자산 갭 해소 방안 검토. 결론: **절차적 생성기(제작기)를 기반**으로, 필요 시 CC0/수작업을 보강하는 하이브리드.

## 1. 세 가지 방안 비교

| 방안 | 장점 | 단점 | 우리 적합도 |
|------|------|------|------------|
| **A. 직접 수작업(픽셀아트/AI)** | 품질·개성 최고, 완전 제어 | 아트 스킬·시간 큼, 우리는 무아티스트·코드퍼스트 | ★★☆ |
| **B. 무료 자산 다운로드**([앞 리서치](../../docs/superpowers/research/2026-09-21-free-assets-research.md)) | 가장 빠름, 고품질 | 스타일 혼재, 라이선스/크레딧 관리, 개성 부족 | ★★★ |
| **C. 제작기(절차적 생성)** | **라이선스 청정(자체)**·무한 변형·초경량·저사양·코드퍼스트와 정합 | "프로그래머 아트" 한계(정교한 캐릭터는 어려움) | ★★★★ |

**추천: C를 기반 + B/A 보강(하이브리드).**
- 타일·아이콘·이펙트·팔레트 변주 → **제작기**(무한·청정·경량)
- 히어로 캐릭터/보스 등 정교한 것 → CC0(Kenney/0x72) 또는 수작업/AI로 소수 제작 후 **제작기로 리컬러·변형**

## 2. 제작기 PoC (`pixel_gen.gd`) — 실증

코드만으로 PNG 자산 생성. 동일 레시피는 텍스처 캐시에서 재사용한다. 실행:
```
godot --path . --rendering-driver opengl3            # 생성물 갤러리
godot --headless --path . --quit                     # 12종 생성 + PNG 저장 검증
```

### 생성기 구성
- `iso_tile(base,seed,speckle)` — 아이소 다이아 + **밝기 노이즈 지터 + 가장자리 림/상단 하이라이트 + 돌 얼룩** (grass/stone/dirt/hell)
- `hero(kind,robe,seed,direction,frame)` — 바바리안/소서리스/용병 전용 실루엣 + 4방향·걷기 프레임
- `monster_named(name,body,seed,frame)` — Fallen/해골/염소인간/매/안다리엘 계열별 실루엣 + 걷기 프레임
- `icon(kind,seed)` — sword/potion/shield/coin/gem/rune/material (도형 조합 + 외곽선)
- 공통: `_fill_ellipse`/`_fill_rect`/`_outline`/`_shade_right`, 해시 노이즈

### 자산 컴파일 출력
- `atlas.png` — 64px 셀에 정렬된 단일 텍스처 아틀라스
- `manifest.json` — 각 자산의 실제 region/cell, 생성기 버전, 아틀라스 MD5
- `heroes.tres` — 영웅 3종 × 4방향, 총 12개 `SpriteFrames` 걷기 애니메이션
- 독립 `asset_gen`과 정본 `game_dungeon` 생성기 소스 MD5 동기화 검증

### 자동 품질 게이트 (`quality.gd`)
- 불투명 픽셀 밀도, 팔레트 크기, 연결 요소 수, 이미지 경계 잘림 검사
- 클래스 실루엣·걷기 프레임·시드 변형 간 최소 픽셀 차이 검사
- 현재 14개 스프라이트 검사 및 세 변형 지표를 통과해야 최종 PASS

### 실측 (2026-09-21, HD 4000)
```
[AG] generated 18 assets, saved 18 PNG → user://assetgen
[AG] cache entries=18 reuse=true
[AG] atlas=true spriteframes=true source_sync=true
[AG][RESULT] verdict=PASS
```
샘플(`samples/`): 돌 타일=노이즈+음영, 포션=병+액체+반사광, 바바리안=후드 휴머노이드
→ **플랫 도형 대비 확연한 개선**, 라이선스 청정, 시드로 무한 변형.

## 3. 게임 적용 경로
- 생성기로 **TileSet용 타일 아틀라스** + **아이템/스킬 아이콘 시트** + **캐릭터 베이스**를 빌드 타임 생성 → Godot `TileSet`/`TextureAtlas`로 임포트.
- 팔레트/시드 파라미터로 몬스터 변종·희귀도별 아이템 색을 자동 생성(콘텐츠 볼륨 문제도 완화).

## 4. 다음 단계 제안
- 캐릭터 8/4방향 + 걷기/공격 프레임 절차 생성(간단 애니), 무기 오버레이(장착 아이템 반영)
- 룬/보석/접사 아이콘 세트 확장, 던전 벽/입구/워프 타일
- 정교함이 필요한 히어로는 CC0 베이스 + 제작기 리컬러 하이브리드
