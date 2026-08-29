import SwiftUI

/// 채팅 화면과는 별개의, "전송" 버튼 하나로 연결된 기기에 0x01 명령을 보내는 화면.
/// bleprph 펌웨어의 gatt_svc_access(WRITE_CHR)가 0x01을 받으면 EPD 기본 이미지 갱신을 트리거합니다.
struct SendCommandView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss

    @State private var resultMessage: String?
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    statusBanner

                    Spacer()

                    Button {
                        send()
                    } label: {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("전송")
                                .font(.title3.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            bleManager.canSendCommand
                                ? Theme.primaryGradient
                                : LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(!bleManager.canSendCommand || isSending)
                    .padding(.horizontal, 24)

                    if let resultMessage {
                        Text(resultMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("명령 전송")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var statusBanner: some View {
        Group {
            if bleManager.canSendCommand {
                Text("기기와 연결되어 있습니다. 전송 버튼을 누르면 0x01 값이 전달됩니다.")
                    .foregroundColor(.green)
            } else {
                Text("연결된 기기가 없습니다.\n먼저 블루투스 아이콘에서 기기를 연결해주세요.")
                    .foregroundColor(.secondary)
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func send() {
        isSending = true
        resultMessage = nil

        bleManager.sendCommand(0x01) { success in
            isSending = false
            resultMessage = success ? "0x01 전송 완료" : "전송 실패, 연결 상태를 확인해주세요."
        }
    }
}

#Preview {
    SendCommandView(bleManager: BLEManager())
}
