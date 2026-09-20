# Phase 7 — 온라인 (계정 / 동기화 / 거래)

디아블로2 클론 Phase 7: 온라인 레이어(P11 계정 / P12 동기화 / P13 거래) 최소 프로토타입.
Godot 고수준 멀티플레이(ENet), **서버 권위(authoritative) 에스크로 거래**.

## 실행 (두 프로세스)
```
# 터미널 1 (서버)
godot --headless --path . -- server
# 터미널 2 (클라이언트)
godot --headless --path . -- client
```

## 흐름 (검증됨)
1. 서버 `create_server(8910)` 리슨
2. 클라 `create_client(127.0.0.1:8910)` 접속 → 계정 로그인(P11)
3. 클라 → 서버 위치 동기화 RPC(P12)
4. 클라 → 서버 거래 요청 → **서버가 에스크로 검증** → 서버 → 클라 결과 RPC(P13)

## 설계 근거
- **거래 = 서버 권위 에스크로**: 카오스큐브(수동 쪽지 중개, Part 1 §7.1)의 개선판.
  아이템 소유·교환을 서버가 원자적으로 검증 → 사기 방지.
- 싱글 우선 → 온라인 후반 도입(로드맵 §3)과 정합. 클라 게임 로직(Phase0~6)은 그대로,
  네트워크 레이어만 위에 얹음.

## 실측 (2026-09-20, HD 4000, 헤드리스 2 프로세스)
```
server: peer connected → pos sync (12.5,8.0) → trade escrow OK   verdict=PASS
client: connected → trade result ok=true 'Steel Short Sword'      verdict=PASS
```

## 정식화 (P11~P13)
- 계정 DB·인증, 캐릭터 영속화(서버 세이브), 상태 동기화 최적화(관심영역/보간),
  거래 UI·시세(카오스큐브식), 채팅, 파티/협동, 안티치트.
