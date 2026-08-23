import Foundation
import CoreBluetooth
import Combine

/// 스캔으로 발견된 주변 BLE 기기 한 개를 나타냅니다.
struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

enum BLEConnectionState: Equatable {
    case poweredOff          // 아이폰 블루투스가 꺼져 있음
    case unauthorized        // 앱에 블루투스 권한이 없음
    case idle                // 준비됨, 스캔 전
    case scanning            // 주변 기기 스캔 중
    case connecting(String)  // 특정 기기에 연결 시도 중
    case connected(String)   // 연결 완료 (기기 이름)
    case failed(String)      // 연결 실패 (에러 메시지)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// CoreBluetooth를 감싸는 매니저.
/// - 이 클래스는 실제로 동작하는 BLE 스캔/연결 로직입니다. (다른 화면들과 달리 "겉모습만"이 아닙니다.)
/// - ESP32 쪽에 특정 서비스/캐릭터리스틱 UUID가 정해지면, `ESP32ServiceUUID` 상수만 채워서
///   scanForPeripherals의 필터를 활성화하면 됩니다. 지금은 UUID가 없어서 "모든 BLE 기기"를 스캔합니다.
final class BLEManager: NSObject, ObservableObject {
    // 나중에 ESP32 쪽 서비스 UUID가 정해지면 여기에 넣고,
    // startScanning()에서 withServices: [ESP32ServiceUUID] 로 바꾸면 해당 기기만 필터링해서 보여줄 수 있습니다.
    static let esp32ServiceUUID: CBUUID? = nil

    // bleprph 펌웨어(gatt_svr.c)에 정의된 커맨드용 캐릭터리스틱 UUID.
    // 이 캐릭터리스틱에 0x01을 쓰면 ESP32가 EPD 갱신을 트리거합니다.
    static let commandCharacteristicUUID = CBUUID(string: "33333333-2222-2222-1111-111100000000")

    @Published private(set) var state: BLEConnectionState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    /// 연결된 기기에서 커맨드 캐릭터리스틱을 찾아서 write할 준비가 됐는지 여부.
    @Published private(set) var canSendCommand: Bool = false

    private var centralManager: CBCentralManager!
    private var connectingPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var pendingSendCompletion: ((Bool) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        discoveredDevices.removeAll()
        guard centralManager.state == .poweredOn else {
            syncStateFromManager()
            return
        }
        state = .scanning
        let services = BLEManager.esp32ServiceUUID.map { [$0] }
        centralManager.scanForPeripherals(withServices: services, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = state {
            state = .idle
        }
    }

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectingPeripheral = device.peripheral
        state = .connecting(device.name)
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectingPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    /// 연결된 기기의 커맨드 캐릭터리스틱에 1바이트 값을 씁니다.
    /// (bleprph 쪽 `gatt_svc_access`의 WRITE_CHR 분기가 이 값을 받습니다. 0x01 = EPD 기본 이미지 표시)
    /// - completion: write 성공/실패를 알려줍니다. 메인 스레드에서 호출됩니다.
    func sendCommand(_ value: UInt8, completion: ((Bool) -> Void)? = nil) {
        guard let peripheral = connectingPeripheral,
              let characteristic = commandCharacteristic else {
            completion?(false)
            return
        }

        pendingSendCompletion = completion
        let data = Data([value])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func syncStateFromManager() {
        switch centralManager.state {
        case .poweredOff:
            state = .poweredOff
        case .unauthorized:
            state = .unauthorized
        default:
            state = .idle
        }
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        syncStateFromManager()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "이름 없는 기기"

        let device = DiscoveredDevice(id: peripheral.identifier, peripheral: peripheral, name: name, rssi: RSSI.intValue)

        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        state = .connected(peripheral.name ?? "연결된 기기")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed(error?.localizedDescription ?? "연결에 실패했습니다.")
        connectingPeripheral = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectingPeripheral = nil
        commandCharacteristic = nil
        canSendCommand = false
        state = .idle
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // 모든 서비스에서 캐릭터리스틱을 탐색합니다. 커맨드 캐릭터리스틱은
        // didDiscoverCharacteristicsFor에서 UUID로 찾아 저장합니다.
        guard error == nil, let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }

        // UUID가 정확히 일치하는 커맨드 캐릭터리스틱을 우선 사용.
        if let match = characteristics.first(where: { $0.uuid == BLEManager.commandCharacteristicUUID }) {
            commandCharacteristic = match
            canSendCommand = true
            return
        }

        // 펌웨어가 다르거나 UUID가 조금 다를 때를 위한 대비: write 가능한 캐릭터리스틱을 대신 사용.
        if commandCharacteristic == nil,
           let fallback = characteristics.first(where: {
               $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
           }) {
            commandCharacteristic = fallback
            canSendCommand = true
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let completion = pendingSendCompletion
        pendingSendCompletion = nil
        completion?(error == nil)
    }
}
