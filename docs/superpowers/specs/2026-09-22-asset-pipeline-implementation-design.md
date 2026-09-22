# 디자인 자산 파이프라인 구현 상세 설계

작성일: 2026-09-22  
상태: 구현 준비  
상위 분석: [디자인 생성기 설계 재검토](../research/2026-09-22-asset-generator-architecture-review.md)

## 1. 목적

현재 자산 생성기의 기능을 유지하면서 다음 구조적 문제를 해결한다.

1. `heroes.tres`와 `monsters.tres`에 중복 저장되는 프레임 픽셀 제거
2. 두 벌인 `pixel_gen.gd`를 하나의 정본으로 통합
3. `user://` 중간 게시 의존 제거
4. 게임 데이터와 아트 레시피의 중복 제거
5. 개발 폴백과 릴리스 완전성 정책 분리
6. idle/walk 이후 attack/cast/hit/death 확장 기반 마련
7. 생성 결과의 구조적·시각적 회귀 검증 강화

완료 시 자산 흐름은 다음과 같아야 한다.

```text
정본 게임/아트 데이터
    ↓ schema + reference validation
단일 자산 컴파일러
    ↓ generate + pack + quality gates
임시 빌드 디렉터리
    ↓ atomic publish
static_atlas.png + animation_atlas.png
manifest.json + animations.res
    ↓
AssetCatalog
    ↓
Actor animation state machine
```

## 2. 범위

### 2.1 포함

- 생성기 단일화
- 데이터 스키마 분리 및 참조 일원화
- 정적/애니메이션 아틀라스 컴파일
- `SpriteFrames` region 참조 생성
- 원자적 게시
- 카탈로그 strict/fallback 정책
- 영웅/몬스터 애니메이션 조회 API
- Actor 애니메이션 상태 머신 기반
- 빌드 및 런타임 검증
- 기존 기능의 단계적 마이그레이션

### 2.2 제외

- 신규 클래스 추가
- 8방향 프레임 완성
- AI 이미지 생성 연동
- 인게임 아트 편집 UI
- 장비 paper-doll 전체 구현
- 모든 몬스터의 attack/death 아트 완성

제외 항목을 위한 확장 지점은 설계하지만 이번 구현 완료 조건에는 포함하지 않는다.

## 3. 설계 원칙

### 3.1 단일 정본

- 생성 코드 정본은 `game_dungeon/art/pixel_gen.gd` 한 벌만 둔다.
- 몬스터의 전투·아트 선택 정본은 `game_dungeon/data/monsters.json`이다.
- 재사용 가능한 형태와 팔레트만 별도 아트 데이터에 둔다.
- 생성 산출물은 파생 데이터이며 사람이 직접 편집하지 않는다.

### 3.2 결정론

동일한 다음 입력은 바이트가 동일한 아틀라스와 manifest를 생성해야 한다.

- 생성기 버전
- 정본 JSON 파일 내용
- 명시적 seed
- 정렬 규칙
- packing 규칙

파일 시스템 열거 순서나 Dictionary 순서에 결과가 의존해서는 안 된다.

### 3.3 검증 후 게시

산출물 하나라도 생성 또는 검증에 실패하면 기존 `generated`를 보존한다. 부분 게시를 금지한다.

### 3.4 개발과 릴리스 정책 분리

- 개발: 누락 자산 폴백 허용, 경고 및 계측
- 테스트: 폴백 허용, 누락 목록을 결과에 포함
- 릴리스: 폴백 금지, 누락 시 시작 또는 빌드 실패

### 3.5 런타임 생성 최소화

릴리스 중 전투 루프에서 `ImageTexture.create_from_image()`를 호출하지 않는다. 동적 색상 효과는 `modulate`, 셰이더 또는 사전 컴파일 변형으로 처리한다.

## 4. 목표 디렉터리 구조

```text
prototype/game_dungeon/
├─ art/
│  ├─ pixel_gen.gd
│  ├─ art_recipes.json
│  ├─ palettes.json
│  └─ schema/
│     ├─ art_recipes.schema.json
│     └─ palettes.schema.json
├─ data/
│  └─ monsters.json
├─ tools/
│  ├─ asset_compiler.gd
│  ├─ asset_packer.gd
│  ├─ asset_quality.gd
│  ├─ asset_report.gd
│  └─ gallery.tscn
├─ generated/
│  ├─ static_atlas.png
│  ├─ animation_atlas.png
│  ├─ manifest.json
│  └─ animations.res
├─ asset_catalog.gd
├─ actor.gd
└─ main.gd
```

마이그레이션 완료 후 다음을 제거한다.

```text
prototype/asset_gen/pixel_gen.gd
prototype/game_dungeon/pixel_gen.gd
prototype/game_dungeon/generated/atlas.png
prototype/game_dungeon/generated/heroes.tres
prototype/game_dungeon/generated/monsters.tres
```

독립 갤러리가 계속 필요하면 `tools/gallery.tscn`을 정본 프로젝트 안에서 실행한다.

## 5. 정본 데이터 상세 설계

### 5.1 `monsters.json`

기존 몬스터 항목에 안정적인 `id`와 `art` 블록을 추가한다.

```json
{
  "id": "fallen",
  "name": "Fallen",
  "kind": "melee",
  "art": {
    "archetype": "fallen",
    "palette": "fallen_red",
    "seed": 20,
    "scale": 1.0,
    "variant_count": 4
  },
  "level": 2,
  "hp": 14,
  "speed": 3.8
}
```

규칙:

- `id`: 영문 소문자 snake_case, 전역 유일
- `art.archetype`: `art_recipes.json`의 키
- `art.palette`: `palettes.json`의 키
- `seed`: 명시적 정수
- `scale`: 0보다 큰 실수
- `variant_count`: 1~16
- 기존 `color`는 마이그레이션 중만 허용하고 완료 후 제거

### 5.2 `art_recipes.json`

```json
{
  "version": 2,
  "archetypes": {
    "fallen": {
      "category": "monster",
      "canvas": [34, 42],
      "generator": "fallen",
      "anchors": {
        "origin": [17, 38],
        "head": [17, 9],
        "hand_front": [24, 19],
        "hand_back": [10, 19],
        "foot_left": [12, 38],
        "foot_right": [22, 38]
      },
      "animations": {
        "idle": {"frames": [0], "fps": 1, "loop": true},
        "walk": {"frames": [1, 0, 2, 0], "fps": 8, "loop": true}
      }
    }
  },
  "static_assets": [
    {
      "id": "icon_sword",
      "category": "icon",
      "generator": "sword",
      "seed": 0
    }
  ]
}
```

`generator`는 코드에 등록된 허용 목록만 사용한다. JSON에서 임의 함수명 또는 스크립트 경로를 실행하지 않는다.

### 5.3 `palettes.json`

```json
{
  "version": 1,
  "palettes": {
    "fallen_red": {
      "outline": "#12090A",
      "deep_shadow": "#4A1715",
      "shadow": "#762820",
      "base": "#BF5940",
      "light": "#E18063",
      "highlight": "#F2B08B",
      "emissive": "#FFD32A"
    }
  }
}
```

규칙:

- 모든 필수 슬롯 존재
- 색상 문자열은 `#RRGGBB` 또는 `#RRGGBBAA`
- outline 명도는 base보다 낮아야 함
- highlight 명도는 base보다 높아야 함
- 같은 팔레트 내 완전 중복 색상 금지

## 6. 컴파일러 상세 설계

### 6.1 진입점

파일: `tools/asset_compiler.gd`

실행 예:

```powershell
godot_console --headless --path prototype/game_dungeon `
  --script res://tools/asset_compiler.gd -- build

godot_console --headless --path prototype/game_dungeon `
  --script res://tools/asset_compiler.gd -- verify
```

지원 명령:

| 명령 | 동작 |
|---|---|
| `build` | 전체 생성·검사·게시 |
| `verify` | 현재 생성물과 입력 해시·참조 무결성 검사 |
| `gallery` | 생성 결과 갤러리 실행용 데이터 준비 |
| `clean-stale` | manifest에 없는 생성 파일만 안전하게 제거 |

`clean-stale`은 `generated` 외부를 절대 대상으로 삼지 않는다.

### 6.2 컴파일 단계

```text
1. 입력 파일 읽기
2. JSON 문법 및 필드 검증
3. ID/참조 무결성 검증
4. 모든 컴파일 작업을 안정 정렬
5. 정적 자산 생성
6. 애니메이션 프레임 생성
7. 정적/애니메이션 아틀라스 packing
8. SpriteFrames region 참조 생성
9. 구조·시각 품질 검사
10. 임시 산출물 재로드 검사
11. 입력/출력 해시 manifest 기록
12. generated 원자적 교체
```

### 6.3 작업 키 정렬

결정론을 위해 모든 작업은 다음 문자열 키로 정렬한다.

```text
static/{category}/{asset_id}/{variant}
anim/{actor_id}/{variant}/{animation}/{direction}/{frame_index}
```

예:

```text
anim/barbarian/0/walk/e/0
anim/barbarian/0/walk/e/1
anim/fallen/2/idle/s/0
static/icon/icon_sword/0
```

### 6.4 아틀라스 packing

1차 구현은 복잡한 bin-packing 대신 고정 셀을 사용한다.

| 종류 | 셀 크기 |
|---|---:|
| 아이콘 | 32×32 |
| 영웅 | 40×48 |
| 일반 몬스터 | 40×48 |
| 보스 | 64×64 |
| 아이소 타일 | 64×32 |

packing 규칙:

- 작업 키 정렬 후 행 우선 배치
- 각 region 주위 1px 투명 padding
- 아틀라스 최대 크기 기본 1024×1024
- 초과 시 `animation_atlas_00.png`, `_01.png`로 분할
- 이미지 필터링은 nearest
- mipmap 비활성

향후 효율적 bin-packing으로 교체하더라도 manifest API는 유지한다.

### 6.5 애니메이션 manifest

```json
{
  "format_version": 2,
  "generator_version": 4,
  "inputs": {
    "monsters_md5": "...",
    "recipes_md5": "...",
    "palettes_md5": "..."
  },
  "atlases": {
    "static": {
      "file": "static_atlas.png",
      "md5": "...",
      "size": [512, 512]
    },
    "animation": {
      "file": "animation_atlas.png",
      "md5": "...",
      "size": [1024, 1024]
    }
  },
  "static": {
    "icon_sword": {
      "atlas": "static",
      "region": [0, 0, 32, 32]
    }
  },
  "actors": {
    "barbarian": {
      "animations": {
        "walk_s": {
          "fps": 8,
          "loop": true,
          "frames": [
            {"atlas": "animation", "region": [0, 0, 32, 40], "duration": 1.0}
          ]
        }
      }
    }
  }
}
```

모든 좌표는 정수이며 PNG 실제 크기 안에 있어야 한다.

### 6.6 `animations.res`

- 하나의 `SpriteFrames` 리소스 사용
- 애니메이션 이름: `{actor_id}/{state}_{direction}`
- 예: `barbarian/walk_s`, `fallen/idle_e`
- 각 프레임은 `animation_atlas.png`를 공유하는 `AtlasTexture`
- 픽셀 데이터 subresource 금지
- 최종 리소스는 바이너리 `.res`와 `FLAG_COMPRESS` 사용 검토

완료 검사:

- 모든 프레임의 `AtlasTexture.atlas`가 허용된 외부 PNG
- 내장 `ImageTexture` subresource 0개
- manifest 프레임 수와 `SpriteFrames` 프레임 수 일치

## 7. 원자적 게시

### 7.1 임시 경로

```text
prototype/game_dungeon/.asset-build/{build_id}/
```

`build_id`는 입력 해시 앞 12자리로 한다.

### 7.2 게시 절차

```text
temp 생성 완료
    ↓
모든 품질/재로드 검사 PASS
    ↓
generated.next에 복사
    ↓
generated.next 파일 목록 재검증
    ↓
기존 generated → generated.previous
generated.next → generated
    ↓
성공 시 previous 제거
실패 시 previous 복원
```

Windows에서는 이동 대상의 절대 경로가 반드시 프로젝트 `generated` 아래인지 확인한다. 빌드 스크립트 외부의 재귀 삭제는 금지한다.

### 7.3 산출물 소유권

- `generated` 산출물은 Git 추적
- `.godot` 임포트 캐시는 Git 제외
- PNG의 `.import` 설정은 필요 시 Git 추적
- 생성 파일 첫 줄 또는 manifest에 “직접 수정 금지” 명시

## 8. AssetCatalog API

파일: `asset_catalog.gd`

### 8.1 정책

```gdscript
enum MissingPolicy {
    FALLBACK,
    WARN,
    FAIL,
}
```

초기화:

```gdscript
func configure(policy: MissingPolicy, fallback_generator: GDScript = null) -> void
```

기본값:

- editor/debug: `WARN`
- release: `FAIL`

### 8.2 정적 자산 API

```gdscript
func static_texture(id: StringName) -> Texture2D
func has_static(id: StringName) -> bool
```

### 8.3 애니메이션 API

```gdscript
func sprite_frames() -> SpriteFrames
func animation_name(actor_id: StringName, state: StringName, direction: StringName) -> StringName
func has_animation(actor_id: StringName, state: StringName, direction: StringName) -> bool
```

호출 예:

```gdscript
sprite.sprite_frames = catalog.sprite_frames()
sprite.play(catalog.animation_name("barbarian", "walk", "s"))
```

### 8.4 진단 API

```gdscript
func missing_assets() -> PackedStringArray
func fallback_count() -> int
func loaded_atlas_count() -> int
func validate_runtime() -> Dictionary
```

`validate_runtime()` 결과:

```gdscript
{
    "ok": true,
    "static_entries": 18,
    "actors": 15,
    "animations": 72,
    "missing": [],
    "fallback_count": 0,
}
```

## 9. Actor 애니메이션 상태 머신

### 9.1 노드 변경

현재 `Sprite2D`를 `AnimatedSprite2D`로 교체한다.

```text
Actor(Node2D)
├─ AnimatedSprite2D
├─ HP/MP drawing
└─ combat/state data
```

### 9.2 상태

```gdscript
enum AnimState {
    IDLE,
    WALK,
    ATTACK,
    CAST,
    HIT,
    DEATH,
}
```

우선순위:

```text
DEATH > HIT > ATTACK/CAST > WALK > IDLE
```

### 9.3 방향

```gdscript
enum Facing {
    SOUTH,
    EAST,
    NORTH,
    WEST,
}
```

방향 입력은 논리 좌표 이동량을 사용한다.

```gdscript
func update_facing(grid_velocity: Vector2) -> void
```

규칙:

- 길이 0.05 미만이면 기존 방향 유지
- 축 우세가 명확하지 않으면 기존 방향 유지
- 방향 최소 유지 시간 0.075초
- 공격/시전 시작 시 대상 방향으로 즉시 전환

### 9.4 API

```gdscript
func configure_animation(catalog: AssetCatalog, actor_id: StringName) -> void
func set_motion(grid_velocity: Vector2) -> void
func play_attack(target_grid_delta: Vector2) -> void
func play_cast(target_grid_delta: Vector2) -> void
func play_hit() -> void
func play_death() -> void
```

attack/cast/hit 리소스가 아직 없으면 현재 `pop`/flash 효과를 사용하되 상태 전이는 동일하게 유지한다.

## 10. 품질 게이트 상세

### 10.1 입력 검사

- JSON parse 성공
- schema version 지원
- 중복 ID 없음
- 모든 참조 해결
- seed 범위 유효
- scale 양수
- animation frame 배열 비어 있지 않음

### 10.2 픽셀 검사

- 불투명 픽셀 밀도 범위
- 팔레트 슬롯 외 색상 금지 또는 허용 오차 적용
- 연결 요소 수 상한
- 이미지 경계 접촉 금지
- 고립된 1~2픽셀 군집 상한
- origin/anchor 이미지 내부

### 10.3 애니메이션 검사

- 발 앵커 편차 ≤ 2px
- 머리 앵커 편차 ≤ 2px
- 인접 프레임 실루엣 IoU ≥ 0.55
- 인접 프레임 픽셀 차이 ≥ 4
- 인접 프레임 픽셀 차이 ≤ 전체 픽셀의 45%
- loop 마지막↔첫 프레임 급변 상한
- death만 마지막 프레임 고정 허용

### 10.4 아틀라스 검사

- region 중첩 없음(동일 자산 alias 제외)
- region 범위가 아틀라스 내부
- padding 보존
- manifest 항목 수와 packing 작업 수 일치
- 저장 후 다시 로드한 이미지 MD5 일치

### 10.5 게임 참조 검사

- 모든 몬스터 `art.archetype` 해결
- 모든 `art.palette` 해결
- 릴리스 빌드에서 모든 필수 상태/방향 존재
- 정적 아이콘 ID 모두 해결
- 폴백 카운터 0

## 11. 테스트 전략

### 11.1 단위 테스트

| 대상 | 테스트 |
|---|---|
| schema loader | 누락/중복/잘못된 타입 거부 |
| palette loader | 필수 슬롯, 색상 문자열, 명도 순서 |
| packer | 중첩 없음, 결정론, 다중 아틀라스 분할 |
| manifest | encode/decode round trip |
| catalog | 정상 조회, 누락 정책, 캐시 재사용 |
| direction | 논리 벡터→4방향, dead zone, hysteresis |
| quality | 경계·고립·팔레트·앵커 실패 검출 |

### 11.2 골든 테스트

대표 입력의 다음 파일 MD5를 기준으로 유지한다.

- `static_atlas.png`
- `animation_atlas.png`
- 정규화된 `manifest.json`

의도적 시각 변경 시 새 골든을 명시적으로 승인한다.

### 11.3 통합 테스트

```text
1. build 2회 → 산출물 MD5 동일
2. generated 삭제 후 build → 전체 복원
3. 레시피 잘못된 참조 → 기존 generated 보존, build FAIL
4. 개발 모드 누락 자산 → 폴백 및 경고
5. 릴리스 모드 누락 자산 → FAIL
6. 바바리안 50초 자동 실행
7. 소서리스 50초 자동 실행
8. 플레이어·용병 방향 4개 관측
9. 컴파일 몬스터 사용 > 0
10. 최종 폴백 수 0(전체 마이그레이션 후)
```

### 11.4 성능 측정

검증 머신: i5-3360M, 8GB, Intel HD 4000.

측정 항목:

- 컴파일 시간
- 정본 게임 시작 시간
- 생성 리소스 총 크기
- 로드된 텍스처 수
- 50초 실행 평균/최저 FPS
- 전투 중 런타임 `ImageTexture` 생성 횟수

목표:

| 지표 | 목표 |
|---|---:|
| 애니메이션 산출물 | 기존 약 954KB 대비 50% 이상 감소 |
| 릴리스 런타임 이미지 생성 | 0회 |
| 시작 시간 회귀 | 10% 이내 |
| 최저 FPS | 기존 검증치 대비 10% 이내 회귀 |

## 12. 단계별 구현 계획

### Phase A — 애니메이션 아틀라스

파일:

- 수정: `prototype/asset_gen/main.gd`
- 신규: `prototype/asset_gen/packer.gd`
- 수정: `prototype/game_dungeon/asset_catalog.gd`

작업:

1. 생성된 모든 영웅/몬스터 프레임을 작업 목록으로 수집
2. 고정 셀 packing
3. `animation_atlas.png`와 frame manifest 생성
4. manifest region으로 외부 아틀라스를 참조하는 `AtlasTexture` 지연 생성
5. 카탈로그가 통합 리소스를 로드하도록 수정
6. 기존 `heroes.tres`, `monsters.tres` 제거

완료 조건:

- 기존 애니메이션과 픽셀 결과 동일
- 두 `.tres` 제거
- 애니메이션 산출물 크기 50% 이상 감소
- 바바리안/소서리스 통합 실행 PASS

### Phase B — 생성기 단일화

작업:

1. `pixel_gen.gd`를 `game_dungeon/art`로 이동
2. 컴파일러·품질 검사·갤러리를 `game_dungeon/tools`로 이동
3. 독립 프로젝트 의존 제거
4. MD5 소스 동기화 검사 제거
5. 새 단일 명령 문서화

완료 조건:

- `pixel_gen.gd` 한 벌
- 동일 산출물 MD5
- 게임 및 컴파일러 모두 같은 preload 사용

### Phase C — 데이터 일원화

작업:

1. `monsters.json`에 `id`와 `art` 추가
2. palette/archetype 파일 분리
3. 중복 name/color 레시피 제거
4. 전체 몬스터 12종 컴파일
5. 참조 무결성 검사 추가

완료 조건:

- 몬스터 데이터 중복 없음
- 전체 12종 catalog 조회 성공
- 자동 실행 몬스터 폴백 0

### Phase D — 게시와 정책

작업:

1. 임시 빌드 및 원자적 게시
2. stale 산출물 검사
3. `MissingPolicy` 추가
4. 릴리스 strict 검사
5. CI용 `verify` 명령 추가

완료 조건:

- 실패한 빌드가 기존 산출물을 변경하지 않음
- 릴리스에서 누락 자산 즉시 실패
- 반복 빌드 결과 동일

### Phase E — 애니메이션 상태 머신

작업:

1. Actor를 `AnimatedSprite2D` 기반으로 전환
2. 논리 좌표 방향 판정
3. idle/walk 상태 이전
4. attack/cast/hit/death 확장 지점 추가
5. 기존 pop/flash를 폴백 효과로 유지

완료 조건:

- 기존 이동·전투 회귀 없음
- 네 방향 전환 유지
- 상태 우선순위 단위 테스트 PASS

## 13. 호환성과 마이그레이션

마이그레이션 동안 `AssetCatalog`는 다음 순서로 조회한다.

```text
animations.res
    ↓ 없음
legacy heroes.tres / monsters.tres
    ↓ 없음
runtime PixelGen (개발만)
```

Phase A 검증 완료 후 legacy 리소스를 삭제한다. Phase C 완료 후 릴리스에서는 runtime 폴백을 비활성화한다.

manifest에는 `format_version`을 두고 카탈로그가 지원하지 않는 상위 버전을 조용히 무시하지 않도록 한다.

```gdscript
if manifest.format_version > SUPPORTED_FORMAT_VERSION:
    push_error("Unsupported asset manifest version")
    return false
```

## 14. 오류 처리

### 컴파일 오류

- 오류 메시지에 자산 ID와 JSON 경로 포함
- 가능한 경우 필드 이름과 실제 값 포함
- 하나의 오류에서 중단하지 않고 참조/스키마 오류를 모아 출력
- 픽셀 생성 또는 저장 실패는 즉시 중단

예:

```text
[ASSET][ERROR] monsters[4].art.palette='bone_white2': unknown palette
[ASSET][ERROR] archetypes.fallen.animations.walk: empty frames
[ASSET][RESULT] FAIL errors=2 published=false
```

### 런타임 오류

- `WARN`: 자산 ID당 최초 1회만 경고
- `FAIL`: 자산 ID, 상태, 방향을 포함해 실패
- 같은 누락을 매 프레임 로그하지 않음

## 15. 관측성과 결과 출력

컴파일 결과:

```text
[ASSET] inputs monsters=12 archetypes=9 palettes=11
[ASSET] generated static=18 frames=144
[ASSET] atlases static=1 animation=1
[ASSET] quality checked=162 failures=0
[ASSET] size old=954430 new=281204 reduction=70.5%
[ASSET] deterministic=true
[ASSET] published=true
[ASSET][RESULT] PASS
```

런타임 결과:

```text
[ASSET] manifest=2 atlases=2 animations=72
[ASSET] policy=FAIL missing=0 fallback=0
[ANIM] player directions=4 states=2
[ANIM] monsters compiled=11 fallback=0
```

## 16. 수용 기준

전체 설계 구현 완료 조건:

- [x] 정본 게임·컴파일러가 `art/pixel_gen.gd` 한 벌만 사용(구형 독립 프로토타입 제외)
- [x] 정적/애니메이션 아틀라스가 분리 생성됨
- [x] 런타임 애니메이션 프레임이 외부 atlas region만 참조
- [x] `heroes.tres`, `monsters.tres` 제거
- [x] 애니메이션 산출물 크기 50% 이상 감소(954,430 → 35,439바이트, 96.3%)
- [x] 게임 데이터의 몬스터 12종 모두 검증된 art 참조 보유
- [x] strict 빌드의 폴백 수 0
- [x] 실패한 컴파일은 기존 generated를 보존
- [x] 반복 빌드 MD5 동일
- [x] 정적 24종 및 애니메이션 24개 anchor/연속성 검사 PASS(편차 1px, 최소 IoU 0.802)
- [x] 바바리안·소서리스 50초 자동 실행 PASS
- [x] 플레이어·용병 4방향 관측
- [x] 런타임 리소스 누수 경고 없음
- [x] 진행 문서와 생성기 README 갱신

## 17. 첫 구현 단위

첫 작업은 Phase A만 수행한다. 생성기 이동이나 데이터 스키마 변경을 동시에 하지 않는다.

구체적 순서:

1. `packer.gd` 추가
2. 기존 hero/monster 프레임을 `FrameJob` 배열로 수집
3. `animation_atlas.png` 생성
4. 각 job의 region을 manifest에 기록
5. region 기반 `animations.res` 생성
6. `AssetCatalog`에 새 포맷 우선 로드 추가
7. 기존 리소스와 픽셀/프레임 수 비교
8. 게임 통합 테스트
9. 용량 감소 확인
10. legacy 리소스 삭제

이 단위는 생성 코드와 게임 데이터를 변경하지 않으므로 위험이 가장 낮고, 가장 큰 현재 비용인 프레임 픽셀 중복을 직접 제거한다.

## 18. 제품 목표 구체화 및 방향 정당성

### 18.1 확정 목표

프로젝트의 상위 제품 목표를 다음 세 축으로 정의한다.

1. **디자인 리소스 직접 생성**  
   캐릭터, 몬스터, 타일, 아이콘, 이펙트, UI 스킨과 사운드는 자체 제작 또는 자체 생성한다. 타 게임의 추출 자산, 스크린샷, 폰트, 음원, 로고를 포함하지 않는다.
2. **Diablo Immortal의 모바일 우선 UX를 참조한 독자 UI 설계**  
   좌측 이동 조작, 우측 공격·스킬 클러스터, 큰 HUD 요소, 터치 친화 메뉴, 스킬 버튼 위치 조정이라는 모바일 원리를 참조하되 화면, 아이콘, 장식, 배치와 그래픽을 직접 제작한다.
3. **Diablo II의 시스템 깊이와 상호작용을 목표 모델로 사용**  
   전투 수식, 성장, 파밍, 접사, 스킬, 난이도, 제작, 용병, 퀘스트, 액트 진행 등 시스템 동작의 충실도를 높인다. 명칭·스토리·캐릭터·몬스터·지역·대사·아트·음원·테이블 수치의 직접 복제를 목표로 하지 않는다.

제품 문구는 다음처럼 사용한다.

> 자체 생성 다크 판타지 자산과 모바일 우선 UI를 사용하는, Diablo II 수준의 시스템 깊이를 목표로 한 독립 액션 RPG.

내부 기술 비교표에서는 D2/Immortal을 참조 모델로 표기할 수 있지만, 외부 제품명·스토어 설명·게임 로고에는 이를 제품 정체성처럼 사용하지 않는다.

### 18.2 Diablo Immortal 모바일 UX 참조 범위

참조 대상은 **Diablo Immortal의 모바일 버전**이다. Blizzard는 Immortal을 모바일 우선으로 만들었기 때문에 휴대전화 화면에 맞춰 UI 요소가 더 크며, PC판에서는 오히려 HUD를 축소했다고 설명한다. 따라서 모바일 UI 목표의 근거로 적절하다.

- [Blizzard: Making Diablo Immortal for PC](https://news.blizzard.com/en-us/article/23797159/making-diablo-immortal-for-pc)

참조와 독자 설계의 경계를 다음처럼 정의한다.

```text
Diablo Immortal에서 참고할 UX 원리
├─ 좌측 엄지 이동, 우측 엄지 주 공격·스킬 클러스터
├─ 이동하면서 공격·충전 스킬을 사용할 수 있는 입력 분리
├─ 휴대전화 화면에 맞춘 큰 HUD와 메뉴 조작 영역
├─ 전투 HUD와 전체 화면 상세 메뉴의 정보 밀도 분리
├─ 스킬 버튼 위치 조정과 입력 방식 전환
└─ 텍스트 확대·밝기·오디오 신호 등 접근성 옵션

프로젝트가 직접 설계할 것
├─ 엄지 도달 영역
├─ 가상 조이스틱과 스킬 클러스터
├─ 터치 타깃 확대
├─ safe area 및 다양한 화면비
├─ 길게 누르기/드래그/탭 충돌 방지
└─ 작은 화면용 단계적 정보 공개
```

Immortal은 모바일에서 이동과 공격을 동시에 수행하는 조작을 기본 경험으로 두었고, 스킬 버튼 위치 조정과 컨트롤러 자동 감지를 제공한다. 따라서 본 프로젝트 역시 데스크톱 UI를 축소하는 것이 아니라 터치를 기준으로 조작과 레이아웃을 설계하는 방향이 타당하다.

- [Blizzard: Diablo Immortal mobile and PC UI/controller differences](https://news.blizzard.com/en-gb/article/23787371/diablo-immortaltm-a-new-plane-of-hell-opens-for-mobile-and-pc-on-june-2)
- [Blizzard: Diablo Immortal accessibility and repositionable skill buttons](https://news.blizzard.com/en-gb/article/23805083/making-a-game-for-everyonediablo-immortals-accessibility-features)

### 18.3 UI 시각 정체성 원칙

직접 생성할 UI 디자인 토큰:

```json
{
  "surface": {
    "background": "#100E12",
    "panel": "#1A171B",
    "panel_raised": "#252027",
    "border": "#625447"
  },
  "semantic": {
    "life": "#A82727",
    "resource": "#285E9E",
    "poison": "#538A38",
    "warning": "#D08A2F",
    "disabled": "#716B70"
  },
  "rarity": {
    "normal": "#D2D0CC",
    "magic": "#718BE3",
    "rare": "#E3CB55",
    "unique": "#B8874D"
  }
}
```

규칙:

- 색상만으로 상태를 구분하지 않고 아이콘·외곽선·문양을 함께 사용
- 장식은 정보 영역을 침범하지 않음
- 패널 테두리와 배경 텍스처는 생성기가 제작
- 로고, 고유 문양, 아이콘 실루엣은 독자 디자인
- 사용 폰트는 직접 제작 또는 상업 사용 가능한 라이선스 확인
- 화면 캡처를 트레이싱하거나 원본 UI 텍스처를 변형하지 않음

### 18.4 모바일 기준 해상도와 레이아웃

기준 방향은 가로 화면이다.

```text
design resolution: 1280 × 720
minimum supported logical area: 960 × 540
target aspect ratios: 4:3, 16:9, 18:9, 19.5:9, 20:9
stretch: canvas_items 또는 viewport 비교 검증
aspect: expand
```

Godot은 단일 기준 해상도와 anchors/containers를 이용해 다양한 화면 크기와 비율을 처리하도록 권장한다. 픽셀 아트 왜곡 방지를 위해 정수 스케일 모드도 검토한다.

- [Godot: Multiple resolutions](https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html)
- [Godot: UI and scaling features](https://docs.godotengine.org/en/stable/about/list_of_features.html)

화면 구역:

```text
┌─────────────────────────────────────────────────────────┐
│ 상태/퀘스트(좌상)              미니맵·메뉴(우상)        │
│                                                         │
│                    전투 가시 영역                       │
│                                                         │
│ 가상 조이스틱                    보조      주 스킬       │
│ (좌하 엄지)                 포션   스킬군   공격(우하)    │
└─────────────────────────────────────────────────────────┘
```

안전 영역:

- 좌우·상하 inset은 OS safe area를 반영
- 중요한 버튼은 물리 화면 끝에서 최소 16 logical px 안쪽
- 노치·카메라 홀 영역에 HUD 배치 금지
- 4:3에서는 중앙 전투 영역을 유지하고 좌우 HUD 간격 축소
- ultrawide에서는 전투 시야를 무제한 확장하지 않고 HUD 여백 증가

### 18.5 터치 입력 규격

Android는 최소 48dp, Apple은 최소 44pt의 터치 타깃을 권장한다. 본 프로젝트는 전투 중 정확도를 위해 기본 56 logical px, 주 공격은 72~88 logical px를 사용한다.

- [Android accessibility: minimum 48dp touch target](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views)
- [Apple UI design: minimum 44pt hit target](https://developer.apple.com/design/tips/)

| 요소 | 표시 크기 | 최소 hit area | 비고 |
|---|---:|---:|---|
| 주 공격 | 72~88 | 88×88 | 우하단 최우선 |
| 스킬 버튼 | 56~68 | 64×64 | 버튼 사이 최소 8 |
| 포션 | 52~60 | 60×60 | 수량·자동 사용 상태 표시 |
| 메뉴 | 40~48 | 48×48 | safe area 반영 |
| 인벤 슬롯 | 48~56 | 56×56 | 탭/길게 누르기 분리 |
| 텍스트 행 버튼 | 높이 48 이상 | 전체 행 | 작은 아이콘만 누르게 하지 않음 |

제스처 계약:

- 탭: 선택 또는 즉시 사용
- 길게 누르기 350ms: 툴팁/상세
- 드래그 임계거리 12 logical px: 이동 시작
- 길게 누르기와 드래그는 상호 배타적
- 두 손가락 이상의 게임 핵심 조작 요구 금지
- 버튼을 누른 채 다른 버튼으로 미끄러질 때 오작동 방지

### 18.6 HUD와 상세 패널 분리

전투 HUD에는 다음만 상시 노출한다.

- 생명·주 자원
- 현재 사용 가능한 4~6개 행동
- 포션 수량
- 중요한 상태이상
- 최소 미니맵
- 현재 목표 한 줄

다음은 패널에서만 표시한다.

- 전체 능력치
- 저항 상세
- 접사 설명
- 제작·경매 설정
- 스킬 트리
- 퀘스트 전문

UI 상태:

```text
Combat HUD
├─ Inventory overlay
├─ Character overlay
├─ Skill overlay
├─ Vendor/Auction overlay
└─ Settings overlay
```

overlay가 열리면 이동 입력을 유지할지 정지할지 모드별로 명시한다. 온라인 모드는 월드를 정지하지 않고, 오프라인 모드는 선택적으로 일시 정지할 수 있다.

### 18.7 접근성 목표

Diablo Immortal은 모바일 스킬 버튼 위치 조정, 컨트롤러 자동 감지·재매핑, UI 탐색용 자유 커서, 최대 200% 채팅 텍스트 확대, 세계 밝기 조절 등을 제공한다. 프로젝트도 모바일 조작성과 가독성을 위해 다음을 지원한다.

- UI 배율 80/100/120/140%
- 본문 텍스트 소/중/대
- 툴팁 배경 불투명도
- 화면 흔들림 감소
- 피해 숫자 on/off
- 색각 보조 팔레트
- 중요 드롭 빛기둥·문양·소리 중복 알림
- 가상 조이스틱 고정/부동 선택
- 스킬 버튼 위치 좌우 반전
- 자동 습득·자동 포션과 같은 조작성 보조

- [Blizzard: Accessibility in Diablo Immortal](https://news.blizzard.com/en-gb/article/23805083/making-a-game-for-everyonediablo-immortals-accessibility-features)

### 18.8 Diablo II 시스템 충실도 목표

“모든 시스템과 콘텐츠를 동일하게”라는 목표는 그대로는 완료 조건을 정의하기 어렵고 직접 복제 위험이 있다. 따라서 **메커니즘 충실도**와 **표현 독창성**을 분리한다.

목표 해석을 다음처럼 확정한다.

| 요구 표현 | 구현 해석 | 판정 |
|---|---|---|
| 모든 시스템 동일 | 관찰 가능한 규칙·상호작용·경계 조건을 독자 코드로 재현 | 타당 |
| 콘텐츠 구조 동일 | 클래스 역할, 액트 진행, 아이템 계층, 보스/퀘스트 밀도와 같은 구조적 범주 재현 | 조건부 타당 |
| 콘텐츠 양 동일 | 장기적으로 비슷한 다양성과 반복 플레이 볼륨 확보 | 단계화 필요 |
| 고유 콘텐츠 동일 | 원작 명칭·스토리·대사·외형·맵·음원·아이콘·데이터를 그대로 복제 | 목표에서 제외 |

따라서 상세 목표 문장은 다음으로 고정한다.

> Diablo II의 공개적으로 관찰 가능한 시스템 규칙과 시스템 간 상호작용을 높은 충실도로 독자 구현하고, 각 시스템을 동일한 깊이로 경험할 수 있는 독자 콘텐츠를 직접 생성한다.

여기서 “동일한 깊이”는 동일 파일·이름·표현의 복제가 아니라 다음을 의미한다.

- 동일 종류의 플레이어 의사결정이 존재
- 유사한 시스템 상호의존성과 빌드 다양성이 존재
- 공식과 cap, breakpoint, 예외 조건을 테스트할 수 있음
- 초반·중반·후반의 성장 단계가 존재
- 대표 콘텐츠 몇 개가 아니라 시스템을 충분히 사용하는 데이터 볼륨이 존재

#### A. 메커니즘 충실도 대상

| 축 | 목표 |
|---|---|
| 프레임 모델 | 25Hz 논리 틱, FCR/FHR와 유사한 breakpoint 구조 |
| 전투 | 명중/방어, 블록, 저항, 면역, 흡혈, 치명 효과, 속성 상성 |
| 캐릭터 | 클래스별 기본 스탯, 레벨업 포인트, 스킬 트리·시너지 |
| 아이템 | 베이스, 품질, 접두/접미, ilvl/alvl, 소켓, 세트/고유 계층 |
| 제작 | 보석·룬·룬 조합·큐브형 변환 |
| 드롭 | NoDrop, 몬스터 레벨, MF diminishing return, 보스/챔피언 보정 |
| 난이도 | 다단 난이도, 저항 페널티, 몬스터 스케일, 면역 변화 |
| 동료 | 용병 성장·장비·부활·AI |
| 진행 | 액트형 캠페인, 퀘스트, 보스, 웨이포인트 |
| 경제 | 상점, 수리, 도박, 골드 소비처 |
| 온라인 | 계정, 동기화, 권위 서버, 안전 거래 |

“유사”는 대충 흉내 낸다는 의미가 아니라, 공개적으로 관찰 가능한 규칙을 독자 코드와 데이터로 재구현하고 결정론 테스트로 검증한다는 의미다.

#### B. 독자적으로 제작할 표현과 콘텐츠

- 클래스 이름과 배경 설정
- 캐릭터·몬스터 이름과 외형
- 지역명, 맵 테마, 퀘스트 대사와 이야기
- 아이템 고유명과 flavor text
- 스킬 이름, 아이콘, VFX와 SFX
- UI 프레임, 패널, 폰트, 문양
- 레벨 배치와 캠페인 순서
- 원본 수치 테이블을 그대로 전재하지 않은 독자 밸런스 데이터

#### C. 콘텐츠 등가성 명세

직접 생성 콘텐츠가 시스템 목표를 충족하는지는 이름의 동일성이 아니라 역할 coverage로 판단한다.

예시:

```text
원소 전투 coverage
├─ 화염 저항/약점 몬스터
├─ 냉기 둔화/면역 몬스터
├─ 번개 고분산 피해 몬스터
├─ 독 지속 피해 몬스터
└─ 복합 속성 보스

아이템 coverage
├─ 일반/매직/레어/세트형/고유형 계층
├─ 무기/방어구/장신구 역할군
├─ 빌드 활성화 접사
├─ 소켓과 삽입 재료
├─ 조합 순서 기반 제작
└─ 초반/중반/후반 베이스 progression
```

각 시스템은 `coverage.json`에 요구 역할을 정의하고 실제 콘텐츠 ID가 이를 충족하는지 빌드 타임에 검사한다. 이는 원작 고유 콘텐츠를 복제하지 않고도 시스템 깊이 목표를 객관화한다.

미국 저작권청은 게임의 아이디어·플레이 방법·시스템·방법 자체와 구체적인 문학·그래픽 표현을 구분한다. 아이디어와 방법은 저작권 보호 대상이 아닐 수 있지만, 그림·텍스트 등 구체적 표현은 보호될 수 있다. 이 문서는 법률 자문이 아니며 실제 배포·상업화 전에는 관할권에 맞는 전문 검토가 필요하다.

- [U.S. Copyright Office: Games](https://www.copyright.gov/register/tx-games.html)
- [17 U.S.C. §102: idea, procedure, process, system and method exclusion](https://www.copyright.gov/title17/92chap1.html)
- [U.S. Copyright Office Circular 33](https://www.copyright.gov/circs/circ33.pdf)

Blizzard의 EULA는 플랫폼과 관련된 시각 요소, 이야기, 캐릭터, 아이템, 음원, 코드 및 파생 저작물에 관한 제한을 명시한다. 따라서 원본 파일 추출·변형, 고유 명칭과 이야기 복제, 외형의 트레이싱을 자산 파이프라인 요구사항에서 명시적으로 금지한다.

- [Blizzard End User License Agreement](https://www.blizzard.com/en-us/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement)
- [Blizzard Legal](https://www.blizzard.com/legal/)

### 18.9 시스템 목표의 현실적 단계화

“모든 시스템”은 단일 완료 항목이 아니라 호환성 수준으로 관리한다.

```text
L0 존재: 시스템 골격과 UI 진입점 존재
L1 핵심: 대표 규칙과 정상 경로 동작
L2 상호작용: 다른 시스템과 조합 동작
L3 경계: breakpoint, cap, 예외, 면역 등 검증
L4 콘텐츠: 충분한 데이터 볼륨과 진행 구조
L5 운영: 저장, 온라인 권위, 마이그레이션, 악용 방지
```

예시:

| 시스템 | 현재 추정 | 목표 |
|---|---:|---:|
| 기본 전투 | L2~L3 | L3 |
| 아이템/접사 | L2 | L4 |
| 스킬 트리/시너지 | L1~L2 | L4 |
| 제작 | L1~L2 | L4 |
| 액트/퀘스트 | L1 | L4 |
| 온라인 | L1 | L5 |
| UI/접근성 | L1~L2 | L4 |

콘텐츠의 “동일한 양”을 목표로 하지 않고, 각 시스템을 대표하는 충분한 독자 콘텐츠로 L4를 달성한다.

### 18.10 목표 방향 정당성 평가

#### 타당한 점

- D2식 시스템은 상호작용이 깊어 장기 성장·파밍 루프의 명확한 기준이 된다.
- 현대적 다크 판타지 정보 위계는 복잡한 시스템을 읽기 쉽게 만드는 데 적합하다.
- 모바일 우선 UI는 자동 습득·자동 포션·간결한 스킬 슬롯과 잘 맞는다.
- 직접 생성 자산은 라이선스, 스타일 일관성, 저사양 용량 목표에 유리하다.
- 현재 프로젝트는 이미 25Hz, 전투, 드롭, 제작, 난이도, 용병, 경제, 액트 구조를 검증해 이 방향의 기술적 기반이 있다.

#### 위험한 점

- “완전 동일”을 문자 그대로 추구하면 범위가 사실상 상용 게임 전체 재제작 수준으로 폭증한다.
- 고유 명칭·스토리·아트·음원·아이콘의 복제는 IP 위험을 만든다.
- PC 중심 정보 밀도를 모바일에 그대로 옮기면 조작성과 가독성이 무너진다.
- 생성 자산만으로 히어로·보스의 최종 품질을 확보하기 어렵다.
- 자동화가 지나치면 전리품 선택과 성장 판단이라는 핵심 재미를 약화할 수 있다.

#### 최종 판정

다음 형태라면 방향은 정당하고 실행 가능하다.

```text
시스템: D2 수준의 깊이와 상호작용을 결정론적으로 재현
콘텐츠: 동일 역할을 수행하는 독자 세계·명칭·데이터로 제작
UI: Diablo Immortal의 모바일 우선 조작·정보 배치를 참고하되 그래픽과 화면은 독자 설계
자산: 전부 직접 제작/생성하고 출처·생성 버전·라이선스를 추적
```

반대로 원작의 모든 명칭·스토리·아트·음원·테이블을 동일하게 복제하는 목표는 권장하지 않는다.

### 18.11 제품 수준 수용 기준

- [ ] 외부 게임에서 추출한 이미지·음원·폰트·코드 0개
- [ ] 모든 생성 자산에 recipe ID, generator version, 입력 해시 존재
- [ ] D2 참조 시스템마다 독립 테스트 명세 존재
- [ ] 원작 고유명 대신 프로젝트 고유 ID와 표시명 사용
- [ ] 모바일 주요 조작 hit area 48 logical px 이상
- [ ] 주 공격 hit area 72 logical px 이상
- [ ] 4:3~20:9에서 HUD 겹침 없음
- [ ] safe area 침범 없음
- [ ] UI 배율 및 큰 텍스트 모드 제공
- [ ] 색상 외의 상태 구분 수단 제공
- [ ] 저사양 기준 25Hz 논리틱과 목표 FPS 유지
- [ ] 릴리스에서 필수 디자인 자산 폴백 0
- [ ] 상업 배포 전 독립 IP 검토 완료
