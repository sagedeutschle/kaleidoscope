import Foundation
import XCTest
import PrismetShared

final class PrismetSaveEnvelopeTests: XCTestCase {
    func testCodecRoundTripRetainsOpaquePayloadBytesExactly() throws {
        let envelope = try makeEnvelope()

        let encoded = try PrismetSaveEnvelopeCodec.encode(envelope)
        let decoded = try PrismetSaveEnvelopeCodec.decode(encoded)

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(decoded.payload, Data([0x00, 0xff, 0x7b]))
    }

    func testCodecEncodingIsDeterministicForSameValue() throws {
        let envelope = try makeEnvelope()

        XCTAssertEqual(
            try PrismetSaveEnvelopeCodec.encode(envelope),
            try PrismetSaveEnvelopeCodec.encode(envelope)
        )
    }

    func testVersionTwoIsStructurallyValidButUnsupported() throws {
        let current = try makeEnvelope(envelopeVersion: 1)
        let future = try makeEnvelope(envelopeVersion: 2)

        XCTAssertEqual(PrismetSaveEnvelope.currentEnvelopeVersion, 1)
        XCTAssertTrue(current.isSupportedEnvelopeVersion)
        XCTAssertFalse(future.isSupportedEnvelopeVersion)
        XCTAssertEqual(
            try PrismetSaveEnvelopeCodec.decode(PrismetSaveEnvelopeCodec.encode(future)),
            future
        )
    }

    func testWrappingLegacyPayloadDoesNotInspectOrAlterInvalidBytes() throws {
        let invalidUTF8AndJSON = Data([0x00, 0xff, 0x7b])

        let envelope = try PrismetSaveEnvelope.wrappingLegacyPayload(
            invalidUTF8AndJSON,
            payloadSchemaVersion: 7,
            featureID: .chess,
            scope: PrismetStorageScope(kind: .device, identifier: deviceID),
            slotID: slotID,
            score: nil,
            modifiedAt: modifiedAt,
            deviceMutationID: mutationID,
            sourcePlatform: .macOS
        )

        XCTAssertEqual(envelope.envelopeVersion, PrismetSaveEnvelope.currentEnvelopeVersion)
        XCTAssertEqual(envelope.payload, invalidUTF8AndJSON)
        XCTAssertEqual(
            try PrismetSaveEnvelopeCodec.decode(PrismetSaveEnvelopeCodec.encode(envelope)).payload,
            invalidUTF8AndJSON
        )
    }

    func testDeviceAndBackendScopesRemainDistinctForSameIdentifier() throws {
        let deviceEnvelope = try makeEnvelope(
            scope: PrismetStorageScope(kind: .device, identifier: deviceID)
        )
        let backendEnvelope = try makeEnvelope(
            scope: PrismetStorageScope(kind: .backendAccount, identifier: deviceID)
        )

        XCTAssertNotEqual(deviceEnvelope.scope, backendEnvelope.scope)
        XCTAssertNotEqual(deviceEnvelope, backendEnvelope)
    }

    func testSlotIDRejectsWhitespaceOnlyValue() throws {
        let envelope = try PrismetSaveEnvelope(
            envelopeVersion: 1,
            payloadSchemaVersion: 7,
            featureID: .chess,
            scope: PrismetStorageScope(kind: .device, identifier: deviceID),
            slotID: slotID,
            score: nil,
            modifiedAt: modifiedAt,
            deviceMutationID: mutationID,
            sourcePlatform: .macOS,
            payload: Data([0x00, 0xff, 0x7b])
        )
        XCTAssertEqual(envelope.slotID, slotID)

        XCTAssertThrowsError(
            try PrismetSaveEnvelope(
                envelopeVersion: 1,
                payloadSchemaVersion: 7,
                featureID: .chess,
                scope: PrismetStorageScope(kind: .device, identifier: deviceID),
                slotID: "   ",
                score: nil,
                modifiedAt: modifiedAt,
                deviceMutationID: mutationID,
                sourcePlatform: .macOS,
                payload: Data([0x00, 0xff, 0x7b])
            )
        ) { error in
            XCTAssertEqual(error as? PrismetSaveEnvelopeValidationError, .emptySlotID)
        }
    }

    func testInitializerRejectsOnlyNonPositiveEnvelopeVersions() throws {
        assertValidationError(
            try makeEnvelope(envelopeVersion: 0),
            equals: .invalidEnvelopeVersion(0)
        )
        assertValidationError(
            try makeEnvelope(envelopeVersion: -1),
            equals: .invalidEnvelopeVersion(-1)
        )

        XCTAssertNoThrow(try makeEnvelope(envelopeVersion: 2))
    }

    func testInitializerRejectsOnlyNonPositivePayloadSchemaVersions() throws {
        assertValidationError(
            try makeEnvelope(payloadSchemaVersion: 0),
            equals: .invalidPayloadSchemaVersion(0)
        )
        assertValidationError(
            try makeEnvelope(payloadSchemaVersion: -1),
            equals: .invalidPayloadSchemaVersion(-1)
        )

        XCTAssertNoThrow(try makeEnvelope(payloadSchemaVersion: 2))
    }

    func testDecodingRejectsEnvelopeVersionZeroWithValidationError() throws {
        let malformed = try replacingJSONValue(
            forKey: "envelopeVersion",
            with: 0,
            in: makeEnvelope()
        )

        assertDecodeError(malformed, equals: .invalidEnvelopeVersion(0))
    }

    func testDecodingRejectsPayloadSchemaVersionZeroWithValidationError() throws {
        let malformed = try replacingJSONValue(
            forKey: "payloadSchemaVersion",
            with: 0,
            in: makeEnvelope()
        )

        assertDecodeError(malformed, equals: .invalidPayloadSchemaVersion(0))
    }

    func testDecodingRejectsBlankSlotIDWithValidationError() throws {
        let malformed = try replacingJSONValue(
            forKey: "slotID",
            with: " \n\t ",
            in: makeEnvelope()
        )

        assertDecodeError(malformed, equals: .emptySlotID)
    }
}

private extension PrismetSaveEnvelopeTests {
    var deviceID: UUID {
        UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    }

    var mutationID: UUID {
        UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    }

    var modifiedAt: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    var slotID: String {
        "window:00000000-0000-0000-0000-000000000001"
    }

    func makeEnvelope(
        envelopeVersion: Int = 1,
        payloadSchemaVersion: Int = 7,
        scope: PrismetStorageScope? = nil
    ) throws -> PrismetSaveEnvelope {
        try PrismetSaveEnvelope(
            envelopeVersion: envelopeVersion,
            payloadSchemaVersion: payloadSchemaVersion,
            featureID: .chess,
            scope: scope ?? PrismetStorageScope(kind: .device, identifier: deviceID),
            slotID: slotID,
            score: nil,
            modifiedAt: modifiedAt,
            deviceMutationID: mutationID,
            sourcePlatform: .macOS,
            payload: Data([0x00, 0xff, 0x7b])
        )
    }

    func replacingJSONValue(
        forKey key: String,
        with value: Any,
        in envelope: PrismetSaveEnvelope
    ) throws -> Data {
        let encoded = try PrismetSaveEnvelopeCodec.encode(envelope)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object[key] = value
        return try JSONSerialization.data(withJSONObject: object)
    }

    func assertValidationError(
        _ expression: @autoclosure () throws -> PrismetSaveEnvelope,
        equals expected: PrismetSaveEnvelopeValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(
                error as? PrismetSaveEnvelopeValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }

    func assertDecodeError(
        _ data: Data,
        equals expected: PrismetSaveEnvelopeValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try PrismetSaveEnvelopeCodec.decode(data),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? PrismetSaveEnvelopeValidationError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
