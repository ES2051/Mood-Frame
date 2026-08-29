import Foundation

struct MoodDetection: Decodable {
    let emotion: String
    let confidence: Double?
}

struct MoodSupportResource: Decodable {
    let name: String
    let contact: String
}

struct MoodResponse: Decodable {
    let type: String
    let detection: MoodDetection?
    let imageURL: String?
    let message: String?
    let resources: [MoodSupportResource]?

    enum CodingKeys: String, CodingKey {
        case type, detection, message, resources
        case imageURL = "image_url"
    }
}

enum MoodAPIError: Error {
    case badResponse
}

/// Talks to the Mood Frame Python backend (FastAPI) running on the desktop,
/// which turns a piece of text into a detected emotion and a comfort image.
final class MoodAPI {
    static let shared = MoodAPI()

    /// Local `mock_app.py` running on the Mac. Phone and Mac must be on the same Wi-Fi.
    var baseURL = URL(string: "http://172.30.1.9:8000")!

    private let session = URLSession.shared

    func requestComfort(text: String) async throws -> MoodResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("support"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["text": text])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw MoodAPIError.badResponse
        }
        return try JSONDecoder().decode(MoodResponse.self, from: data)
    }
}
