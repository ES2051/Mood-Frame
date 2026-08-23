import SwiftUI

/// 디자인에서 뽑아낸 색상/그라데이션을 한 곳에 모아둔 파일입니다.
/// 실제 톤이 조금 다르면 이 파일의 색상 값만 바꾸면 앱 전체에 반영됩니다.
enum Theme {
    static let purple = Color(red: 0.55, green: 0.40, blue: 0.82)      // 진한 라벤더 퍼플
    static let pink = Color(red: 0.90, green: 0.55, blue: 0.68)        // 로즈 핑크
    static let peach = Color(red: 0.99, green: 0.72, blue: 0.55)       // 살구/오렌지 (스플래시 타이틀용)
    static let textGray = Color(red: 0.55, green: 0.52, blue: 0.60)    // 서브텍스트 그레이-퍼플

    /// 배경: 위쪽 밝은 라벤더 -> 아래쪽 은은한 핑크빛 화이트
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.94, green: 0.92, blue: 0.98),
            Color(red: 0.98, green: 0.94, blue: 0.95),
            Color(red: 0.99, green: 0.96, blue: 0.96)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 버튼/로고에 쓰는 퍼플 -> 핑크 그라데이션
    static let primaryGradient = LinearGradient(
        colors: [purple, pink],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 스플래시 타이틀 텍스트에 쓰는 퍼플 -> 핑크 -> 피치 그라데이션
    static let titleGradient = LinearGradient(
        colors: [purple, pink, peach],
        startPoint: .leading,
        endPoint: .trailing
    )
}
