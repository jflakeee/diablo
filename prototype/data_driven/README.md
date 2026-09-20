# 데이터 구동 (Data-Driven) — 콘텐츠 = 데이터

통합본을 **data-driven**으로 전환. 몬스터/아이템 베이스/접사를 `data/*.json`에서 로드.
콘텐츠 추가 = **JSON 편집**(코드 변경 불필요). 정식화의 토대(검증 상태 §5-2).

## 데이터 파일
- `data/monsters.json` — 몬스터 정의(스탯·AI kind·스폰 위치) → 스폰에 직접 사용
- `data/item_bases.json` — 무기/방어구 베이스
- `data/affixes.json` — prefix/suffix 테이블

## 로더 (`data.gd`)
`FileAccess` + `JSON.parse_string`로 읽어 배열/딕셔너리로 노출. 실패 시 push_error + 빈 기본값.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3 -- barb            # 플레이
godot --path . --rendering-driver opengl3 -- autoquit barb   # 검증
godot --headless --path . --quit                             # 데이터 로드 자체검증만
```

## 실측 (2026-09-20, HD 4000)
```
data loaded — monsters=6 weapons=3 armor=3 prefixes=6 suffixes=6   selftest=PASS
barbarian kills=2 boss_hp=455/500 (monsters from JSON)            verdict=PASS
```
→ 몬스터가 JSON에서 로드·스폰·전투, 런타임 에러 0.

## 다음 (파이프라인 확장)
- `item.gd`의 const 테이블 → `item_bases.json`/`affixes.json` 소비로 전환(현재 로더는 준비됨)
- 스킬/룬워드/보석/유니크 JSON화, 원본 `*.txt` → JSON 변환 툴
- 스키마 검증(필수 필드·타입), 핫리로드
