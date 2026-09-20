# 무료 디자인/스프라이트 자산 딥리서치 (ARPG용)

- 작성일: 2026-09-21
- 목적: 최대 갭인 **오리지널 자산**(스프라이트·타일·아이콘·UI·사운드)을 **무료·라이선스 명확** 소스로 대체
- 대상: 아이소메트릭 또는 2.5D 탑다운 ARPG(디아블로류), Godot + 스프라이트 아틀라스/타일맵
- 원칙: **원본 D2 에셋 사용 금지**(저작권). 아래는 전부 **오리지널 무료** 자산.

---

## 0. 라이선스 먼저 (상업 배포 기준)

| 라이선스 | 크레딧 | 상업 이용 | 주의 |
|----------|--------|-----------|------|
| **CC0 / Public Domain** | 불필요 | ✅ 자유 | **최우선 선택** |
| **CC-BY (3.0/4.0)** | 필요(제작자 표기) | ✅ | 크레딧 목록 관리 |
| **CC-BY-SA / GPL** | 필요 + **동일 라이선스 전파** | ✅ | 파생물도 SA/GPL → 상업 클로즈드에 부담 |
| **CC-BY-NC** | 필요 | ❌ **판매 불가** | 유료 게임 제외 |
| **커스텀(예: CraftPix)** | 대개 불필요 | ✅ | **원본 파일 재판매 금지** 등 조항 확인 |

> **권장:** 유료/스토어 배포를 염두에 두면 **CC0 우선**, 필요 시 CC-BY(크레딧 관리). SA/GPL·NC는 신중.

출처: [OGA CC0 resources](https://opengameart.org/content/cc0-resources), [CC0 게임음악 정리](https://gtstu.com/free-royalty-free-music-indie-games/)

---

## 1. 그래픽 — 아이소메트릭(디아블로류 최근접)

| 소스 | 내용 | 라이선스 | 비고 |
|------|------|----------|------|
| **Reiner's Tilesets** | **아이소 캐릭터·몬스터**(정지/걷기/공격/피격 애니), 타일 ~250+ | 무료(상업 시 크레딧: *Reiner "Tiles" Prokein*) | **디아블로류 프리렌더 아이소의 대표**, 색/크기/포맷 수정 허용 |
| **Kenney Isometric Assets** | 아이소 타일 수백 종 | **CC0** | 상업 자유, 무크레딧 |
| **OGA — Wyrmsun (CC0)** | 900+ 아이템 + Human/Orc/Skeleton 캐릭터 400+ + 아이소 마을타일 400+ | **CC0** | 대량 CC0 |
| **OGA — Isometric Tiles/RPG 태그** | 아이소 폐허·식물·던전 등 | 다양(CC0~) | 에셋별 확인 |
| **itch.io CC0 Isometric 태그** | 오브젝트 395·오버월드 360·벽 1872 타일 등 | **CC0** | |

출처: [Reiner 라이선스](https://www.reinerstilesets.de/graphics/lizenz/) · [Reiner 2D 몬스터](https://www.reinerstilesets.de/graphics/2d-grafiken/2d-monsters/) · [Kenney Isometric](https://kenney.itch.io/kenney-isometric-assets) · [OGA isometric-rpg](https://opengameart.org/content/isometric-rpg) · [itch CC0 isometric](https://itch.io/game-assets/assets-cc0/tag-isometric)

---

## 2. 그래픽 — 2.5D 탑다운/픽셀 던전(대안 스타일)

우리 프로토타입은 아이소 렌더지만 **탑다운 픽셀**로 방향 전환 시 더 풍부한 무료 자산 활용 가능.

| 소스 | 내용 | 라이선스 |
|------|------|----------|
| **0x72 — DungeonTileset II** | 16x16 던전 타일 + **애니 캐릭터 + 무기** | **CC0** |
| **Kenney — Roguelike/RPG pack, RPG Base, RPG Urban** | 탑다운 RPG 타일·캐릭터 | **CC0** |
| **LPC (Liberated Pixel Cup)** + **Universal LPC Spritesheet Generator** | 커스터마이즈 캐릭터 스프라이트(걷기/공격/시전) | **CC-BY-SA 3.0 / GPL 3.0** | 기여자 전원 크레딧·SA 전파 주의 |
| **CraftPix 무료 섹션** | 2D 판타지/RPG 캐릭터·타일·GUI·배경 | 커스텀(상업 OK, 재판매 금지) |

출처: [0x72 DungeonTileset II](https://0x72.itch.io/dungeontileset-ii) · [Kenney Roguelike/RPG](https://kenney.nl/assets/roguelike-rpg-pack) · [LPC 생성기](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/) · [LPC 저장소/라이선스](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) · [CraftPix 무료](https://craftpix.net/freebies/)

---

## 3. UI (모바일 HUD·인벤·버튼)

| 소스 | 내용 | 라이선스 |
|------|------|----------|
| **Kenney — UI Pack** (430) / **UI Pack RPG Expansion** (85) / **UI Pack Adventure** / **Pixel UI Pack** | 버튼·패널·아이콘·프레임 | **CC0** |

우리 게임의 조이스틱·스킬버튼·인벤 그리드·패널을 이걸로 교체하면 즉시 룩 향상.

출처: [Kenney UI Pack](https://kenney.nl/assets/ui-pack) · [UI Pack RPG Expansion](https://kenney.nl/assets/ui-pack-rpg-expansion) · [Pixel UI Pack](https://kenney.nl/assets/pixel-ui-pack)

---

## 4. 아이콘 (스킬·아이템·룬·보석)

| 소스 | 내용 | 라이선스 |
|------|------|----------|
| **game-icons.net** | **4180+ SVG/PNG** 판타지 아이콘(스킬/무기/물약/룬 등), 흑/백/투명 | **CC-BY 3.0** (제작자 크레딧) |
| **Shikashi's Fantasy Icons Pack** | 판타지 아이템 아이콘 | 무료(itch) |
| **OGA — Basic RPG Item Icons / Skill·item·spell icons** | 아이템·스킬 아이콘 | 다양 |

→ 스킬트리·인벤 아이템·룬워드 아이콘에 최적(우리 스킬버튼 라벨을 아이콘으로 교체).

출처: [game-icons.net](https://game-icons.net/) · [about/license](https://game-icons.net/about.html) · [Shikashi Icons](https://shikashipx.itch.io/shikashis-fantasy-icons-pack) · [OGA RPG item icons](https://opengameart.org/content/basic-rpg-item-icons-free)

---

## 5. 사운드 & 음악

| 소스 | 내용 | 라이선스 |
|------|------|----------|
| **Kenney Audio** (Interface·Impact·**RPG Audio**·Music Jingles 등 10팩) | UI클릭·타격·RPG SFX | **CC0** |
| **Freesound** | ~381,000 CC0 사운드(필터: Creative Commons 0) | **CC0**(필터 시) / 그 외 CC-BY 등 |
| **OGA — CC0 Fantasy Music & Sounds / 50 RPG SFX / Fantasy SFX Library** | 판타지 BGM·SFX | CC0(필터) / 다양 |

출처: [Kenney Audio](https://kenney.nl/assets/tag:audio) · [Freesound](https://freesound.org/) · [OGA CC0 Fantasy Music](https://opengameart.org/content/cc0-fantasy-music-sounds) · [50 RPG SFX](https://opengameart.org/content/50-rpg-sound-effects)

---

## 6. 폰트 (한글 포함)

- **Google Fonts** (OFL, 상업 자유): 본문/UI. 한글은 **Noto Sans KR**, 픽셀/판타지 느낌은 영문 픽셀 폰트(OGA/dafont의 무료 상업 허용본).
- 픽셀 UI엔 Kenney 폰트(CC0)도 포함.

---

## 7. 우리 프로젝트 매핑 & 권장 스택

현재 상태: 전부 색 도형 플레이스홀더. 아래로 교체 시 "다르게 구현(스프라이트/사운드/디자인)" 갭 해소.

| 필요 | 1순위(무크레딧 CC0) | 대안 |
|------|--------------------|------|
| 던전 타일 | Kenney Isometric / 0x72(CC0) | OGA Wyrmsun |
| 캐릭터(바바·소서) | Reiner(크레딧) / 0x72(CC0) | LPC 생성기(SA 주의) |
| 몬스터·보스 | Reiner 2D 몬스터(크레딧) | OGA Wyrmsun(CC0) |
| 아이템/스킬/룬 아이콘 | game-icons.net(CC-BY) | Shikashi(무료) |
| 모바일 UI | Kenney UI Pack(CC0) | Pixel UI Pack |
| SFX·BGM | Kenney Audio(CC0)·Freesound CC0 | OGA CC0 |

### 스타일 결정 포인트
- **진짜 아이소(프리렌더)** → **Reiner's Tilesets**가 디아블로 느낌 최고(단 크레딧 + 룩 통일 필요).
- **관리 편의·무크레딧** → **CC0 조합**(Kenney 아이소/UI/오디오 + 0x72 캐릭터 + game-icons 아이콘). ← **추천**(라이선스 단순).

### 실무 주의
1. **팩 단위 라이선스 재확인** — 같은 사이트도 에셋마다 다를 수 있음(특히 OGA, itch).
2. **CC-BY/SA/GPL 크레딧·전파** 관리 — 상업 클로즈드면 CC0 위주 권장.
3. **원본 D2/상표(클래스·아이템 고유명)** 회피 — 자산도 명칭도 오리지널로.
4. Godot 적용: 스프라이트 → **TextureAtlas/스프라이트시트**, 타일 → **TileSet 리소스**, 아이콘 → UI 테마.

---

## 8. 다음 단계 제안
- 스타일 확정(CC0 픽셀 조합 vs Reiner 아이소) → 소량 다운로드로 **P0 프로토타입에 실제 타일/캐릭터 1세트 적용** → 룩앤필 검증.
- 크레딧 파일(`CREDITS.md`) 마련(CC-BY 사용 시).
