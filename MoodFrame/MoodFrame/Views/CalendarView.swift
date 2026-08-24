import SwiftUI

/// 사이드 메뉴 "캘린더" — 월별 캘린더에서 감정 기록/일기가 있는 날짜를 점으로 표시하고,
/// 날짜를 탭하면 그날의 감정 기록과 일기를 아래에서 볼 수 있습니다.
struct CalendarView: View {
    @EnvironmentObject var moodStore: MoodStore
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // 일요일 시작
        return cal
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    daysGrid

                    Divider().padding(.horizontal, 20)

                    selectedDayRecords
                    selectedDayDiaryEntries
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("캘린더")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 상단 월 이동

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 24)
        .foregroundColor(Theme.purple)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    // MARK: - 요일 헤더

    private var weekdayHeader: some View {
        HStack {
            ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(Theme.textGray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 날짜 그리드

    private var daysInMonthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }

    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(Array(daysInMonthGrid.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasRecord = !moodStore.records(on: date).isEmpty
        let hasDiary = !moodStore.diaryEntries(on: date).isEmpty

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.footnote.weight(isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                HStack(spacing: 3) {
                    if hasRecord {
                        Circle().fill(Theme.pink).frame(width: 5, height: 5)
                    }
                    if hasDiary {
                        Circle().fill(Theme.purple).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(width: 36, height: 36)
            .background(
                isSelected
                    ? AnyView(Circle().fill(Theme.primaryGradient))
                    : AnyView(Color.clear)
            )
        }
    }

    // MARK: - 선택한 날짜의 감정 기록

    private var selectedDayRecords: some View {
        let records = moodStore.records(on: selectedDate)
        return VStack(alignment: .leading, spacing: 10) {
            Text(dayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.textGray)
                .padding(.horizontal, 20)

            if records.isEmpty {
                Text("이 날의 감정 기록이 없어요")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(records) { record in
                        HStack(spacing: 12) {
                            Text(record.emoji).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.label).font(.footnote.weight(.semibold))
                                Text(record.note).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 선택한 날짜의 일기 (캘린더 <-> 일기장 연동)

    private var selectedDayDiaryEntries: some View {
        let entries = moodStore.diaryEntries(on: selectedDate)
        return Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("이 날의 일기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.textGray)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.title)
                                    .font(.footnote.weight(.semibold))
                                Text(entry.content)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 4)
            }
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 기록"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    NavigationStack {
        CalendarView().environmentObject(MoodStore())
    }
}
