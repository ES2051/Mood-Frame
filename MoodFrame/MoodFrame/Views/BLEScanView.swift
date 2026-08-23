import SwiftUI
import CoreBluetooth

/// 메인 화면의 블루투스 아이콘을 누르면 뜨는 스캔/연결 시트.
/// 실제로 CoreBluetooth로 스캔하고 연결하는 화면입니다 (겉모습만이 아님).
struct BLEScanView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusBanner

                if bleManager.discoveredDevices.isEmpty {
                    Spacer()
                    ProgressView()
                        .padding(.bottom, 8)
                    Text("주변 BLE 기기를 검색 중입니다...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("ESP32가 전원이 켜져 있고\n광고(advertising) 중인지 확인해주세요.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Spacer()
                } else {
                    List(bleManager.discoveredDevices) { device in
                        Button {
                            bleManager.connect(to: device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("RSSI \(device.rssi)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isConnecting(to: device) || isConnected(to: device) {
                                    Text(isConnected(to: device) ? "연결됨" : "연결 중...")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Theme.purple)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, 12)
            .navigationTitle("기기 연결")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        bleManager.startScanning()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                bleManager.startScanning()
            }
            .onDisappear {
                bleManager.stopScanning()
            }
        }
    }

    private func isConnecting(to device: DiscoveredDevice) -> Bool {
        if case .connecting(let name) = bleManager.state { return name == device.name }
        return false
    }

    private func isConnected(to device: DiscoveredDevice) -> Bool {
        if case .connected(let name) = bleManager.state { return name == device.name }
        return false
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch bleManager.state {
        case .poweredOff:
            bannerText("아이폰 설정에서 블루투스를 켜주세요.", color: .red)
        case .unauthorized:
            bannerText("설정 > MoodFrame 에서 블루투스 권한을 허용해주세요.", color: .red)
        case .connected(let name):
            bannerText("\(name)에 연결되었습니다.", color: .green)
        case .failed(let message):
            bannerText(message, color: .red)
        default:
            EmptyView()
        }
    }

    private func bannerText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 16)
    }
}

#Preview {
    BLEScanView(bleManager: BLEManager())
}
