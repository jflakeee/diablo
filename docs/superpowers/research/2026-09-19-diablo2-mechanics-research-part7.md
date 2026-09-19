# 디아블로 2 메커니즘 딥리서치 — Part 7 (기술 구현 선행연구)

- 작성일: 2026-09-19
- 방향 전환: 게임 수치 → **실제 구현에 직결되는 엔지니어링 선행연구(prior art)**
- 다루는 항목: 오픈소스 D2 재구현 / Diablo Immortal 모바일 조작 / Phaser 아이소메트릭 / 원본 파일 포맷·툴
- 주 대상: **P0(엔진/렌더/입력)**, P1(맵), P9(모바일 UI), 자산 파이프라인

> **핵심 전제(저작권):** 아래 오픈소스 엔진들은 **모두 "합법 구매한 원본 D2 설치본의 에셋을 로드"** 하는 구조다. 우리 클론은 [로드맵 §9](../specs/2026-09-19-diablo2-clone-master-roadmap-design.md) 방침대로 **자체 오리지널 자산**을 쓰므로 MPQ를 직접 로드하지 않는다. → 이들에게서 배우는 것은 **데이터 구조·아키텍처·렌더링 기법**이지 에셋이 아니다.

---

## 1. 오픈소스 D2 재구현 비교 · P0

| 프로젝트 | 언어/스택 | 특징 | 우리에게 주는 교훈 |
|----------|-----------|------|-------------------|
| **Riiablo** | Java + **LibGDX** + OpenGL + Flatbuffers + Netty | **PC·안드로이드 구동**, 원본 에셋 100% 로드, 3종 네트워크 모드 | 모바일 D2 재구현의 최근접 사례 → 아키텍처 벤치마크 1순위 |
| **OpenDiablo2** | **Go** (Abyss Engine으로 진화) | 크로스플랫폼, 툴셋/코어 엔진 분리, MPQ 로더, 아이소 2D 구조(town/map/UI) | **모듈 분리**(데이터 추출 툴셋 ↔ 런타임 엔진) 설계 참고 |
| **freeablo** | C++ | 원조 Diablo 1 재구현 | 저수준 렌더/경로탐색 참고 |
| **DGEngine** | C++ (SFML) | 데이터 주도(JSON) 범용 ARPG 엔진 | **data-driven** 설계 철학 참고 |

출처: [OpenDiablo2 — GitHub](https://github.com/OpenDiablo2/OpenDiablo2), [Riiablo — GitHub](https://github.com/collinsmith/riiablo), [freeablo](https://github.com/andrewpage/freeablo), [DGEngine](https://github.com/dgengin/DGEngine)

### Riiablo 심층 (모바일 D2의 실증)
- 스택: **Java + LibGDX + OpenGL + Flatbuffers + Netty**.
- **플랫폼:** PC·안드로이드(향후 iOS/Linux). 다양한 종횡비(4:3~21:9) 지원.
- **모바일 UI 적응:** 원본 에셋은 480px 높이 기준이나, **모바일은 360px 높이로 낮춰 UI 요소 터치 선택을 쉽게** 함. → 우리 P9의 "칸 확대" 전략과 동일한 접근.
- **네트워크:** 전용 서버 / TCP-IP listen 서버 / 싱글플레이 3모드 → 우리 로드맵(싱글 우선→후반 온라인)과 정합.
- **에셋:** 원본 MPQ 로드(전용 MPQ Viewer 자체 제작). Windows 자동감지.
- **구현 현황:** "아직 플레이 불가, 그러나 세이브 로드·이동 가능" — 콘솔/CVAR·컨트롤러 지원. → **D2 완전 재현의 난이도**를 보여주는 현실 지표(로드맵 §6 리스크 뒷받침).

> **구현 함의:** Riiablo의 **네트워크 3모드 구조**와 **모바일 360px UI 스케일**을 그대로 참고. LibGDX(Java) 대신 우리는 Phaser(TS)지만 **아키텍처 패턴**(에셋 매니저, ECS적 엔티티, 화면 스택)은 이식 가능.

---

## 2. Diablo Immortal — 모바일 조작의 정석 · P9

공식 모바일 D2-계열 게임. 우리 모바일 UI(로드맵 §8)의 1차 벤치마크.

- **좌: 가상 조이스틱**(이동), **우: 기본공격 + 스킬 버튼**.
- **자동 조준**(가장 가까운 적) 기본 + **버튼 홀드 시 수동 조준**.
- 일부 스킬은 **홀드로 차징**(데미지·범위 증가) → D2 어쌔신 차징 스킬과 자연 매핑.
- **UI는 PC보다 크게**, 화면을 여러 요소가 덮음. **상황별 컨텍스트 프롬프트**를 잘 관리(상호작용 가능 시점을 항상 명확히 표시).
- **한계(반면교사):** 복잡한 콤보·자유조준은 터치로 어렵다 → **자동화(오토타겟/오토콤보) 보조가 필수**.

출처: [Diablo Immortal 조작 — Den of Geek](https://www.denofgeek.com/games/diablo-immortal-control-options-supported-controllers-mouse-keyboard/), [Diablo Immortal — Wikipedia](https://en.wikipedia.org/wiki/Diablo_Immortal), [설정 가이드 — game8](https://game8.co/games/Diablo-Immortal/archives/376937)

> **구현 함의(P9):** 조작 = 조이스틱 이동 + 스킬버튼(탭=자동조준 시전 / 홀드=수동조준·차징). 컨텍스트 상호작용은 "근접 시 자동 버튼 노출". 복잡 조작은 오토타겟으로 흡수. D2 원작의 마우스 정밀조준을 **터치+자동보조**로 치환하는 것이 핵심 설계.

---

## 3. Phaser 3 아이소메트릭 렌더링 · P0/P1

- **Phaser 3.50+ 는 아이소메트릭 타일맵을 네이티브 지원** → 구형 플러그인(30×30 초과 시 성능 문제) 대신 이걸 사용.
- **핵심 난제 = 좌표 변환.** 탑다운은 화면↔월드 직결이지만, 아이소는 **논리 그리드 ↔ 화면 좌표 간 수학 변환**이 필요. 이 변환만 이해하면 렌더·클릭·경로탐색·카메라가 자연히 따라옴.
- **깊이 정렬(depth sorting):** 아이소 특성상 Y(또는 그리드 합)에 따른 렌더 순서 정렬 필수(캐릭터가 벽 앞뒤로 올바르게 겹치도록).
- 모바일 성능: 타일 컬링·배칭·아틀라스로 대응(로드맵 §6 리스크).

출처: [Phaser 공식 아이소 예제](https://phaser.io/examples/v3/category/tilemap/isometric), [Isometric View in Phaser 3 — Medium](https://tnodes.medium.com/creating-an-isometric-view-in-phaser-3-fada95927835), [Depth sorting — Phaser Discourse](https://phaser.discourse.group/t/depth-sorting-with-tilemaps/8144), [Iso Map Example (TS) — Ourcade](https://examples.ourcade.co/phaser3-typescript/depth-sorting/isometric-map/)

> **구현 함의(P0):** 프로토타입의 첫 검증 대상 = (1) 그리드↔스크린 좌표 변환 유틸, (2) Y기반 깊이 정렬, (3) 타일맵 렌더 + 캐릭터 이동 클릭 매핑. Part 2 §1의 25 FPS 논리틱은 렌더(60fps)와 분리.

---

## 4. 원본 파일 포맷 & 툴 (참고용) · 자산 파이프라인

우리는 원본 에셋을 쓰지 않지만, **데이터 구조 이해**와 **레벨/애니메이션 설계 참고**를 위해:

| 포맷 | 용도 |
|------|------|
| **MPQ** | 블리자드 아카이브(d2char.mpq=캐릭터, d2data.mpq=몬스터/미사일/아이템/지형/UI) |
| **DC6 / DCC** | 스프라이트(2D 애니메이션 프레임). DCC는 압축 |
| **COF** | 애니메이션 조합 정의(레이어/방향/프레임) |
| **DT1 / DS1** | **DT1=타일**, **DS1=맵(타일 배치)** → 레벨 생성(P1) 참고 |
| **TXT** | 게임 데이터 테이블(monstats/weapons/skills…) → 구조 이식 대상 |

- 툴: **Dr.Tester**(뷰/추출), **D2 Workshop**(VSCode 확장: MPQ 브라우즈·txt 편집·DC6 뷰), **CascView**(D2R 데이터), **SAU/MPQ Editor**.

출처: [diablo-file-formats — GitHub](https://github.com/itsgoingd/diablo-file-formats), [Extracting D2 Animations — Paul Siramy](http://paul.siramy.free.fr/_divers2/Extracting%20Diablo%20II%20Animations.pdf), [D2 Workshop — VS Marketplace](https://marketplace.visualstudio.com/items?itemName=Xebyte.d2-workshop), [D2R Modding — diablo2.io](https://diablo2.io/forums/d2r-modding-tutorial-t704113.html)

> **구현 함의:** 우리 자산 파이프라인은 **자체 스프라이트 아틀라스(PNG) + Tiled 맵(TMX/JSON) + 게임데이터 JSON**. 단 **DS1/DT1의 "타일+오브젝트 레이어 분리"와 COF의 "방향×액션 애니메이션 조합" 개념은 그대로 차용**(캐릭터 8/16방향 애니메이션 설계에 유용).

---

## 5. 종합 — 기술 스택 재확인

이번 선행연구가 로드맵 §7 결정(Phaser 3 + TS)을 어떻게 보강하는가:

- **Riiablo**가 증명: D2 규모는 "실행은 되나 완성은 요원" → **수직 슬라이스 우선 전략(로드맵)이 옳음**.
- **모바일 UI 스케일 다운(360px)·자동 조준 보조**는 실증된 필수 패턴 → P9 스펙에 반영.
- **Phaser 3.50+ 네이티브 아이소**로 렌더 리스크 완화 → P0에서 좌표변환·깊이정렬만 검증하면 됨.
- **데이터 주도(DGEngine 철학)** + **툴셋/런타임 분리(OpenDiablo2)** → 우리도 게임데이터 JSON + 임포트 툴 분리 권장.

---

## 6. 리서치 전체 지도 (문서 8개)

| # | 문서 | 축 |
|---|------|----|
| — | 로드맵 | 분해·페이징·기술스택·모바일UI·리스크 |
| 1 | Part 1 | 데이터·개요 (명중·스탯·드롭·면역·커뮤니티) |
| 2 | Part 2 | 데이터 (브레이크포인트·스케일링·룬워드·레벨생성) |
| 3 | Part 3 | 데이터 (바바리안스킬·접사·큐브·액트1) |
| 4 | Part 4 | 데이터 (6클래스스킬·베이스·유니크) |
| 5 | Part 5 | 공식 (데미지·저항·블록·모디파이어·MF·경험치) |
| 6 | Part 6 | 공식 (달리기·보석·용병·도박) |
| 7 | **Part 7** | **기술 (재구현엔진·모바일조작·아이소렌더·파일포맷)** |

**딥리서치는 이제 게임 메커니즘·핵심 공식·구현 선행연구를 모두 포괄한다.** 남은 것은 (a) 전수 콘텐츠 데이터(구현 시 임포트), (b) 실제 프로토타이핑을 통한 검증뿐이다. → **다음 단계는 조사가 아니라 P0 착수.**
