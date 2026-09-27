# 완전 무료 템플릿 우선 적용 및 로컬 생성 전환 검토

- 작성일: 2026-09-27
- 대상: Ashen Depths 시각 재설계
- 결론: **CC0 템플릿으로 구조와 사용성을 먼저 완성한 뒤, 동일한 리소스 계약을 유지한 채 프로젝트 로컬 생성 자산으로 카테고리별 교체한다.**

---

## 1. 결정

1차 UI 구현에는 Kenney의 CC0 UI 리소스를 사용한다.

- UI Pack: 기본 버튼, 체크박스, 슬라이더, 패널의 임시 구현
- UI Pack RPG Expansion: RPG형 버튼·패널의 임시 구현
- Fantasy UI Borders: 패널 테두리와 9-slice 프레임의 임시 구현
- Tiny Dungeon 또는 Roguelike/RPG Pack: 갤러리·타일 교체 시험용 참조 자산
- Noto Sans CJK KR: 한글 본문과 누락 글리프 방지용 글꼴

최종 시각 정체성은 기존 `art/pixel_gen.gd`와 빌드 타임 자산 컴파일러를 확장해 로컬에서 결정론적으로 생성한다.

템플릿의 역할은 최종 미술이 아니라 다음을 빠르게 검증하는 것이다.

- UI 계층
- 버튼 크기
- 9-slice 동작
- 모바일/PC 반응형 배치
- 상태 표현
- 아이콘 슬롯 규격
- 입력 및 접근성

---

## 2. 라이선스 판정 기준

### 2.1 승인 등급

| 등급 | 조건 | 정책 |
|---|---|---|
| A | CC0 또는 자체 생성 | 즉시 사용 가능 |
| B | OFL 글꼴, MIT/Apache 도구 | 라이선스 파일과 고지 포함 후 사용 |
| C | CC-BY | 꼭 필요한 경우만, 정확한 저작자·원문 URL·변경 내역 기록 |
| D | CC-BY-SA, GPL 아트, 커스텀 무료 라이선스 | 기본적으로 사용하지 않음 |
| 금지 | NC, ND, 출처 불명, 팬 리핑, 상표·원작 에셋 재가공 | 사용 금지 |

“무료 다운로드”, “개인/상업 무료”라는 설명만으로 승인하지 않는다. 다운로드 시점의 라이선스 원문 또는 에셋 페이지 사본과 파일 해시를 보관한다.

### 2.2 CC0의 의미와 한계

CC0는 저작권과 관련 권리를 가능한 범위에서 포기해 상업적 복사·수정·배포를 허용하며 일반적으로 저작자 표시도 요구하지 않는다. 다만 상표권, 초상권, 제3자의 권리까지 자동으로 해결하지는 않는다.

따라서 다음은 CC0여도 사용하지 않는다.

- 다른 상용 게임의 로고·문양과 혼동되는 요소
- Diablo 고유 상표 또는 UI 장식을 모사한 요소
- 원출처가 의심되는 재업로드
- 실존 인물·브랜드를 포함한 이미지

---

## 3. 후보 리소스 평가

### 3.1 우선 승인: Kenney CC0

#### UI Pack

- 라이선스: CC0
- 파일 수: 430개
- 용도: 공통 버튼, 슬라이더, 토글, 패널 구조 검증
- 장점: 상태 종류가 많고 UI 프로토타이핑에 적합
- 단점: Ashen Depths의 어두운 고딕 분위기와는 거리가 있음
- 적용: 색상·크기를 조정한 임시 Theme 리소스로만 사용

#### UI Pack RPG Expansion

- 라이선스: CC0
- 파일 수: 85개
- 용도: 인벤토리·상점·캐릭터 패널의 RPG형 임시 표현
- 장점: 일반 UI Pack보다 게임 문맥이 잘 맞음
- 단점: 최종 고유성이 부족함
- 적용: 슬롯 크기와 패널 계층 검증

#### Fantasy UI Borders

- 라이선스: CC0
- 파일 수: 140개
- 용도: ModalShell, 카드, 아이템 상세의 9-slice 테두리
- 장점: 프레임 변형 수가 많음
- 단점: 그대로 사용하면 밝고 캐주얼할 수 있음
- 적용: 흑갈색·잿빛·금색 팔레트로 임시 변환

#### Tiny Dungeon / Roguelike-RPG Pack

- 라이선스: CC0
- 용도: 타일·소품·아이콘 파이프라인의 임시 입력
- 장점: 작은 텍스처와 다수의 카테고리
- 단점: 현재 아이소메트릭 비율과 직접 호환되지 않음
- 적용: 인게임 최종 타일이 아니라 컴파일러·카탈로그 시험 데이터로 제한

### 3.2 조건부 승인: Noto Sans CJK KR

- 라이선스: SIL Open Font License 1.1
- 상업 프로젝트와 앱 번들에 사용 가능
- 글꼴 파일 단독 판매 금지 및 OFL 고지 보존 필요
- 용도: 한글 본문, UI 수치, 누락 글리프 방지
- 적용: Regular, Medium 또는 Bold의 필요한 굵기만 포함

글꼴은 CC0가 아니지만 한글 안정성을 위해 승인 등급 B 예외로 채택한다.

### 3.3 사이트 단위 승인 금지

#### OpenGameArt

작품마다 CC0, CC-BY, CC-BY-SA, GPL 등 조건이 다르다. 검색 결과가 무료여도 전체 사이트를 승인 목록으로 취급하지 않는다. 사용하려면 개별 에셋이 CC0인지 다시 확인해야 한다.

#### itch.io 무료 에셋

각 제작자의 커스텀 약관이 다르며 수정·재배포·상업 이용 조건도 달라질 수 있다. CC0가 명시된 개별 패키지가 아니면 1차 파이프라인에 포함하지 않는다.

#### AI 생성 공유 사이트

학습 데이터와 출력 권리의 출처 검증이 어렵다. 프로젝트 내 직접 생성 과정과 프롬프트·생성일을 기록한 자산만 사용한다.

---

## 4. 단계별 적용 전략

### Stage T0 — 계약 고정

템플릿 다운로드 전에 리소스 ID와 규격을 먼저 정한다.

```text
ui/button/primary/{normal,hover,pressed,disabled}
ui/button/secondary/{normal,hover,pressed,disabled}
ui/panel/modal
ui/panel/card
ui/frame/item/{normal,magic,rare,set,unique,skillbook}
ui/icon/menu/{character,bag,shop,settings,map}
ui/icon/status/{life,mana,poison,burn,freeze,stun}
ui/icon/action/{equip,store,protect,sell,gamble}
ui/skill/{class}/{skill_id}
```

코드는 파일명을 직접 참조하지 않고 리소스 ID만 조회한다.

### Stage T1 — CC0 템플릿 적용

- 원본 ZIP과 라이선스를 `third_party_sources` 보관 영역에 저장
- 실제 런타임에는 필요한 파일만 복사
- 9-slice margin, 최소 크기, 상태 매핑을 Theme로 구성
- 원본 색상은 프로젝트 임시 팔레트로 일괄 조정
- 고딕 장식을 추가하지 않고 구조 검증을 우선

이 단계의 목표는 “예쁘게 보이기”보다 모든 화면이 일관되게 동작하는 것이다.

### Stage T2 — UI 구조 완성

- 반응형 HUD
- ModalShell
- 스킬 상태
- 인벤토리 ActionBar
- 라벨 금지영역
- 접근성 배율
- 시각 회귀 테스트

템플릿 상태에서 기능과 레이아웃을 먼저 잠근다.

### Stage G1 — 로컬 UI 생성기

`pixel_gen.gd`에 UI 전용 생성기를 직접 늘리지 않고 `art/ui_gen.gd`를 분리한다.

```text
art/
├─ pixel_gen.gd       # 월드, 캐릭터, 몬스터
├─ ui_gen.gd          # 패널, 버튼, 슬롯, 아이콘 기초
├─ effect_gen.gd      # 타격, 원소, 해금 이펙트
├─ palettes.json
└─ ui_recipes.json
```

첫 생성 대상:

1. 패널 배경과 테두리
2. 버튼 5상태
3. 아이템 등급 프레임
4. 상태 아이콘
5. 메뉴 아이콘
6. 클래스 스킬 아이콘

### Stage G2 — 템플릿 교체

카테고리 단위로 교체한다.

```text
템플릿 버튼 → 로컬 생성 버튼 → 회귀 검사 → 템플릿 버튼 제거
템플릿 패널 → 로컬 생성 패널 → 회귀 검사 → 템플릿 패널 제거
템플릿 아이콘 → 로컬 생성 아이콘 → 회귀 검사 → 템플릿 아이콘 제거
```

한 번에 전체를 바꾸지 않는다. 리소스 ID 계약이 동일하므로 코드 변경 없이 카탈로그 매핑만 교체한다.

### Stage G3 — 최종 출처 감사

- 런타임 아틀라스의 모든 엔트리에 origin 기록
- 템플릿 잔존 파일 목록 생성
- 사용하지 않는 원본 제거
- 라이선스 고지 생성
- 최종 빌드에서 허용되지 않은 출처 실패 처리

---

## 5. 로컬 생성 방법

### 5.1 UI 레시피 예시

```json
{
  "id": "panel_modal_obsidian",
  "type": "nine_patch",
  "size": [96, 96],
  "border": 18,
  "palette": "ashen_obsidian",
  "layers": [
    {"shape": "fill", "color": "panel_base"},
    {"shape": "inner_bevel", "color": "panel_raised", "width": 3},
    {"shape": "crack", "seed": 271, "density": 0.08},
    {"shape": "corner_rune", "variant": "split_gate"},
    {"shape": "outer_line", "color": "accent_gold", "width": 1}
  ]
}
```

같은 레시피에서 `normal/hover/pressed/disabled/selected` 팔레트 변형을 생성한다.

### 5.2 아이콘 생성 규칙

- 64×64 정본, 16px·32px 축소 검사
- 실루엣이 전체 면적의 55–75%를 차지
- 외곽선 최소 2px
- 색상은 기본 3–5색, 발광 1색
- 같은 카테고리는 시점과 광원 방향 통일
- 글자와 숫자를 아이콘 이미지에 직접 굽지 않음

### 5.3 버튼 상태 생성

```text
normal   : 기준 명도, 금속 외곽선
hover    : 상단 림 +10%, 내부 문양 약한 발광
pressed  : 내용 2px 아래 이동, 내부 명도 -8%
disabled : 채도 -70%, 명도 -25%
selected : 이중 외곽선 + 클래스 강조색
```

### 5.4 결정론과 품질 검사

- 모든 노이즈는 명시적 seed 사용
- 동일 입력은 동일 해시 산출
- 투명 가장자리 bleed 검사
- 9-slice 모서리 변형 검사
- 16/32/48/64px 축소 갤러리 생성
- 명도 대비 검사
- 유사 실루엣 검사
- 누락 상태 검사

---

## 6. 디렉터리와 출처 기록

권장 구조:

```text
prototype/game_dungeon/
├─ third_party_sources/
│  ├─ kenney_ui_pack/
│  │  ├─ LICENSE.txt
│  │  ├─ SOURCE.json
│  │  └─ original.zip.sha256
│  └─ noto_sans_cjk_kr/
│     ├─ OFL.txt
│     └─ SOURCE.json
├─ art/
│  ├─ ui_gen.gd
│  ├─ ui_recipes.json
│  └─ palettes.json
├─ generated/
│  ├─ ui_atlas.png
│  └─ ui_manifest.json
└─ ui/
   └─ themes/
      ├─ template_theme.tres
      └─ ashen_theme.tres
```

`SOURCE.json` 필수 항목:

```json
{
  "name": "Kenney UI Pack RPG Expansion",
  "source_url": "https://kenney.nl/assets/ui-pack-rpg-expansion",
  "license": "CC0-1.0",
  "downloaded_at": "2026-09-27",
  "archive_sha256": "...",
  "modified": true,
  "usage": ["temporary UI prototype"]
}
```

---

## 7. 적용 범위 결정

### 즉시 템플릿 사용 가능

- 버튼 배경
- 패널 테두리
- 슬롯 배경
- 체크박스·슬라이더
- 스크롤바
- 탭 상태

### 처음부터 로컬 생성 권장

- 클래스 스킬 아이콘
- 희귀도 아이콘
- 캐릭터 선택 실루엣
- Ashen Depths 로고와 문양
- 몬스터·캐릭터·월드 타일
- 타격·마법 이펙트

게임 정체성을 결정하는 자산까지 범용 템플릿으로 채우면 화면은 정돈되어도 독자성이 사라진다.

---

## 8. 최종 평가

CC0 템플릿 우선 적용은 타당하다. 현재 프로젝트의 가장 큰 문제는 최종 아트 품질보다 레이아웃과 정보 구조이므로, 검증된 템플릿으로 UI 동작을 먼저 안정시키는 편이 효율적이다.

단, 다음 조건을 지켜야 한다.

- 템플릿 파일명에 코드가 종속되지 않게 한다.
- 템플릿과 최종 자산이 동일한 리소스 ID와 크기 계약을 사용한다.
- UI 구조 완성 전에는 템플릿의 세부 장식에 시간을 쓰지 않는다.
- 독자성을 결정하는 스킬·캐릭터·몬스터 자산은 로컬 생성한다.
- 최종 릴리스 전에 템플릿 잔존 여부와 라이선스 manifest를 자동 검사한다.

따라서 실행 순서는 다음으로 확정한다.

```text
CC0 템플릿 수집·기록
→ Theme/Atlas 어댑터
→ 반응형 UI 기능 완성
→ 로컬 UI 생성기
→ 카테고리별 무중단 교체
→ 출처·해시·시각 회귀 검증
```

---

## 9. 조사 출처

- Kenney UI Pack: https://kenney.nl/assets/ui-pack
- Kenney UI Pack RPG Expansion: https://kenney.nl/assets/ui-pack-rpg-expansion
- Kenney Fantasy UI Borders: https://kenney.nl/assets/fantasy-ui-borders
- Kenney Tiny Dungeon: https://kenney.nl/assets/tiny-dungeon
- Kenney Roguelike/RPG Pack: https://kenney.nl/assets/roguelike-rpg-pack
- Kenney license FAQ: https://kenney.nl/support
- Creative Commons CC0: https://creativecommons.org/publicdomain/zero/1.0/
- Noto font usage and licensing: https://github.com/notofonts/noto-docs/blob/main/docs/website/use.md
- OpenGameArt license FAQ: https://opengameart.org/node/5571
