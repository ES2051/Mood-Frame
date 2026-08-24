import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var imageData: Data? = nil
    var isLoading: Bool = false
}

/// 로그인 이후 메인 화면 (감정 기록 채팅 UI).
/// 텍스트를 보내면 실제 백엔드(Mood Frame API)로 감정을 분석하고, 그에 맞는 이미지를 생성해 보여줍니다.
/// 생성된 이미지와 대화 내용은 기록 / 일기장 / 캘린더 / 이미지 저장에 자동으로 남습니다.
/// 왼쪽 상단 메뉴 아이콘을 누르면 사이드 메뉴가 열리고, 뒤로가기(NavigationStack)로 채팅 화면으로 돌아올 수 있습니다.
struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var moodStore: MoodStore
    @StateObject private var bleManager = BLEManager()

    @State private var showBLESheet = false
    @State private var showSideMenu = false
    @State private var path: [MenuItem] = []
    @State private var inputText: String = ""
    @State private var activeSendMessageID: UUID?
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "안녕하세요 🌸\n오늘 기분이 어떠세요? 지금 느끼는 감정을 자유롭게 이야기해 주세요.", isUser: false)
    ]

    private let quickMoods: [(String, String)] = [
        ("😊", "기쁨"), ("😢", "슬픔"), ("🤧", "화남"), ("😌", "평온")
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $path) {
                ZStack {
                    Theme.backgroundGradient
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        topBar

                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 14) {
                                    ForEach(messages) { message in
                                        chatBubble(message)
                                            .id(message.id)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                            }
                            .onChange(of: messages.count) { _ in
                                if let lastID = messages.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastID, anchor: .bottom)
                                    }
                                }
                            }
                        }

                        quickMoodRow

                        inputBar
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MenuItem.self) { item in
                    destination(for: item)
                }
            }
            .sheet(isPresented: $showBLESheet) {
                BLEScanView(bleManager: bleManager)
            }

            SideMenuView(
                isShowing: $showSideMenu,
                onSelect: { item in path.append(item) },
                onLogout: { authViewModel.logout() }
            )
        }
    }

    @ViewBuilder
    private func destination(for item: MenuItem) -> some View {
        switch item {
        case .gallery:
            ImageGalleryView()
        case .records:
            RecordsView()
        case .diary:
            DiaryView()
        case .calendar:
            CalendarView()
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack {
            Button {
                showSideMenu = true
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

            Group {
                if message.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(message.text)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                } else if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                    VStack(spacing: 8) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220)

                        sendToTagButton(messageID: message.id, uiImage: uiImage)

                        if activeSendMessageID == message.id {
                            tagSendStatusText
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                } else {
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
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - 태그로 전송

    private func sendToTagButton(messageID: UUID, uiImage: UIImage) -> some View {
        Button {
            activeSendMessageID = messageID
            guard let packed = EPDImagePacker.pack(uiImage) else { return }
            bleManager.sendImage(packed)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("태그로 전송")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(Theme.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.purple.opacity(0.12))
            .clipShape(Capsule())
        }
        .disabled(isSendingToTag)
    }

    private var isSendingToTag: Bool {
        switch bleManager.tagSendState {
        case .sending, .waitingForRender: return true
        default: return false
        }
    }

    @ViewBuilder
    private var tagSendStatusText: some View {
        switch bleManager.tagSendState {
        case .idle:
            EmptyView()
        case .sending:
            Text("태그로 전송 중...").font(.caption2).foregroundColor(.secondary)
        case .waitingForRender:
            Text("태그가 화면을 그리는 중...").font(.caption2).foregroundColor(.secondary)
        case .succeeded:
            Text("태그에 표시했어요 ✅").font(.caption2).foregroundColor(Theme.purple)
        case .failed(let message):
            Text(message).font(.caption2).foregroundColor(.red)
        }
    }

    // MARK: - 감정 빠른 선택

    private var quickMoodRow: some View {
        HStack(spacing: 10) {
            ForEach(quickMoods, id: \.1) { emoji, label in
                Button {
                    send(text: "오늘은 \(label) 기분이에요 \(emoji)")
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
                sendMood()
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

    // MARK: - 감정 -> 이미지 요청

    private func sendMood() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        send(text: trimmed)
    }

    private func send(text: String) {
        messages.append(ChatMessage(text: text, isUser: true))
        messages.append(ChatMessage(text: "감정을 분석하고 이미지를 만들고 있어요...", isUser: false, isLoading: true))
        let loadingID = messages.last!.id

        Task {
            do {
                let response = try await MoodAPI.shared.requestComfort(text: text)

                if response.type == "support" {
                    await MainActor.run {
                        messages.removeAll { $0.id == loadingID }
                        messages.append(ChatMessage(text: response.message ?? "지금 많이 힘드시군요. 혼자가 아니에요.", isUser: false))
                        if let resources = response.resources {
                            let list = resources.map { "\($0.name) — \($0.contact)" }.joined(separator: "\n")
                            messages.append(ChatMessage(text: list, isUser: false))
                        }
                    }
                    return
                }

                guard let urlString = response.imageURL, let url = URL(string: urlString) else {
                    await MainActor.run {
                        messages.removeAll { $0.id == loadingID }
                        messages.append(ChatMessage(text: "응답을 이해하지 못했어요.", isUser: false))
                    }
                    return
                }

                let (imageData, _) = try await URLSession.shared.data(from: url)
                let rawEmotion = response.detection?.emotion ?? "neutral"
                let label = koreanLabel(for: rawEmotion)
                let emoji = emojiSymbol(for: rawEmotion)

                await MainActor.run {
                    messages.removeAll { $0.id == loadingID }
                    messages.append(ChatMessage(text: "'\(label)' 감정이 느껴지네요 \(emoji)\n감정에 어울리는 이미지를 준비했어요.", isUser: false))
                    messages.append(ChatMessage(text: "", isUser: false, imageData: imageData))

                    moodStore.addMoodRecord(emoji: emoji, label: label, note: text)
                    moodStore.addDiaryEntry(
                        title: diaryTitleFormatter.string(from: Date()),
                        content: "\(text)\n\n감지된 감정: \(label)"
                    )
                    moodStore.savedImages.append(imageData)
                }
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == loadingID }
                    messages.append(ChatMessage(text: "서버에 연결하지 못했어요: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }

    private let diaryTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일의 기록"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    private func koreanLabel(for emotion: String) -> String {
        let map: [String: String] = [
            "joy": "기쁨", "sadness": "슬픔", "anger": "화남", "fear": "두려움",
            "surprise": "놀람", "love": "사랑", "disgust": "혐오", "neutral": "평온",
            "admiration": "감탄", "amusement": "즐거움", "annoyance": "짜증", "approval": "인정",
            "caring": "다정함", "confusion": "혼란", "curiosity": "호기심", "desire": "욕구",
            "disappointment": "실망", "disapproval": "반대", "embarrassment": "당황",
            "excitement": "설렘", "gratitude": "감사", "grief": "비통함", "nervousness": "긴장",
            "optimism": "낙관", "pride": "자부심", "realization": "깨달음", "relief": "안도",
            "remorse": "후회"
        ]
        return map[emotion.lowercased()] ?? emotion
    }

    private func emojiSymbol(for emotion: String) -> String {
        let map: [String: String] = [
            "joy": "😊", "sadness": "😢", "anger": "😠", "fear": "😨",
            "surprise": "😮", "love": "🥰", "disgust": "🤢", "neutral": "😌",
            "excitement": "✨", "nervousness": "😬", "gratitude": "🙏", "relief": "😮‍💨"
        ]
        return map[emotion.lowercased()] ?? "💬"
    }
}

#Preview {
    MainView()
        .environmentObject(AuthViewModel())
        .environmentObject(MoodStore())
}
