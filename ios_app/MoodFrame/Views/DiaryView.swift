import SwiftUI

/// 사이드 메뉴 "일기장" — 짧은 글을 남기고 목록으로 다시 볼 수 있습니다.
struct DiaryView: View {
    @EnvironmentObject var moodStore: MoodStore
    @State private var showAddSheet = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            if moodStore.diaryEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("아직 쓴 일기가 없어요")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(moodStore.diaryEntries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.title)
                                        .font(.body.weight(.semibold))
                                    Spacer()
                                    Text(dateFormatter.string(from: entry.date))
                                        .font(.caption2)
                                        .foregroundColor(Theme.textGray)
                                }
                                if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 220)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Text(entry.content)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("일기장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.primaryGradient)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddDiaryEntryView { title, content in
                moodStore.addDiaryEntry(title: title, content: content)
            }
        }
    }
}

private struct AddDiaryEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
    var onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("제목을 입력하세요", text: $title)
                }
                Section("내용") {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                }
            }
            .navigationTitle("새 일기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty else { return }
                        onSave(trimmedTitle, content)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DiaryView().environmentObject(MoodStore())
    }
}
