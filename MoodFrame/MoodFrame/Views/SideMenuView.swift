import SwiftUI

enum MenuItem: String, Identifiable, Hashable {
    case gallery = "이미지 저장"
    case records = "기록"
    case diary = "일기장"
    case calendar = "캘린더"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gallery: return "photo.on.rectangle"
        case .records: return "list.bullet.rectangle"
        case .diary: return "book.closed"
        case .calendar: return "calendar"
        }
    }
}

/// 왼쪽 상단 햄버거 버튼을 누르면 나오는 사이드 메뉴.
/// 화면 왼쪽에서 슬라이드되어 나오는 커스텀 드로어입니다.
struct SideMenuView: View {
    @Binding var isShowing: Bool
    var onSelect: (MenuItem) -> Void
    var onLogout: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // 뒷 배경 어둡게 + 탭하면 닫힘
            if isShowing {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            // 실제 메뉴 패널
            if isShowing {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mood Frame")
                            .font(.custom("Georgia-BoldItalic", size: 22))
                            .foregroundStyle(Theme.primaryGradient)
                        Text("메뉴")
                            .font(.caption)
                            .foregroundColor(Theme.textGray)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    ForEach([MenuItem.gallery, .records, .diary, .calendar]) { item in
                        Button {
                            onSelect(item)
                            close()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(Theme.purple)
                                    .frame(width: 26)
                                Text(item.rawValue)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        }
                    }

                    Spacer()

                    Divider().padding(.horizontal, 24)

                    Button {
                        close()
                        onLogout()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 26)
                            Text("로그아웃")
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
                .frame(width: 260, alignment: .leading)
                .frame(maxHeight: .infinity)
                .background(Color.white)
                .ignoresSafeArea()
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowing)
    }

    private func close() {
        isShowing = false
    }
}
