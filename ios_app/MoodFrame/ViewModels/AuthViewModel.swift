import Foundation
import Combine
import CryptoKit

/// 로그인/회원가입 상태를 관리하는 뷰모델입니다.
/// 회원가입된 계정은 기기의 UserDefaults에 저장되고(비밀번호는 평문이 아닌 해시로 저장),
/// 로그인은 회원가입 때 등록한 아이디+비밀번호가 일치할 때만 성공합니다.
/// 추후 서버 로그인 API로 교체할 때는 이 클래스 내부 구현만 바꾸면 됩니다.
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String = ""

    enum SignUpError: LocalizedError {
        case emptyFields
        case idAlreadyExists

        var errorDescription: String? {
            switch self {
            case .emptyFields:
                return "아이디와 비밀번호를 입력해주세요."
            case .idAlreadyExists:
                return "이미 사용 중인 아이디입니다."
            }
        }
    }

    private let storageKey = "moodframe.registeredAccounts"

    /// [정규화된 아이디: 해시된 비밀번호]
    private var accounts: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    private func normalize(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hash(id: String, password: String) -> String {
        let digest = SHA256.hash(data: Data("\(id):\(password)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 회원가입 시도. 성공하면 계정을 저장하고 true를 반환합니다.
    /// 아이디/비밀번호가 비어있거나 이미 가입된 아이디면 에러를 던집니다.
    @discardableResult
    func signUp(id: String, password: String) throws -> Bool {
        let normalizedID = normalize(id)
        guard !normalizedID.isEmpty, !password.isEmpty else {
            throw SignUpError.emptyFields
        }
        var current = accounts
        guard current[normalizedID] == nil else {
            throw SignUpError.idAlreadyExists
        }
        current[normalizedID] = hash(id: normalizedID, password: password)
        accounts = current
        return true
    }

    /// 로그인 시도. 회원가입된 아이디와 비밀번호가 정확히 일치할 때만 true를 반환하고
    /// isLoggedIn을 true로 바꿉니다.
    func login(id: String, password: String) -> Bool {
        let normalizedID = normalize(id)
        guard !normalizedID.isEmpty, !password.isEmpty else { return false }
        guard let storedHash = accounts[normalizedID],
              storedHash == hash(id: normalizedID, password: password) else {
            return false
        }
        currentUserID = normalizedID
        isLoggedIn = true
        return true
    }

    func logout() {
        isLoggedIn = false
        currentUserID = ""
    }
}
