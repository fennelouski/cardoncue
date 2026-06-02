//
//  CardModelTests.swift
//  CardOnCueTests
//
//  Unit tests for card encryption, grouping, and geofence flattening.
//

import Foundation
import Testing
import CryptoKit
import SwiftData
@testable import CardOnCue

struct CardModelTests {

    @Test func encryptionRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let payload = "1234-5678-ABCD"
        let card = try CardModel.createWithEncryptedPayload(
            userId: "test",
            name: "Test Card",
            barcodeType: .qr,
            payload: payload,
            masterKey: key
        )
        #expect(card.payloadEncrypted.isEmpty == false)
        let decrypted = try card.decryptPayload(masterKey: key)
        #expect(decrypted == payload)
    }

    @Test func groupKeyPrefersNetworkId() throws {
        let key = SymmetricKey(size: .bits256)
        let card = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Costco Membership", barcodeType: .qr,
            payload: "x", masterKey: key, metadata: ["networkId": "net_costco"]
        )
        #expect(card.groupKey == "net_costco")
    }

    @Test func sameBrandDifferentCardholdersShareGroupKey() throws {
        let key = SymmetricKey(size: .bits256)
        let nathan = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Costco Membership", barcodeType: .qr,
            payload: "x", masterKey: key, metadata: ["personName": "Nathan"]
        )
        let sarah = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Costco", barcodeType: .qr,
            payload: "y", masterKey: key, metadata: ["personName": "Sarah"]
        )
        #expect(nathan.groupKey == sarah.groupKey)
        #expect(nathan.cardholderName == "Nathan")
        #expect(sarah.cardholderName == "Sarah")
    }

    @Test func geofenceTargetsIncludePrimaryAndAdditional() throws {
        let container = try ModelContainer(
            for: CardModel.self, CardLocation.self, SavedLocation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let key = SymmetricKey(size: .bits256)
        let card = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Costco", barcodeType: .qr, payload: "x", masterKey: key
        )
        card.locationLatitude = 40.0150
        card.locationLongitude = -105.2705
        card.locationName = "Costco Boulder"
        context.insert(card)

        let denver = CardLocation(latitude: 39.7392, longitude: -104.9903, name: "Costco Denver")
        context.insert(denver)
        denver.card = card
        try context.save()

        let targets = card.geofenceTargets
        #expect(targets.count == 2)
        #expect(targets.contains { $0.locationId == "primary" })
        #expect(targets.contains { $0.locationId == denver.id })
        // Region identifiers are "<cardId>|<locationId>".
        #expect(targets.allSatisfy { $0.id.contains("|") })
    }

    @Test func geofenceEnabledDefaultsTrueAndToggles() throws {
        let key = SymmetricKey(size: .bits256)
        let card = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Card", barcodeType: .qr, payload: "x", masterKey: key
        )
        #expect(card.isGeofenceEnabled == true)
        card.isGeofenceEnabled = false
        #expect(card.isGeofenceEnabled == false)
    }

    @Test func softDeleteHidesCardAndRestoreReveals() throws {
        let key = SymmetricKey(size: .bits256)
        let card = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Test Card", barcodeType: .qr, payload: "x", masterKey: key
        )
        #expect(card.archivedAt == nil)

        card.archivedAt = Date()
        #expect(card.archivedAt != nil, "Card should be archived after soft delete")

        card.archivedAt = nil
        #expect(card.archivedAt == nil, "Card should be visible again after restore")
    }

    @Test func permanentDeleteRemovesFromContext() throws {
        let container = try ModelContainer(
            for: CardModel.self, CardLocation.self, SavedLocation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let key = SymmetricKey(size: .bits256)
        let card = try CardModel.createWithEncryptedPayload(
            userId: "u", name: "Delete Me", barcodeType: .qr, payload: "x", masterKey: key
        )
        context.insert(card)
        try context.save()

        context.delete(card)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<CardModel>())
        #expect(remaining.isEmpty, "Card should be gone after permanent delete")
    }
}
