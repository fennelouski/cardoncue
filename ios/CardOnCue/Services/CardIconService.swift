import Foundation
import UIKit

enum CardIconError: Error {
    case invalidURL
    case invalidResponse
    case uploadFailed
    case deleteFailed
    case networkError(Error)
}

actor CardIconService {
    static let shared = CardIconService()

    private let baseURL = "https://www.cardoncue.com/api/v1"

    private init() {}

    func getCardIcon(cardId: String) async throws -> String {
        let endpoint = "\(baseURL)/cards/\(cardId)/icon"

        guard let url = URL(string: endpoint) else {
            throw CardIconError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CardIconError.invalidResponse
        }

        struct IconResponse: Codable {
            let iconUrl: String
        }

        let iconResponse = try JSONDecoder().decode(IconResponse.self, from: data)
        return iconResponse.iconUrl
    }

    func uploadCustomIcon(cardId: String, image: UIImage) async throws -> String {
        let endpoint = "\(baseURL)/cards/\(cardId)/icon"

        guard let url = URL(string: endpoint) else {
            throw CardIconError.invalidURL
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw CardIconError.uploadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"icon\"; filename=\"icon.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CardIconError.uploadFailed
        }

        struct UploadResponse: Codable {
            let iconUrl: String
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.iconUrl
    }

    func deleteCustomIcon(cardId: String) async throws -> String {
        let endpoint = "\(baseURL)/cards/\(cardId)/icon"

        guard let url = URL(string: endpoint) else {
            throw CardIconError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CardIconError.deleteFailed
        }

        struct DeleteResponse: Codable {
            let iconUrl: String?
        }

        let deleteResponse = try JSONDecoder().decode(DeleteResponse.self, from: data)
        return deleteResponse.iconUrl ?? ""
    }
}
