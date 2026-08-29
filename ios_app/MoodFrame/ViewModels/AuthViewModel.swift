import Foundation
import Combine

/// 로그인/회원가입 상태를 관리하는 뷰모델입니다.
/// 현재는 FE 단계이므로 서버 통신 없이 더미 로직으로 동작합니다.
/// 추후 실제 로그인 API 또는 BLE 페어링 연동 시 이 부분의 내부 구현만 교체하면 됩니다.
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String = ""

    /// 로그인 시도. 성공하면 true를 반환하고 isLoggedIn을 true로 바꿉니다.
    func login(id: String, password: String) -> Bool {
        guard !id.isEmpty, !password.isEmpty else { return false }
        // TODO: 실제 로그인 API 연동 지점
        currentUserID = id
        isLoggedIn = true
        return true
    }

    func logout() {
        isLoggedIn = false
        currentUserID = ""
    }

    /// 회원가입 시도. 성공하면 true를 반환합니다.
    func signUp(id: String, password: String) -> Bool {
        guard !id.isEmpty, !password.isEmpty else { return false }
        // TODO: 실제 회원가입 API 연동 지점
        return true
    }
}
