# Android 네이티브 출시 검증 조건

기준일: 2026-09-23
대상 프로젝트: `prototype/game_dungeon`

현재 저장소의 Web/PWA 출시는 자동 검증할 수 있지만 Android APK/AAB 출시는 이 개발 환경의 외부 도구가 준비되지 않아 아직 PASS로 판정하지 않는다.

## 현재 확인된 외부 의존성

- Godot 4.7.2 Android export templates
- JDK 17과 `java`, `keytool`
- Android SDK, platform-tools(`adb`), platform 및 build-tools
- Godot Editor Settings에 설정한 Java SDK/Android SDK 경로
- 배포 서명용 keystore와 별도 관리되는 비밀 값

`ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`이 현재 비어 있고, PATH에서도 `adb`, `java`, `keytool`을 찾을 수 없다. 설치된 Godot export template에는 Web 템플릿만 확인됐다.

## 완료 판정 기준

아래 조건을 모두 실제 산출물과 기기 로그로 확인해야 Android 출시 검증을 PASS로 변경한다.

1. 현재 Godot 버전과 정확히 일치하는 Android export template 설치
2. release AAB와 테스트용 APK의 오류 없는 export
3. APK를 지원 최소 사양 실기기에 설치하고 첫 실행 성공
4. 전투, 이동, 인벤토리, 저장/불러오기, 화면 회전 정책, safe area 입력 확인
5. pause, focus-out, OS 강제 종료 후 재실행에서 원자적 저장과 백업 복구 확인
6. 저사양 기기 성능, 발열, 메모리 및 장시간 플레이 측정
7. release keystore 서명, 버전 코드, 패키지 ID 및 스토어 요구사항 확인

도구 설치 후 export preset을 추가하고 다음 형태로 검증한다.

```powershell
godot_console --headless --path prototype/game_dungeon --export-release "Android" build_android/ashen-depths.apk
adb install -r build_android/ashen-depths.apk
```

Web/PWA 성공은 Android 네이티브 성공의 대체 증거로 사용하지 않는다.
