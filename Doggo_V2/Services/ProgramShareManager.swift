//
//  ProgramShareManager.swift
//  Doggo_V2
//
//  "One-click" program sharing over a custom URL scheme. A CustomProgram only
//  stores routine UUID references, so a shareable link can't carry the program
//  alone — it carries a self-contained SNAPSHOT of the referenced routines,
//  their items, exercises, and set templates.
//
//  Pipeline: SharedProgram → JSON → zlib (Apple Compression) → base64url → URL.
//  Raw JSON is far too long for a reliable link; zlib typically shrinks a
//  realistic program by ~3–5×, and base64url keeps the payload URL-safe with
//  no percent-encoding. The codec here is pure and side-effect free — all
//  database work lives in the import use case (Stage 3).
//
//  URL shape:  doggov2://import/program?payload=<base64url(zlib(json))>
//

import Foundation
import Compression

// MARK: - Shareable Snapshot

/// A fully self-contained program: everything needed to rebuild the routines
/// on another device, independent of that device's existing data.
nonisolated struct SharedProgram: Codable, Equatable, Sendable {
    /// Bumped when the payload shape changes; older apps reject newer versions.
    var schemaVersion: Int
    var name: String
    var details: String
    var days: [Day]

    static let currentVersion = 1

    init(name: String, details: String, days: [Day], schemaVersion: Int = SharedProgram.currentVersion) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.details = details
        self.days = days
    }

    nonisolated struct Day: Codable, Equatable, Sendable {
        var routineName: String
        var note: String
        /// Weekday assignment from the source program ("Monday"…), if any.
        var weekday: String?
        var items: [Item]
    }

    nonisolated struct Item: Codable, Equatable, Sendable {
        var name: String
        var muscleGroup: String
        /// Exercise.type ("Strength" / "Cardio").
        var type: String
        /// CardioTrackingType raw value.
        var cardioType: String
        /// Local superset group index within the day (nil = not supersetted).
        var superset: Int?
        var note: String?
        var sets: [SetTemplate]
    }

    nonisolated struct SetTemplate: Codable, Equatable, Sendable {
        var reps: Int
        var repsUpper: Int?
        var weight: Double?
    }
}

extension SharedProgram {
    var dayCount: Int { days.count }
    var exerciseCount: Int { days.reduce(0) { $0 + $1.items.count } }

    /// Snapshots a saved CustomProgram by resolving its routine references.
    /// Pure read mapping on the main context — no inserts.
    @MainActor
    static func from(_ program: CustomProgram, routinesByID: [String: Routine]) -> SharedProgram {
        var days: [Day] = []

        for (index, routineID) in program.routineIDs.enumerated() {
            guard let routine = routinesByID[routineID] else { continue }
            let weekday = index < program.weekdays.count ? program.weekdays[index] : nil

            var supersetMap: [UUID: Int] = [:]
            var items: [Item] = []

            for item in routine.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                guard let exercise = item.exercise else { continue }

                var superset: Int?
                if let sid = item.supersetID {
                    if supersetMap[sid] == nil { supersetMap[sid] = supersetMap.count }
                    superset = supersetMap[sid]
                }

                let sets = item.templateSets
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { SetTemplate(reps: $0.targetReps, repsUpper: $0.targetRepsUpper, weight: $0.targetWeight) }

                items.append(Item(
                    name: exercise.name,
                    muscleGroup: exercise.muscleGroup,
                    type: exercise.type,
                    cardioType: exercise.cardioType,
                    superset: superset,
                    note: item.note,
                    sets: sets
                ))
            }

            days.append(Day(routineName: routine.name, note: routine.note, weekday: weekday, items: items))
        }

        return SharedProgram(name: program.name, details: program.details, days: days)
    }
}

// MARK: - Codec

nonisolated enum ProgramShareManager {
    static let scheme = "doggov2"
    static let host = "import"
    static let path = "/program"
    static let payloadKey = "payload"

    /// First guard: upper bound on the *encoded* payload, applied before we
    /// touch the data at all.
    static let maxPayloadCharacters = 60_000

    /// Second guard: hard cap on the *decompressed* size. zlib can amplify
    /// ~1000×, so the input cap alone isn't enough — inflate is bounded to this
    /// many bytes and aborts past it, so a decompression bomb can never force a
    /// large allocation. A legitimate program snapshot is a few KB; 2 MB is
    /// enormous headroom.
    static let maxDecompressedBytes = 2_000_000

    enum ShareError: LocalizedError {
        case urlConstructionFailed

        var errorDescription: String? {
            switch self {
            case .urlConstructionFailed: return "Could not build a share link for this program."
            }
        }
    }

    // MARK: Encode

    /// Convenience for the export UI: snapshot a saved program and build its
    /// share link in one step. Returns nil if the link can't be built.
    @MainActor
    static func shareURL(for program: CustomProgram, routines: [Routine]) -> URL? {
        let byID = Dictionary(routines.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        return try? makeShareURL(SharedProgram.from(program, routinesByID: byID))
    }

    /// Builds the shareable deep link for a program snapshot.
    static func makeShareURL(_ program: SharedProgram) throws -> URL {
        let payload = try encodePayload(program)
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = [URLQueryItem(name: payloadKey, value: payload)]
        guard let url = components.url else { throw ShareError.urlConstructionFailed }
        return url
    }

    /// SharedProgram → JSON → zlib → base64url.
    static func encodePayload(_ program: SharedProgram) throws -> String {
        let json = try JSONEncoder().encode(program)
        let compressed = try (json as NSData).compressed(using: .zlib)
        return base64URLEncode(compressed as Data)
    }

    // MARK: Decode

    /// Parses a deep link into a program snapshot, or nil if it isn't a valid
    /// Doggo import link. Lenient on host/path, strict on scheme + payload.
    static func parse(_ url: URL) -> SharedProgram? {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              (url.host?.lowercased() == host || components.path.contains("program")),
              let payload = components.queryItems?.first(where: { $0.name == payloadKey })?.value
        else { return nil }
        return decodePayload(payload)
    }

    /// base64url → bounded zlib inflate → JSON → SharedProgram. Returns nil on
    /// any corruption, an over-sized payload, a decompression bomb, or an
    /// unsupported (newer) schema version. Never crashes and never allocates
    /// more than `maxDecompressedBytes` of decompressed output.
    static func decodePayload(_ payload: String) -> SharedProgram? {
        guard payload.count <= maxPayloadCharacters,
              let compressed = base64URLDecode(payload),
              let json = zlibInflate(compressed, limit: maxDecompressedBytes),
              let program = try? JSONDecoder().decode(SharedProgram.self, from: json),
              program.schemaVersion <= SharedProgram.currentVersion
        else { return nil }
        return program
    }

    // MARK: - Bounded inflate

    /// Inflates an Apple `.zlib` (raw DEFLATE) buffer back to bytes, streaming
    /// through a fixed window and aborting the moment output would exceed
    /// `limit`. Returns nil on corrupt input or overflow — so a decompression
    /// bomb fails safe instead of forcing an unbounded allocation.
    private static func zlibInflate(_ input: Data, limit: Int) -> Data? {
        guard !input.isEmpty else { return nil }

        let bufferSize = 64 * 1024
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dstBuffer.deallocate() }

        var stream = compression_stream(dst_ptr: dstBuffer, dst_size: bufferSize,
                                        src_ptr: UnsafePointer(dstBuffer), src_size: 0,
                                        state: nil)
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            return nil
        }
        defer { compression_stream_destroy(&stream) }

        var output = Data()
        return input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            stream.src_ptr = srcBase
            stream.src_size = input.count
            stream.dst_ptr = dstBuffer
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    if produced > 0 {
                        output.append(dstBuffer, count: produced)
                        if output.count > limit { return nil }   // bomb guard — fail safe
                    }
                    if status == COMPRESSION_STATUS_END { return output }
                    stream.dst_ptr = dstBuffer                    // window full → reset and continue
                    stream.dst_size = bufferSize
                default:
                    return nil                                    // corrupt input
                }
            }
        }
    }

    // MARK: - base64url

    /// URL-safe base64: +/→-_ and stripped padding, so no percent-encoding.
    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
