# 세이브(P10) 심화 — 저장/로드

캐릭터/인벤토리/진행을 JSON으로 직렬화·복원. 로드맵 마지막 시스템 갭.

## 실행 / 검증
```
godot --path . --rendering-driver opengl3 -- barb    # S=저장, L=불러오기
godot --headless --path . --quit                     # 세이브 라운드트립 자체검증
```

## 직렬화 대상 (`_gather_state`/`_apply_state`)
- 캐릭터: class, level, xp, 스탯(str/dex/vit/energy), 스탯/스킬 포인트
- skills(id→level), inventory(아이템 dict 배열), equipped(weapon/armor)
- 진행: kills

## 저장소 (`save.gd`)
- `user://savegame.json` (OS별 사용자 경로, 헤드리스도 기록)
- `JSON.stringify`/`JSON.parse_string`. 아이템은 이미 순수 dict라 그대로 직렬화.

## 실측 (2026-09-20, HD 4000)
```
save→load: level=7 str=44 bash=5 inv=1 kills=12
apply 라운드트립: 변조후 로드 → level=7 str=44 bash=5 = true
[SV][RESULT] save_selftest verdict=PASS
게임 중 저장→로드 save_roundtrip=true, verdict=PASS
```

## 정식화
- 다중 세이브 슬롯, 하드코어(사망 시 삭제), 자동저장, 버전 마이그레이션
- 월드/던전 시드·진행 저장, 클라우드(온라인 캐릭터는 서버 영속화 P11)
- 무결성(체크섬)·손상 복구
