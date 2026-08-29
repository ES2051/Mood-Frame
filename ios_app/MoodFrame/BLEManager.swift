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

enum TagSendState: Equatable {
    case idle
    case sending
    case waitingForRender
    case succeeded
    case failed(String)
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

    // EPD_TEST_01 태그 펌웨어(ble_epd.c)의 GATT 서비스/캐릭터리스틱.
    // Mood-Frame 백엔드의 config.py와 반드시 같은 값이어야 합니다.
    static let tagServiceUUID = CBUUID(string: "7a0247e0-4b3a-4bde-9e1f-1c9b6a4f9001")
    static let tagImageCharUUID = CBUUID(string: "7a0247e1-4b3a-4bde-9e1f-1c9b6a4f9002")
    static let tagStatusCharUUID = CBUUID(string: "7a0247e2-4b3a-4bde-9e1f-1c9b6a4f9003")
    private static let imageChunkSize = 180
    private static let renderTimeoutSeconds: UInt64 = 20

    @Published private(set) var state: BLEConnectionState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var tagSendState: TagSendState = .idle

    private var centralManager: CBCentralManager!
    private var connectingPeripheral: CBPeripheral?
    private var imageCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var renderContinuation: CheckedContinuation<Bool, Never>?
    private var renderTimeoutTask: Task<Void, Never>?

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

    // MARK: - 태그로 이미지 전송

    /// EPDImagePacker.pack()으로 만든 8000바이트 이미지를 180바이트씩 나눠 태그에 씁니다.
    /// 태그가 렌더링을 끝내면 status characteristic이 notify를 보내오는데, 그걸 기다립니다.
    func sendImage(_ data: Data) {
        guard let peripheral = connectingPeripheral, let imageChar = imageCharacteristic else {
            tagSendState = .failed("연결된 태그가 없어요. 먼저 블루투스로 태그에 연결해주세요.")
            return
        }
        guard data.count == EPDImagePacker.imageSize else {
            tagSendState = .failed("이미지 크기가 올바르지 않아요.")
            return
        }

        renderTimeoutTask?.cancel()
        if let pending = renderContinuation {
            renderContinuation = nil
            pending.resume(returning: false)
        }

        tagSendState = .sending

        Task {
            var offset = 0
            while offset < data.count {
                let end = min(offset + Self.imageChunkSize, data.count)
                let chunk = data.subdata(in: offset..<end)
                peripheral.writeValue(chunk, for: imageChar, type: .withoutResponse)
                offset = end
                try? await Task.sleep(nanoseconds: 10_000_000)
            }

            await MainActor.run { self.tagSendState = .waitingForRender }

            let rendered = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                self.renderContinuation = continuation
                self.renderTimeoutTask = Task {
                    try? await Task.sleep(nanoseconds: Self.renderTimeoutSeconds * 1_000_000_000)
                    if let pending = self.renderContinuation {
                        self.renderContinuation = nil
                        pending.resume(returning: false)
                    }
                }
            }

            await MainActor.run {
                self.tagSendState = rendered ? .succeeded : .failed("태그로부터 응답이 없어요.")
            }
        }
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
        imageCharacteristic = nil
        statusCharacteristic = nil
        state = .idle
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, service.uuid == Self.tagServiceUUID, let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == Self.tagImageCharUUID {
                imageCharacteristic = characteristic
            } else if characteristic.uuid == Self.tagStatusCharUUID {
                statusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == Self.tagStatusCharUUID else { return }
        renderTimeoutTask?.cancel()
        if let pending = renderContinuation {
            renderContinuation = nil
            pending.resume(returning: true)
        }
    }
}
