import SwiftUI

enum AppScreen {
    case splash
    case login
    case main
}

/// 앱의 루트 뷰.
/// 1) 앱 실행 -> 스플래시 화면 4초 노출
/// 2) 4초 후 -> 로그인 화면
/// 3) 로그인 성공 -> 메인 화면
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var screen: AppScreen = .splash

    var body: some View {
        Group {
            switch screen {
            case .splash:
                SplashView()
            case .login:
                LoginView()
            case .main:
                MainView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: screen)
        .onAppear {
            // 스플래시를 4초간 보여준 뒤 로그인 화면으로 전환합니다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if screen == .splash {
                    screen = .login
                }
            }
        }
        .onChange(of: authViewModel.isLoggedIn) { isLoggedIn in
            // 로그인에 성공하면 메인 화면으로 전환합니다.
            if isLoggedIn {
                screen = .main
            } else if screen == .main {
                // 로그아웃 시 다시 로그인 화면으로.
                screen = .login
            }
        }
    }
}

extension AppScreen: Equatable {}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
