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

/// 일기장 한 편 (생성된 이미지를 저장하면 imageData가 함께 채워집니다)
struct DiaryEntry: Identifiable {
    let id = UUID()
    let date: Date
    var title: String
    var content: String
    var imageData: Data? = nil
}

/// 저장된 이미지의 출처. 하루 3회 제한은 "채팅에서 생성된 이미지 저장"에만 적용됩니다.
enum SavedImageSource: Equatable {
    case generated  // 채팅에서 생성 -> 확인창에서 "저장"을 선택한 경우
    case library    // 사진 앱에서 직접 고른 경우
}

/// 이미지 저장 한 건 (날짜/시간 + 출처 포함)
struct SavedImage: Identifiable {
    let id = UUID()
    let date: Date
    let data: Data
    let source: SavedImageSource
}

/// 앱 전체에서 공유하는 데이터 저장소.
/// "기록 / 일기장 / 캘린더 / 이미지 저장"이 같은 데이터를 보고 쓸 수 있도록 한 곳에서 관리합니다.
final class MoodStore: ObservableObject {
    @Published var moodRecords: [MoodRecord] = []
    @Published var diaryEntries: [DiaryEntry] = []
    @Published var savedImages: [SavedImage] = []

    /// 채팅에서 생성된 이미지는 하루 최대 이 횟수까지만 저장할 수 있습니다.
    let dailyImageSaveLimit = 3

    private var calendar: Calendar { Calendar.current }

    func addMoodRecord(emoji: String, label: String, note: String) {
        moodRecords.insert(MoodRecord(date: Date(), emoji: emoji, label: label, note: note), at: 0)
    }

    func addDiaryEntry(title: String, content: String, imageData: Data? = nil) {
        diaryEntries.insert(DiaryEntry(date: Date(), title: title, content: content, imageData: imageData), at: 0)
    }

    /// 특정 날짜에 "생성된 이미지"를 저장한 횟수 (기본값: 오늘). 하루 저장 제한 확인용입니다.
    func generatedImageSaveCount(on date: Date = Date()) -> Int {
        savedImages.filter { $0.source == .generated && calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    /// 오늘 생성된 이미지를 하나 더 저장할 수 있는지 여부 (하루 최대 dailyImageSaveLimit회)
    var canSaveGeneratedImageToday: Bool {
        generatedImageSaveCount() < dailyImageSaveLimit
    }

    /// 오늘 더 저장할 수 있는 횟수
    var remainingGeneratedImageSavesToday: Int {
        max(0, dailyImageSaveLimit - generatedImageSaveCount())
    }

    /// 채팅에서 생성된 이미지를 사용자가 "저장"하기로 선택했을 때 호출합니다.
    /// 현재 날짜/시간과 함께 이미지 + 간단한 일기 내용이 일기장에 저장됩니다.
    /// 하루 저장 제한(dailyImageSaveLimit)에 도달한 경우 아무것도 저장하지 않고 false를 반환합니다.
    @discardableResult
    func saveGeneratedImage(_ data: Data, title: String, diaryContent: String) -> Bool {
        guard canSaveGeneratedImageToday else { return false }
        let now = Date()
        savedImages.append(SavedImage(date: now, data: data, source: .generated))
        diaryEntries.insert(DiaryEntry(date: now, title: title, content: diaryContent, imageData: data), at: 0)
        return true
    }

    /// 사진 앱에서 직접 고른 이미지를 추가합니다. (하루 3회 제한과는 무관)
    func addLibraryImage(_ data: Data) {
        savedImages.append(SavedImage(date: Date(), data: data, source: .library))
    }

    /// 특정 날짜(일 단위)에 해당하는 감정 기록들
    func records(on date: Date) -> [MoodRecord] {
        moodRecords.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// 특정 날짜(일 단위)에 해당하는 일기들
    func diaryEntries(on date: Date) -> [DiaryEntry] {
        diaryEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
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
