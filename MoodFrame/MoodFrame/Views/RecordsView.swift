import SwiftUI

/// 사이드 메뉴 "기록" — 지금까지 남긴 감정 기록을 최신순으로 보여줍니다.
struct RecordsView: View {
    @EnvironmentObject var moodStore: MoodStore

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            if moodStore.moodRecords.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(moodStore.moodRecords) { record in
                            HStack(alignment: .top, spacing: 14) {
                                Text(record.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(Color.white)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.label)
                                        .font(.body.weight(.semibold))
                                    Text(record.note)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(dateFormatter.string(from: record.date))
                                        .font(.caption2)
                                        .foregroundColor(Theme.textGray)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("아직 기록이 없어요")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        RecordsView().environmentObject(MoodStore())
    }
}
