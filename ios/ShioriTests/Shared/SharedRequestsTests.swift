import Foundation
import Testing
@testable import Shiori

struct SharedRequestsTests {
    @Test func theSameRequestAskedAtOnceGoesOutOnce() async throws {
        let shared = SharedRequests()
        let calls = Calls()
        let request: @Sendable () async throws -> Int = {
            calls.record("sent")
            try await Task.sleep(for: .milliseconds(50))
            return 42
        }

        async let first = shared.run("Discovery book", request)
        async let second = shared.run("Discovery book", request)
        let answers = try await [first, second]

        #expect(answers == [42, 42])
        #expect(calls.all == ["sent"])
    }

    @Test func differentRequestsGoOutApart() async throws {
        let shared = SharedRequests()
        let calls = Calls()

        async let book = shared.run("Discovery book") { calls.record("book"); return 1 }
        async let audiobook = shared.run("Discovery audiobook") { calls.record("audiobook"); return 2 }
        _ = try await (book, audiobook)

        #expect(Set(calls.all) == ["book", "audiobook"])
    }

    @Test func anAnswerIsNeverKeptOnceItCameBack() async throws {
        let shared = SharedRequests()
        let calls = Calls()

        _ = try await shared.run("Discovery book") { calls.record("sent"); return 1 }
        _ = try await shared.run("Discovery book") { calls.record("sent"); return 1 }

        #expect(calls.all == ["sent", "sent"])
    }

    @Test func aFailureReachesEveryoneSharingIt() async {
        let shared = SharedRequests()
        let request: @Sendable () async throws -> Int = {
            try await Task.sleep(for: .milliseconds(50))
            throw Boom()
        }

        async let first: Result<Int, any Error> = Result(awaiting: { try await shared.run("k", request) })
        async let second: Result<Int, any Error> = Result(awaiting: { try await shared.run("k", request) })
        let results = await [first, second]

        #expect(results.allSatisfy { if case .failure = $0 { true } else { false } })
    }

    @Test func aCallerLeavingDoesNotCallItOffForTheOthers() async throws {
        let shared = SharedRequests()
        let request: @Sendable () async throws -> Int = {
            try await Task.sleep(for: .milliseconds(100))
            return 7
        }

        let leaving = Task { try await shared.run("k", request) }
        let staying = Task { try await shared.run("k", request) }
        try await Task.sleep(for: .milliseconds(20))
        leaving.cancel()

        #expect(try await staying.value == 7)
        await #expect(throws: CancellationError.self) { try await leaving.value }
    }

    @Test func everyoneLeavingCallsItOff() async throws {
        let shared = SharedRequests()
        let finished = Flag()
        let request: @Sendable () async throws -> Int = {
            try await Task.sleep(for: .seconds(5))
            finished.isOn = true
            return 7
        }

        let only = Task { try await shared.run("k", request) }
        try await Task.sleep(for: .milliseconds(20))
        only.cancel()

        await #expect(throws: CancellationError.self) { try await only.value }
        #expect(finished.isOn == false)
        // A caller arriving after starts afresh rather than joining the
        // cancelled request.
        #expect(try await shared.run("k") { 8 } == 8)
    }
}

private extension Result where Failure == any Error {
    init(awaiting body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
