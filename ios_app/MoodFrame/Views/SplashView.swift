import SwiftUI

/// 앱 실행 시 가장 먼저 보이는 스플래시 화면.
/// 화면 전환(로그인 화면으로 이동)은 ContentView에서 4초 타이머로 처리합니다.
struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "leaf.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.titleGradient)
                    .padding(.bottom, 4)

                VStack(spacing: 4) {
                    Text("Mood")
                        .font(.custom("Georgia-BoldItalic", size: 56))
                        .foregroundStyle(Theme.titleGradient)

                    Text("Frame")
                        .font(.custom("Georgia-BoldItalic", size: 56))
                        .foregroundStyle(Theme.titleGradient)
                }

                Text("FEEL · EXPRESS · GROW")
                    .font(.system(size: 13, weight: .medium))
                    .kerning(2)
                    .foregroundColor(Theme.textGray)
                    .padding(.top, 4)

                HStack(spacing: 6) {
                    Circle().fill(Theme.textGray.opacity(0.3)).frame(width: 6, height: 6)
                    Capsule().fill(Theme.primaryGradient).frame(width: 20, height: 6)
                    Circle().fill(Theme.textGray.opacity(0.3)).frame(width: 6, height: 6)
                }
                .padding(.top, 20)

                Spacer()
                Spacer()

                Text("당신의 감정을 담는 공간")
                    .font(.footnote)
                    .foregroundColor(Theme.textGray)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    SplashView()
}
