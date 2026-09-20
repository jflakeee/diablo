# 랜덤 던전 생성 (P1 심화) — D2 "인스턴트 맵"

시드 기반 랜덤 던전 생성 + AStarGrid2D 경로탐색 + 연결성 검증.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3               # 렌더(R키: 재생성)
godot --path . --rendering-driver opengl3 -- seed=123   # 특정 시드
godot --path . --rendering-driver opengl3 -- autoquit   # 렌더 검증
godot --headless --path . --quit                        # 생성 자체검증만(3시드)
```

## 알고리즘 (Part 2 §5 근사)
1. **프리셋 룸 슬롯** 5×5, 룸당 9×9 타일(맵 45×45)
2. **스패닝 트리**(randomized DFS)로 슬롯 연결 → 완전 연결 보장(25노드→24문)
3. 각 룸 카빙(내부 바닥 + 테두리 벽), **연결된 슬롯 사이에만 문(3칸 개구) 카빙** = connectivity 매칭 근사
4. **입구** = 시작 슬롯 중심, **출구** = 트리 최심부 슬롯 중심
5. **AStarGrid2D**로 입구→출구 경로 산출

## 검증 (자체검증 = headless 가능)
- 각 시드마다: floor 타일 수 == **입구 flood-fill 도달 수** → 고립 구역 0 확인
- 입구→출구 A* 경로 길이 > 0

## 실측 (2026-09-20, HD 4000)
```
3시드: rooms=25 doors=24 floor=1369 reachable=1369 (connected) path=146~160   PASS
렌더: 45×45=2025 타일 + A* 경로, render OK, 에러 0
```

## 정식화
- 다양한 프리셋 청크(방/복도/특수룸) + 회전·엣지 패턴 매칭, 오버월드/미로/프리셋 3타입(Part 2 §5)
- 몬스터 밀도 배치, 워프 연결, 맵 크기 범위 랜덤, 미니맵
- 게임(통합본)에 연결: 고정 아레나 → 이 생성기로 교체
