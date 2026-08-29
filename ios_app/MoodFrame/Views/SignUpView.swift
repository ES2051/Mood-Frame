import SwiftUI

/// 회원가입 화면. 로그인 화면의 "회원가입" 링크에서 진입합니다.
struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var id: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var message: String = ""

    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("회원가입")
                    .font(.custom("Georgia-BoldItalic", size: 26))
                    .foregroundStyle(Theme.primaryGradient)
                    .padding(.top, 40)

                VStack(spacing: 14) {
                    TextField("아이디를 입력하세요", text: $id)
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("비밀번호를 입력하세요", text: $password)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("비밀번호를 다시 입력하세요", text: $passwordConfirm)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 28)

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    guard password == passwordConfirm else {
                        message = "비밀번호가 일치하지 않습니다."
                        return
                    }
                    if authViewModel.signUp(id: id, password: password) {
                        dismiss()
                    } else {
                        message = "아이디와 비밀번호를 입력해주세요."
                    }
                } label: {
                    Text("가입 완료")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)

                Spacer()
            }
        }
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
