import Foundation
import SwiftUI
import Combine

/// 감정 기록 한 건 (채팅에서 감정을 선택/입력하면 여기에 쌓입니다)
struct MoodRecord: Identifiable {
    let id = UUID()
    let date: Date
    let emoji: String
    let label: String
    let note: String
}

/// 일기장 한 편
struct DiaryEntry: Identifiable {
    let id = UUID()
    let date: Date
    var title: String
    var content: String
}

/// 앱 전체에서 공유하는 데이터 저장소.
/// "기록 / 일기장 / 캘린더 / 이미지 저장"이 같은 데이터를 보고 쓸 수 있도록 한 곳에서 관리합니다.
final class MoodStore: ObservableObject {
    @Published var moodRecords: [MoodRecord] = []
    @Published var diaryEntries: [DiaryEntry] = []
    @Published var savedImages: [Data] = []

    func addMoodRecord(emoji: String, label: String, note: String) {
        moodRecords.insert(MoodRecord(date: Date(), emoji: emoji, label: label, note: note), at: 0)
    }

    func addDiaryEntry(title: String, content: String) {
        diaryEntries.insert(DiaryEntry(date: Date(), title: title, content: content), at: 0)
    }

    /// 특정 날짜(일 단위)에 해당하는 감정 기록들
    func records(on date: Date) -> [MoodRecord] {
        let calendar = Calendar.current
        return moodRecords.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// 특정 날짜(일 단위)에 해당하는 일기들
    func diaryEntries(on date: Date) -> [DiaryEntry] {
        let calendar = Calendar.current
        return diaryEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// 감정 기록이 하나라도 있는 날짜들 (캘린더에 점 표시용)
    var datesWithRecords: Set<DateComponents> {
        let calendar = Calendar.current
        return Set(moodRecords.map { calendar.dateComponents([.year, .month, .day], from: $0.date) })
    }

    /// 일기가 하나라도 있는 날짜들 (캘린더에 점 표시용)
    var datesWithDiaryEntries: Set<DateComponents> {
        let calendar = Calendar.current
        return Set(diaryEntries.map { calendar.dateComponents([.year, .month, .day], from: $0.date) })
    }
}
