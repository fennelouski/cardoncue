import Foundation
import SwiftData
import UIKit

struct PhotoImportReviewItem: Identifiable {
    let id = UUID()
    let barcodePayload: String
    let barcodeType: BarcodeType
    let capturedImage: UIImage
    let boundingBox: CGRect?
}

enum PhotoImportProcessingResult {
    case autoSaved
    case needsReview(PhotoImportReviewItem)
    case failed
}

enum PhotoImportService {
    static let autoSaveThreshold: Float = 0.85
    static let maxSelectionCount = 50

    static func processAndSaveImage(
        _ image: UIImage,
        modelContext: ModelContext
    ) async -> PhotoImportProcessingResult {
        guard let barcode = await BarcodeQualityService.shared.detectBestBarcode(in: image) else {
            return .failed
        }

        do {
            let ocrResult = try await VisionOCRService.shared.analyzeCardImage(image)
            let parsedData = await CardDataParser.shared.parseFromVisionOCR(
                ocrResult,
                userLocation: nil
            )
            let decision = await RapidSaveService.shared.evaluateSave(
                ocrResult: ocrResult,
                parsedData: parsedData,
                batchContext: nil,
                threshold: autoSaveThreshold
            )

            if decision.shouldAutoSave {
                do {
                    try await performInstantSave(
                        barcodePayload: barcode.payload,
                        barcodeType: barcode.barcodeType,
                        cardName: decision.suggestedName,
                        capturedImage: image,
                        boundingBox: barcode.boundingBox,
                        parsedData: parsedData,
                        ocrResult: ocrResult,
                        modelContext: modelContext
                    )
                    return .autoSaved
                } catch {
                    return .needsReview(
                        PhotoImportReviewItem(
                            barcodePayload: barcode.payload,
                            barcodeType: barcode.barcodeType,
                            capturedImage: image,
                            boundingBox: barcode.boundingBox
                        )
                    )
                }
            }

            return .needsReview(
                PhotoImportReviewItem(
                    barcodePayload: barcode.payload,
                    barcodeType: barcode.barcodeType,
                    capturedImage: image,
                    boundingBox: barcode.boundingBox
                )
            )
        } catch {
            return .needsReview(
                PhotoImportReviewItem(
                    barcodePayload: barcode.payload,
                    barcodeType: barcode.barcodeType,
                    capturedImage: image,
                    boundingBox: barcode.boundingBox
                )
            )
        }
    }

    private static func performInstantSave(
        barcodePayload: String,
        barcodeType: BarcodeType,
        cardName: String,
        capturedImage: UIImage,
        boundingBox: CGRect?,
        parsedData: ParsedCardData,
        ocrResult: VisionOCRService.OCRResult,
        modelContext: ModelContext
    ) async throws {
        let keychainService = KeychainService()

        var masterKey = try keychainService.getMasterKey()
        if masterKey == nil {
            masterKey = try keychainService.generateAndStoreMasterKey()
        }

        guard let key = masterKey else {
            throw NSError(domain: "CardOnCue", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get encryption key"
            ])
        }

        let segments = OCRSegmentDetector.shared.detectSegments(from: ocrResult, parsedData: parsedData)
        let ocrData = OCRData(
            fullText: ocrResult.allText,
            segments: segments,
            confidence: ocrResult.confidence
        )

        let cardIcon = await MembershipIconResolver.shared.resolveIcon(
            cardName: cardName,
            locationName: parsedData.suggestedLocations.first?.name,
            modelContext: modelContext
        )

        let locationName: String?
        let latitude: Double?
        let longitude: Double?
        let address: String?

        if let firstLocation = parsedData.suggestedLocations.first {
            locationName = firstLocation.name
            latitude = firstLocation.coordinate?.latitude
            longitude = firstLocation.coordinate?.longitude
            address = firstLocation.address
        } else {
            locationName = nil
            latitude = nil
            longitude = nil
            address = nil
        }

        let card = try CardModel.createWithEncryptedPayload(
            userId: AppUser.id,
            name: cardName,
            barcodeType: barcodeType,
            payload: barcodePayload,
            masterKey: key,
            tags: [],
            validTo: nil,
            oneTime: false,
            iconName: cardIcon.type == .sfSymbol ? cardIcon.value : "creditcard.fill"
        )

        if let personName = parsedData.personName {
            card.metadata["personName"] = personName
        }
        card.locationName = locationName
        card.locationLatitude = latitude
        card.locationLongitude = longitude
        if let addr = address {
            card.metadata["locationAddress"] = addr
        }

        if let ocrJSON = try? JSONEncoder().encode(ocrData) {
            card.ocrDataJSON = String(data: ocrJSON, encoding: .utf8)
        }

        if let iconJSON = try? JSONEncoder().encode(cardIcon) {
            card.iconDataJSON = String(data: iconJSON, encoding: .utf8)
        }

        let imageStorage = CardImageStorageService.shared
        if let originalURL = try? imageStorage.saveImage(capturedImage, cardId: card.id, isProcessed: false) {
            card.originalImageURL = originalURL.lastPathComponent
        }

        await MainActor.run {
            modelContext.insert(card)
            PersistenceHelper.save(modelContext, label: "PhotoImportService.saveCard")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
