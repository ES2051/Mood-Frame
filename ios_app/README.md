# MOOD FRAME - Xcode 적용 가이드

Figma 디자인(스플래시 → 로그인 → 메인 채팅) 그대로 SwiftUI로 구현했고, **블루투스(BLE) 연결만 실제로 동작**하도록 CoreBluetooth를 붙였습니다. 나머지(로그인 검증, 채팅 응답 등)는 화면만 보여주는 목업입니다.

## 포함된 파일

```
MoodFrame/
  MoodFrameApp.swift          앱 진입점
  ContentView.swift           스플래시(4초) → 로그인 → 메인 화면 전환 담당
  Theme.swift                 색상/그라데이션 모음
  BLEManager.swift            *** 실제 동작하는 CoreBluetooth 스캔/연결 로직 ***
  Views/
    SplashView.swift          1번 화면 (Mood Frame 로고 + FEEL·EXPRESS·GROW)
    LoginView.swift            2번 화면 (아이디/비밀번호 + 회원가입)
    SignUpView.swift           회원가입 화면
    MainView.swift              3번 화면 (채팅 UI + 우측 상단 블루투스 아이콘)
    BLEScanView.swift          블루투스 아이콘 탭 시 뜨는 기기 스캔/연결 시트
```

## 왜 시뮬레이터가 아니라 실제 아이폰이 필요한가요

**Xcode 시뮬레이터는 블루투스 하드웨어를 지원하지 않습니다.** BLE 스캔/연결은 반드시 실제 아이폰에서 실행해야 확인할 수 있어요. 아래 과정도 실제 기기 기준으로 안내합니다.

## 1단계. 준비물

- Mac + Xcode (최신 버전 권장, App Store에서 설치)
- 실제 아이폰 1대 (Lightning/USB-C 케이블 또는 같은 Wi-Fi로 무선 디버깅)
- 애플 ID (무료 계정으로도 기기에 앱을 설치해서 테스트할 수 있습니다. 단 7일마다 재설치 필요. 유료 개발자 계정($99/년)이면 이 제한이 없어집니다)
- ESP32 개발보드가 전원이 켜진 채로 BLE 광고(advertising) 중이어야 함

## 2단계. Xcode 프로젝트 생성

1. Xcode 실행 → `File > New > Project`
2. `iOS` 탭 → `App` 선택 → `Next`
3. Product Name: `MoodFrame` (또는 원하는 이름)
4. Interface: **SwiftUI**, Language: **Swift** 로 설정
5. 저장 위치 선택 후 `Create`

## 3단계. 소스 파일 넣기

1. Xcode 왼쪽 프로젝트 네비게이터에서 기본 생성된 `ContentView.swift`와 `〈프로젝트명〉App.swift` 파일을 **삭제**하세요 (Move to Trash)
2. Finder에서 이 zip을 풀어서 나온 `MoodFrame` 폴더 안의 모든 `.swift` 파일과 `Views` 폴더를 Xcode 프로젝트 네비게이터로 **드래그 앤 드롭**
3. 뜨는 창에서 `Copy items if needed` 체크, `Add to targets`에 본인 앱 타겟이 체크되어 있는지 확인 후 `Finish`
4. `Views` 폴더는 그룹(노란 폴더 아이콘)으로 넣어도 되고, 파일만 다 같은 레벨에 넣어도 동작에는 문제없습니다

## 4단계. 블루투스 권한 설정 (필수, 빠지면 스캔이 안 됩니다)

iOS는 블루투스를 쓰는 앱이 사용자에게 보여줄 권한 설명 문구를 반드시 요구합니다.

1. 프로젝트 네비게이터에서 최상단 프로젝트 파일 클릭 → 타겟 선택 → `Info` 탭
2. `Custom iOS Target Properties`에서 `+` 버튼으로 아래 키 추가:
   - Key: `Privacy - Bluetooth Always Usage Description`
     Value: `기기 연결을 위해 블루투스를 사용합니다.`
   - Key: `Privacy - Bluetooth Peripheral Usage Description`
     Value: `기기 연결을 위해 블루투스를 사용합니다.`

(Info.plist를 직접 열어서 편집한다면 다음 두 줄을 추가하는 것과 같습니다.)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>기기 연결을 위해 블루투스를 사용합니다.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>기기 연결을 위해 블루투스를 사용합니다.</string>
```

이 문구가 없으면 앱이 블루투스를 스캔하려는 순간 크래시가 납니다.

## 5단계. 배포 대상(iOS 버전) 확인

- 프로젝트 타겟 → `General` 탭 → `Minimum Deployments`를 **iOS 16.0 이상**으로 설정 (NavigationStack 등을 사용하기 때문)

## 6단계. 서명(Signing) 설정 — 내 아이폰에 설치하기 위해 필요

1. 타겟 선택 → `Signing & Capabilities` 탭
2. `Automatically manage signing` 체크
3. `Team`에서 본인 애플 ID 선택 (처음이면 Xcode > Settings > Accounts에서 애플 ID 로그인 먼저)
4. Bundle Identifier가 겹치면 에러가 나니, 뒤에 본인 이름 등을 붙여 고유하게 변경 (예: `com.taeyoung.moodframe`)

## 7단계. 아이폰에 연결해서 실행

1. 아이폰을 케이블로 Mac에 연결 (처음 연결 시 아이폰에서 "이 컴퓨터를 신뢰하시겠습니까?" 팝업 → 신뢰함)
2. Xcode 상단 실행 대상(시뮬레이터 이름이 적힌 부분)을 클릭해서 본인 아이폰으로 변경
3. 아이폰에서 처음 앱을 설치하면 "신뢰하지 않는 개발자" 경고가 뜰 수 있음 → 아이폰 `설정 > 일반 > VPN 및 기기 관리`에서 본인 개발자 프로필(애플 ID) 신뢰 처리
4. Xcode에서 ▶ 실행(Run) 버튼 클릭 (Cmd+R)
5. 앱이 설치되고 실행되면: 스플래시(4초) → 로그인 화면(아이디/비밀번호 아무거나 입력하면 통과) → 메인 채팅 화면

## 8단계. BLE 연결 테스트

1. ESP32 보드 전원을 켜서 BLE 광고 상태로 둡니다
2. 앱 첫 실행 시 블루투스 권한 팝업이 뜨면 **허용**
3. 메인 화면 우측 상단 블루투스 아이콘 탭 → "기기 연결" 시트가 뜨며 자동으로 스캔 시작
4. 목록에 ESP32가 나타나면 탭 → "연결됨" 표시로 바뀌면 성공
5. 상단 블루투스 아이콘도 연결되면 색이 채워진 형태로 바뀝니다

### 잘 안 될 때 체크리스트

- 시뮬레이터로 실행 중이라면 절대 안 됩니다. 실제 아이폰인지 확인
- 아이폰 설정 > 블루투스가 켜져 있는지 확인
- 4단계의 Info.plist 권한 문구를 빠뜨리지 않았는지 확인 (빠지면 앱이 스캔 시도 시 강제 종료됩니다)
- ESP32가 이미 다른 기기(다른 폰, 컴퓨터)에 연결되어 있으면 광고를 멈추는 경우가 많습니다. 다른 연결을 끊고 다시 시도
- 앱을 백그라운드로 보내면 스캔이 일시 정지됩니다 (지금 구현은 포그라운드 스캔 기준)

## 다음 단계 (참고)

- `BLEManager.swift` 상단의 `esp32ServiceUUID`에 ESP32 쪽에서 사용하는 Service UUID를 넣으면, 주변의 모든 BLE 기기가 아니라 ESP32만 필터링해서 보여줄 수 있습니다
- 연결 후 실제 데이터를 주고받으려면 `BLEManager.swift`의 `peripheral(_:didDiscoverCharacteristicsFor:)`에서 원하는 Characteristic을 찾아 `readValue` / `setNotifyValue(true, for:)`를 호출하면 됩니다
- 로그인/회원가입은 지금 더미 로직(`AuthViewModel.swift`)이라 아이디·비밀번호를 아무거나 넣어도 통과합니다. 실제 서버 인증이 필요하면 이 파일만 교체하면 됩니다
