import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

/// 로그인 이후 메인 화면 (감정 기록 채팅 UI).
/// 채팅 로직 자체는 목업이지만, 우측 상단 블루투스 아이콘은 실제 BLEManager와 연결되어 있습니다.
struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var bleManager = BLEManager()

    @State private var showBLESheet = false
    @State private var showSendCommandSheet = false
    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "안녕하세요 🌸\n오늘 기분이 어떠세요? 지금 느끼는 감정을 자유롭게 이야기해 주세요.", isUser: false),
        ChatMessage(text: "오늘은 설레는 기분이에요 ✨", isUser: true),
        ChatMessage(text: "설레는 감정이군요 💜\n어떤 일이 있었나요?", isUser: false)
    ]

    private let quickMoods: [(String, String)] = [
        ("😊", "기쁨"), ("😢", "슬픔"), ("🤧", "화남"), ("😌", "평온")
    ]

    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(messages) { message in
                            chatBubble(message)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                }

                quickMoodRow

                inputBar
            }
        }
        .sheet(isPresented: $showBLESheet) {
            BLEScanView(bleManager: bleManager)
        }
        .sheet(isPresented: $showSendCommandSheet) {
            SendCommandView(bleManager: bleManager)
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack {
            Button {
                showSendCommandSheet = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.purple)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Mood Frame")
                .font(.custom("Georgia-BoldItalic", size: 22))
                .foregroundStyle(Theme.primaryGradient)

            Spacer()

            Button {
                showBLESheet = true
            } label: {
                Image(systemName: bluetoothIconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(bleManager.state.isConnected ? .white : Theme.purple)
                    .frame(width: 40, height: 40)
                    .background(
                        Group {
                            if bleManager.state.isConnected {
                                Theme.primaryGradient
                            } else {
                                Color.white.opacity(0.7)
                            }
                        }
                    )
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var bluetoothIconName: String {
        bleManager.state.isConnected ? "wifi" : "dot.radiowaves.left.and.right"
    }

    // MARK: - 채팅 말풍선

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            Text(message.text)
                .font(.body)
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if message.isUser {
                            Theme.primaryGradient
                        } else {
                            Color.white
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - 감정 빠른 선택

    private var quickMoodRow: some View {
        HStack(spacing: 10) {
            ForEach(quickMoods, id: \.1) { emoji, label in
                Button {
                    messages.append(ChatMessage(text: "오늘은 \(label) 기분이에요 \(emoji)", isUser: true))
                } label: {
                    Text("\(emoji) \(label)")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(Theme.purple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - 입력창

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("감정을 입력해보세요...", text: $inputText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())

            Button {
                guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                messages.append(ChatMessage(text: inputText, isUser: true))
                inputText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.primaryGradient)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    MainView()
        .environmentObject(AuthViewModel())
}
