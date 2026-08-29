import SwiftUI

/// 로그인 화면.
/// 상단 로고 + "Mood Frame" 타이틀, 중앙에 아이디/비밀번호 입력, 로그인 버튼, 하단 회원가입 링크.
struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var id: String = ""
    @State private var password: String = ""
    @State private var showError: Bool = false
    @State private var goToSignUp: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Theme.primaryGradient)
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Image(systemName: "camera.macro")
                                        .font(.system(size: 34))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: Theme.purple.opacity(0.3), radius: 12, y: 6)

                            Text("Mood Frame")
                                .font(.custom("Georgia-BoldItalic", size: 32))
                                .foregroundStyle(Theme.primaryGradient)

                            Text("감정을 기록하세요")
                                .font(.subheadline)
                                .foregroundColor(Theme.textGray)
                        }
                        .padding(.top, 60)

                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("아이디")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.primary)
                                TextField("아이디를 입력하세요", text: $id)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .padding(14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("비밀번호")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.primary)
                                SecureField("비밀번호를 입력하세요", text: $password)
                                    .padding(14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if showError {
                                Text("아이디 또는 비밀번호를 확인해주세요.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            Button {
                                let success = authViewModel.login(id: id, password: password)
                                showError = !success
                            } label: {
                                Text("로그인")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.primaryGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.top, 4)

                            HStack {
                                Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 1)
                                Text("or")
                                    .font(.caption)
                                    .foregroundColor(Theme.textGray)
                                Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 1)
                            }
                            .padding(.top, 8)

                            HStack {
                                Spacer()
                                Text("계정이 없으신가요?")
                                    .font(.footnote)
                                    .foregroundColor(Theme.textGray)
                                Button {
                                    goToSignUp = true
                                } label: {
                                    HStack(spacing: 2) {
                                        Text("회원가입").font(.footnote.weight(.semibold))
                                        Image(systemName: "chevron.right").font(.caption2)
                                    }
                                    .foregroundColor(Theme.purple)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 28)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationDestination(isPresented: $goToSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
