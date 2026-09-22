# 디자인 생성기 설계 재검토 및 개선안

작성일: 2026-09-22  
대상: `prototype/asset_gen`, `prototype/game_dungeon` 자산 생성·게시·소비 파이프라인

## 1. 결론

현재 생성기는 초기 플레이스홀더 PoC를 넘어 다음을 갖춘 실제 자산 파이프라인으로 발전했다.

- JSON 기반 결정론적 자산 레시피
- 타일·영웅·몬스터·아이콘 절차 생성
- 클래스/몬스터별 실루엣과 영웅 4방향 걷기 프레임
- 정적 아틀라스, manifest, `SpriteFrames` 생성
- 게임 프로젝트 게시 및 런타임 소비
- 누락 자산의 런타임 절차 생성 폴백
- MD5 재현성 및 구조적 품질 게이트

그러나 기능을 순차적으로 확장하면서 **정적 아틀라스, 픽셀을 내장한 대형 `.tres`, 런타임 절차 생성**의 세 경로가 동시에 존재하게 됐다. 다음 개선의 우선순위는 새 자산 추가보다 파이프라인 통합이어야 한다.

최종 권장 방향은 다음과 같다.

> 절차적 그림 함수 모음이 아니라, 정본 게임 데이터와 아트 문법을 입력받아 압축 아틀라스·애니메이션 리소스·검증 보고서를 생성하는 자산 컴파일러로 재구성한다.

## 2. 현재 구현 상태

### 2.1 구현된 흐름

```text
recipes.json
    ↓
PixelGen
    ↓
개별 PNG + atlas.png + manifest.json
             + heroes.tres + monsters.tres
    ↓ publish
game_dungeon/generated
    ↓
AssetCatalog
    ├─ 정적 아이콘 아틀라스 소비
    ├─ 영웅 SpriteFrames 소비
    ├─ 몬스터 SpriteFrames 소비
    └─ 누락 시 런타임 PixelGen 폴백
```

### 2.2 현재 산출물 크기

| 파일 | 크기(검토 시점) | 역할 |
|---|---:|---|
| `atlas.png` | 약 17KB | 정적 타일·대표 스프라이트·아이콘 18종 |
| `manifest.json` | 약 2.8KB | 아틀라스 region, MD5, 생성기/레시피 버전 |
| `heroes.tres` | 약 703KB | 영웅 3종 × 4방향 걷기 프레임 |
| `monsters.tres` | 약 251KB | 몬스터 레시피 4종 걷기 프레임 |

정적 아틀라스는 매우 작지만 애니메이션 리소스 두 개는 약 954KB다. 이는 각 프레임의 `ImageTexture` 픽셀 데이터가 `.tres`에 반복 내장되기 때문이다.

### 2.3 런타임 실측

- 플레이어 방향 사용: 남·동·북·서 4방향
- 용병 방향 사용: 남·동·북·서 4방향
- 대표 자동 실행의 몬스터 자산 경로: 컴파일 2, 런타임 폴백 9
- 자산 카탈로그 셀프테스트: PASS
- 14개 스프라이트 구조 품질 검사: PASS
- 반복 생성 아틀라스 MD5 일치: PASS

## 3. 핵심 설계 문제

### 3.1 애니메이션 텍스처 중복

현재 `heroes.tres`와 `monsters.tres`는 프레임 텍스처를 개별 subresource로 포함한다. 캐릭터, 방향, 동작, 프레임 수가 증가하면 파일 크기와 로딩 비용이 선형 이상으로 증가한다.

Godot은 스프라이트 시트를 `AnimatedSprite2D` 또는 `Sprite2D`로 재생하는 표준 흐름을 제공한다. 여러 프레임은 하나의 애니메이션 아틀라스에 배치하고, `SpriteFrames`에는 아틀라스 region 참조만 저장하는 구조가 적합하다.

참고:

- [Godot: 2D sprite animation](https://docs.godotengine.org/en/4.0/tutorials/2d/2d_sprite_animation.html)
- [Godot: ResourceSaver](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html)

### 3.2 생성기 정본이 두 벌

현재 아래 파일이 복제되어 있다.

- `prototype/asset_gen/pixel_gen.gd`
- `prototype/game_dungeon/pixel_gen.gd`

MD5 검사는 두 파일의 불일치를 발견하지만 중복 자체를 제거하지 못한다. 수정자가 한쪽만 변경하면 생성 단계가 실패하고, 코드 리뷰에서도 동일한 대형 diff가 반복된다.

독립 `asset_gen` 프로젝트를 없애고 생성 도구를 `game_dungeon/tools` 아래에서 실행하는 구조가 단순하다.

```text
game_dungeon/
├─ pixel_gen.gd
├─ tools/
│  ├─ asset_compiler.gd
│  ├─ asset_quality.gd
│  └─ gallery.tscn
└─ generated/
```

장기적으로는 `EditorImportPlugin`을 사용해 레시피 변경과 생성 산출물의 의존성을 Godot 임포트 시스템에 맡기는 것이 가장 안정적이다. 공식 API는 추가 생성 파일을 `gen_files`로 등록하고 생성 파라미터·해시를 임포트 메타데이터에 기록할 수 있다.

- [Godot: EditorImportPlugin](https://docs.godotengine.org/en/stable/classes/class_editorimportplugin.html)
- [Godot: Import plugins](https://docs.godotengine.org/en/latest/tutorials/plugins/editor/import_plugins.html)

### 3.3 `user://` 경유 게시

현재 생성 결과를 먼저 `user://assetgen`에 쓴 뒤 `game_dungeon/generated`로 복사한다.

위험 요소:

- 이전 실행의 오래된 파일이 남을 수 있음
- 생성과 게시가 원자적이지 않음
- 게시 명령 누락을 Git이나 Godot이 자동 검출하지 못함
- 에디터 재임포트 순서에 의존
- CI에서 암묵적인 명령 순서를 알아야 함

개선된 게시 흐름은 임시 디렉터리에 전체 산출물을 만든 뒤 모든 검사를 통과한 경우에만 `generated`를 교체해야 한다.

### 3.4 게임 데이터와 아트 레시피 중복

`asset_gen/recipes.json`과 `game_dungeon/data/monsters.json`이 몬스터 이름과 색상을 각각 보관한다. 두 파일이 갈라지면 컴파일 자산과 런타임 폴백 자산의 외형이 달라진다.

게임 몬스터 데이터에 `art` 참조를 추가하고, 생성기 레시피는 재사용 가능한 archetype과 palette만 정의하는 것이 바람직하다.

```json
{
  "id": "fallen",
  "name": "Fallen",
  "art": {
    "archetype": "fallen",
    "palette": "fallen_red",
    "seed": 20,
    "scale": 1.0
  },
  "combat": {
    "hp": 14,
    "speed": 3.8
  }
}
```

```json
{
  "archetypes": {
    "fallen": {
      "canvas": [34, 42],
      "body": "demon_small",
      "horns": "short_pair",
      "weapon_anchor": [25, 19]
    }
  },
  "palettes": {
    "fallen_red": {
      "outline": "#12090a",
      "shadow": "#6b241d",
      "base": "#bf5940",
      "light": "#e18063"
    }
  }
}
```

### 3.5 컴파일과 폴백 혼재

검토 시점에 몬스터 12종 중 레시피에 등록된 종은 4종뿐이다. 자동 실행에서는 컴파일 자산 2개와 폴백 자산 9개가 함께 사용됐다.

이 구조는 개발 중에는 유용하지만 릴리스에서 유지하면 다음 문제가 생긴다.

- 컴파일 자산은 고정 시드, 폴백 자산은 셀 기반 시드
- 색상과 스케일의 정본이 서로 다름
- 일부 개체에서만 런타임 텍스처 생성 비용 발생
- 폴백 결과는 빌드 타임 품질 게이트의 직접 대상이 아님

권장 정책:

```text
개발 빌드: FALLBACK + 경고 및 카운터
테스트 빌드: WARN + 누락 목록 출력
릴리스 빌드: FAIL + 누락 art_id가 있으면 빌드 중단
```

### 3.6 방향 판정과 포즈 의미

현재 화면상의 `dx/dy` 크기로 남·동·북·서를 분류한다. 아이소메트릭 환경에서는 논리 그리드 방향과 화면 방향이 다르며, 경계 각도에서 방향이 흔들릴 수 있다.

개선안:

- 화면 위치가 아닌 `gx/gy` 변화량 또는 A* 다음 셀로 방향 판정
- 방향 전환 dead zone과 50~100ms 히스테리시스
- 공격 시 대상 방향으로 회전
- 향후 8방향은 논리 이동 벡터 각도를 8구간으로 양자화

또한 현재 4방향 프레임은 픽셀 값이 다르지만 완전한 정면·측면·후면 포즈는 아니다. 현재 품질 검사는 “다름”을 검증하지만 방향이 의미상 올바른지는 보장하지 않는다.

### 3.7 애니메이션 상태 부족

현재 실질적인 프레임 애니메이션은 idle/walk 중심이며 공격은 주로 `pop()` 스케일 효과에 의존한다.

다음 상태가 필요하다.

1. idle
2. walk
3. attack
4. cast
5. hit
6. death

권장 상태 전이:

```text
idle ─movement→ walk
walk ─stopped→ idle
idle/walk ─attack→ attack
idle/walk ─cast→ cast
any alive ─damage→ hit
any ─life 0→ death
attack/cast/hit ─finished→ idle 또는 walk
```

상태가 늘어나기 전에 수동 `Sprite2D.texture` 교체에서 `AnimatedSprite2D` 중심 구조로 전환하는 것이 좋다.

## 4. 품질 게이트 개선

현재 검사는 다음을 검증한다.

- 불투명 픽셀 밀도
- 팔레트 색상 수
- 연결 요소 수
- 이미지 경계 잘림
- 클래스 실루엣 차이
- 걷기 프레임 변화량
- 시드 변형 차이

실제로 소서리스, 안다리엘, Blood Hawk의 경계 잘림을 검출했으므로 유효성이 확인됐다.

추가할 지표:

### 4.1 프레임 정렬

- 발 앵커 위치 변화
- 머리 중심 위치 변화
- 손과 무기 앵커 거리
- 프레임별 bounding box 변화
- 중심 질량 이동량

### 4.2 애니메이션 연속성

- 인접 프레임 픽셀 차이 최소·최대
- 실루엣 IoU
- 연결 요소 수 변화
- 좌우 다리 교대 여부
- 반복 마지막 프레임과 첫 프레임 차이

### 4.3 방향 의미

- 동/서 프레임의 좌우 반전 관계
- 북쪽 프레임의 얼굴 픽셀 억제
- 무기 앵커가 진행 방향에 존재하는지
- 남/북 실루엣 차이 임계값

### 4.4 배경 가독성

- 액트별 대표 바닥과 외곽선 명도 차이
- 아이템 아이콘과 바닥의 대비
- 희귀도 색상 간 최소 색상 거리
- 색각 이상 시뮬레이션에서 드롭 구분 가능 여부

자동 생성은 최종본을 무조건 승인하는 도구보다 사람이 마무리할 반제품 생성 도구로 사용하는 것이 현실적이라는 연구 결과와도 일치한다.

- [Towards Machine-Learning Assisted Asset Generation for Games](https://www.sbgames.org/sbgames2019/files/papers/ComputacaoFull/197880.pdf)
- [Generating Pixel Art Character Sprites using GANs](https://arxiv.org/abs/2208.06413)

## 5. 목표 아키텍처

```text
Canonical game/art data
├─ monsters.json
├─ items.json
├─ art_recipes.json
└─ palettes.json
        │
        ▼
Asset compiler / EditorImportPlugin
├─ schema validation
├─ procedural generation
├─ animation packing
├─ quality gates
└─ deterministic hashes
        │
        ▼
Temporary build
├─ static_atlas.png
├─ animation_atlas.png
├─ animations.res
└─ manifest.json
        │
        ▼ all checks PASS
Atomic publish
        │
        ▼
AssetCatalog
├─ static regions
├─ animation clips
├─ development fallback
└─ release strict mode
        │
        ▼
Actor animation state machine
```

## 6. 개선 우선순위

### P0 — 구조 부채 제거

1. 영웅·몬스터 프레임을 `animation_atlas.png`로 통합
2. `.tres` 내부 픽셀 중복 제거
3. 두 `pixel_gen.gd`를 단일 정본으로 통합
4. `user://` 복사 대신 정식 컴파일/임포트 단계 도입
5. 릴리스 모드에서 누락 자산을 빌드 실패로 처리

기대 효과:

- 생성 리소스 용량 대폭 감소
- 생성기 정본 한 벌
- 게시 누락 방지
- 폴백 여부와 릴리스 완전성 명확화

### P1 — 시각적 체감 향상

1. attack/cast/hit/death 상태 추가
2. 정면·측면·후면 실루엣을 실제로 분리
3. 논리 그리드 기반 방향 판정
4. 손·발·머리·무기 앵커 도입
5. 장비 오버레이 시작

### P2 — 데이터 일원화

1. 몬스터 데이터에 `art` 블록 추가
2. 전체 12종 컴파일
3. archetype과 palette 분리
4. 챔피언·유니크를 팔레트·오버레이로 표현
5. 게임 데이터와 아트 데이터 참조 무결성 검사

### P3 — 제작 도구화

1. Godot import plugin
2. 갤러리에서 시드·팔레트·파츠 조정
3. 결과 잠금 및 승인
4. 승인 자산만 릴리스 아틀라스에 포함
5. 이전 승인본과 시각 diff 제공

## 7. 다음 구현 권고

가장 먼저 구현할 작업은 **애니메이션 아틀라스 통합**이다.

```text
1. animation_atlas.png 생성
2. animation_manifest.json 생성
3. SpriteFrames가 AtlasTexture region만 참조
4. heroes.tres/monsters.tres를 animations.res 하나로 통합
5. 파일 크기와 런타임 회귀 검증
6. 기존 내장 텍스처 리소스 제거
```

이 작업은 지금까지 구현한 생성 함수·레시피·품질 검사·카탈로그를 그대로 활용하면서 가장 큰 구조적 비용인 프레임 픽셀 중복을 제거한다. 이후 `AnimatedSprite2D` 상태 머신과 attack/cast/hit/death 확장도 자연스럽게 연결된다.

