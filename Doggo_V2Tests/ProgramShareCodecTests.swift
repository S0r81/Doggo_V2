//
//  ProgramShareCodecTests.swift
//  Doggo_V2Tests
//
//  Security coverage for the doggov2:// import payload codec — the app's top
//  untrusted-input surface. Proves the decoder fails safe (nil, no crash, no
//  unbounded allocation) on malformed, garbage, oversized, and decompression-
//  bomb input, and that the bounded streaming inflate still round-trips real
//  programs (the regression risk of replacing NSData.decompressed).
//

import Testing
import Foundation
@testable import Doggo_V2

// @MainActor: SharedProgram's Equatable conformance is main-actor-isolated under
// the project's default-actor-isolation setting, so equality assertions run here.
// The codec under test is nonisolated and runs fine from this context.
@MainActor
struct ProgramShareCodecTests {

    // MARK: - Fixtures

    private func sampleProgram(schemaVersion: Int? = nil) -> SharedProgram {
        SharedProgram(
            name: "Test Program",
            details: "A sample",
            days: [
                SharedProgram.Day(
                    routineName: "Day 1", note: "Heavy", weekday: "Monday",
                    items: [
                        SharedProgram.Item(
                            name: "Bench Press", muscleGroup: "Chest", type: "Strength",
                            cardioType: "Distance", superset: nil, note: "RPE 8",
                            sets: [
                                SharedProgram.SetTemplate(reps: 8, repsUpper: 10, weight: 135),
                                SharedProgram.SetTemplate(reps: 8, repsUpper: nil, weight: nil)
                            ]
                        )
                    ]
                )
            ],
            schemaVersion: schemaVersion ?? SharedProgram.currentVersion
        )
    }

    private func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Round-trip (regression guard for the new bounded inflate)

    @Test func realProgramRoundTrips() throws {
        let program = sampleProgram()
        let payload = try ProgramShareManager.encodePayload(program)
        let decoded = ProgramShareManager.decodePayload(payload)
        #expect(decoded == program, "Bounded inflate must remain byte-compatible with the encoder.")
    }

    @Test func fullURLRoundTrips() throws {
        let program = sampleProgram()
        let url = try ProgramShareManager.makeShareURL(program)
        #expect(ProgramShareManager.parse(url) == program)
    }

    // MARK: - Fail-safe on hostile / malformed input

    @Test func emptyPayloadIsRejected() {
        #expect(ProgramShareManager.decodePayload("") == nil)
    }

    @Test func nonBase64PayloadIsRejected() {
        #expect(ProgramShareManager.decodePayload("!!! not base64 @@@") == nil)
    }

    @Test func validBase64ButNotZlibIsRejected() {
        // Well-formed base64url of random bytes — decodes to bytes, but they are
        // not a valid zlib stream, so inflate must fail safe.
        let garbage = Data((0..<512).map { _ in UInt8.random(in: 0...255) })
        #expect(ProgramShareManager.decodePayload(base64url(garbage)) == nil)
    }

    @Test func oversizedEncodedPayloadIsRejectedBeforeDecoding() {
        let huge = String(repeating: "A", count: ProgramShareManager.maxPayloadCharacters + 1)
        #expect(ProgramShareManager.decodePayload(huge) == nil)
    }

    @Test func unsupportedNewerSchemaIsRejected() throws {
        // A perfectly valid payload from a *newer* app must be refused, not
        // mis-decoded.
        let future = sampleProgram(schemaVersion: SharedProgram.currentVersion + 1)
        let payload = try ProgramShareManager.encodePayload(future)
        #expect(ProgramShareManager.decodePayload(payload) == nil)
    }

    // MARK: - Decompression bomb

    @Test func decompressionBombFailsSafe() throws {
        // 5 MB of zeros compresses to a tiny (<60 KB) payload but would inflate
        // to 5 MB — well past the 2 MB cap. The bounded inflate must abort and
        // return nil instead of allocating it.
        let bomb = Data(count: 5_000_000)
        let compressed = try (bomb as NSData).compressed(using: .zlib) as Data
        let payload = base64url(compressed)

        // The encoded bomb is small enough to pass the first (input-size) guard,
        // so this genuinely exercises the decompressed-size cap.
        #expect(payload.count <= ProgramShareManager.maxPayloadCharacters)
        #expect(ProgramShareManager.decodePayload(payload) == nil)
    }

    @Test func atDecompressedCapBoundaryStaysSafe() throws {
        // Just over the cap must be rejected; this also exercises multi-window
        // streaming (output far exceeds the 64 KB inflate buffer).
        let justOver = Data(count: ProgramShareManager.maxDecompressedBytes + 100_000)
        let compressed = try (justOver as NSData).compressed(using: .zlib) as Data
        #expect(ProgramShareManager.decodePayload(base64url(compressed)) == nil)
    }

    // MARK: - parse() scheme/shape guards

    @Test func foreignSchemeIsRejected() {
        #expect(ProgramShareManager.parse(URL(string: "https://evil.example.com/program?payload=abc")!) == nil)
    }

    @Test func missingPayloadIsRejected() {
        #expect(ProgramShareManager.parse(URL(string: "doggov2://import/program")!) == nil)
    }
}
