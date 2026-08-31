import SwiftUI
import PhotosUI

/// 사이드 메뉴 "이미지 저장" — 채팅에서 생성된 감정 이미지가 자동으로 쌓이고,
/// 사진 앱에서 직접 이미지를 골라 추가할 수도 있습니다.
struct ImageGalleryView: View {
    @EnvironmentObject var moodStore: MoodStore
    @EnvironmentObject var bleManager: BLEManager
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImage: SavedImage?

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
                        ForEach(moodStore.savedImages) { saved in
                            if let uiImage = UIImage(data: saved.data) {
                                Button {
                                    selectedImage = saved
                                } label: {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
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
                            moodStore.addLibraryImage(data)
                        }
                    }
                }
                selectedItems = []
            }
        }
        .sheet(item: $selectedImage) { saved in
            GalleryImageDetailSheet(savedImage: saved, bleManager: bleManager)
        }
    }
}

/// 갤러리에서 이미지를 고르면 뜨는 화면 — 큰 미리보기와 함께 "태그로 전송" 버튼을 제공합니다.
/// MainView의 채팅 이미지 전송과 동일한 EPDImagePacker + BLEManager 경로를 그대로 사용합니다.
private struct GalleryImageDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let savedImage: SavedImage
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 20) {
                    if let uiImage = UIImage(data: savedImage.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                            .padding(.horizontal, 24)

                        sendToTagButton(uiImage: uiImage)

                        tagSendStatusText
                    }

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("이미지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func sendToTagButton(uiImage: UIImage) -> some View {
        Button {
            guard let packed = EPDImagePacker.pack(uiImage) else { return }
            bleManager.sendImage(packed)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("태그로 전송")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSendingToTag
                    ? LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                    : Theme.primaryGradient
            )
            .clipShape(Capsule())
        }
        .disabled(isSendingToTag)
        .padding(.horizontal, 24)
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
            Text("태그로 전송 중...").font(.footnote).foregroundColor(.secondary)
        case .waitingForRender:
            Text("태그가 화면을 그리는 중...").font(.footnote).foregroundColor(.secondary)
        case .succeeded:
            Text("태그에 표시했어요 ✅").font(.footnote).foregroundColor(Theme.purple)
        case .failed(let message):
            Text(message).font(.footnote).foregroundColor(.red)
        }
    }
}

#Preview {
    NavigationStack {
        ImageGalleryView()
            .environmentObject(MoodStore())
            .environmentObject(BLEManager())
    }
}
