import SwiftUI
import PhotosUI

/// 사이드 메뉴 "이미지 저장" — 채팅에서 생성된 감정 이미지가 자동으로 쌓이고,
/// 사진 앱에서 직접 이미지를 골라 추가할 수도 있습니다.
struct ImageGalleryView: View {
    @EnvironmentObject var moodStore: MoodStore
    @State private var selectedItems: [PhotosPickerItem] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            if moodStore.savedImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("저장된 이미지가 없어요")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(moodStore.savedImages.enumerated()), id: \.offset) { _, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("이미지 저장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.primaryGradient)
                }
            }
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            moodStore.savedImages.append(data)
                        }
                    }
                }
                selectedItems = []
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImageGalleryView().environmentObject(MoodStore())
    }
}
