import AVFoundation
import MediaPlayer
import Observation
import SwiftUI
import UIKit

/// The Audible player: one title at a time, for the whole app.
///
/// It plays the FairPlay stream the server's licence names with AVFoundation,
/// as it is — the content key is asked through the server, which keeps the
/// device credentials, and nothing is ever decrypted outside Apple's player.
/// It keeps playing with the screen locked, answers the lock screen, the
/// Control Centre and a headset (Now Playing), resumes where the reader
/// stopped on any Audible player, and saves the position back to Audible
/// while it plays.
///
/// Created once by the app and handed down through the environment; no view
/// reads a shared instance.
@MainActor @Observable
final class AudiblePlayer {
    enum Phase: Equatable {
        /// The licence is being asked for, or the stream is buffering its start.
        case loading
        case ready
        /// Amazon refused or the stream failed: the message says which.
        case failed(String)
    }

    /// What is being listened to. Nil when nothing is: the accessory is gone.
    private(set) var title: ListeningTitle?
    private(set) var phase: Phase = .loading
    private(set) var isPlaying = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var chapters: [ListeningChapter] = []
    /// When the sleep timer pauses the player, and what it was set to.
    private(set) var sleepTimer: (minutes: Int, endsAt: Date)?

    var progress: ListeningProgress {
        ListeningProgress(elapsed: elapsed, duration: duration, chapters: chapters)
    }

    /// The step of the ±30 s buttons, the lock screen's included.
    static let skipInterval: TimeInterval = 30
    /// How often a playing title saves its position on Audible.
    static let saveInterval: TimeInterval = 30
    /// The sleep timer's choices, in minutes.
    static let sleepChoices = [15, 20, 30]

    private let client: ListeningClient
    private var playback: Playback?
    private let player = AVPlayer()
    private var keys: FairPlayKeys?
    private var keySession: AVContentKeySession?
    private var observations: [NSKeyValueObservation] = []
    private var timeObserver: Any?
    private var lastSaved: TimeInterval?
    private var lastSaveAt = Date.distantPast
    private var sleepTask: Task<Void, Never>?
    /// The timer's last choice and when it paused the player: a headset press
    /// or a shake soon after takes the listening up for as long again.
    private var lastSleepMinutes: Int?
    private var sleptAt: Date?
    /// How long after the timer paused that a press or a shake still restarts it.
    static let sleepRestartWindow: TimeInterval = 30 * 60
    private var startTask: Task<Void, Never>?
    /// The stream once played: a failure after that is an expired signed link
    /// rather than a refusal, and asking for a fresh licence fixes it once.
    private var hasPlayed = false
    private var hasRetried = false
    private var artwork: MPMediaItemArtwork?

    init(client: ListeningClient = .live) {
        self.client = client
        player.automaticallyWaitsToMinimizeStalling = true
        observePlayer()
        observeApp()
        configureRemoteCommands()
    }

    // MARK: - Commands

    /// Play a title, from where the reader stopped on any Audible player. The
    /// accessory shows it at once, with a loader, while the licence is asked.
    func play(_ title: ListeningTitle, fromStart: Bool = false) {
        if title.asin == self.title?.asin, phase == .ready {
            if fromStart { seek(to: 0) }
            resume()
            return
        }
        saveNow()
        teardownStream()
        self.title = title
        phase = .loading
        elapsed = 0
        duration = 0
        chapters = []
        artwork = nil
        hasPlayed = false
        hasRetried = false
        lastSaved = nil
        loadArtwork(for: title)
        start(at: fromStart ? 0 : nil)
    }

    func togglePlayPause() {
        if case .failed = phase, let title {
            self.title = nil
            play(title)
            return
        }
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard phase == .ready else { return }
        activateSession()
        player.play()
    }

    func pause() {
        player.pause()
        saveNow()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: elapsed + seconds)
    }

    func previousChapter() {
        seek(to: progress.previousChapterStart)
    }

    func nextChapter() {
        guard let start = progress.nextChapterStart else { return }
        seek(to: start)
    }

    /// Move to a position. The bar slides there at once; the clock the
    /// player reports is ignored until the seek lands, so it never jumps back
    /// in between; and Audible hears of it once the taps have settled, not
    /// once per tap.
    func seek(to seconds: TimeInterval) {
        guard phase == .ready else { return }
        let target = min(max(0, seconds), max(0, duration - 1))
        withAnimation(.smooth(duration: 0.35)) { elapsed = target }
        pendingSeeks += 1
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 1000),
            toleranceBefore: .zero,
            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 1000)
        ) { [weak self] _ in
            Task { @MainActor in self?.pendingSeeks -= 1 }
        }
        updateNowPlaying()
        seekSaveTask?.cancel()
        seekSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.seekSaveDelay))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Seeks still on their way: until they land, the player's clock still
    /// says where it was.
    private var pendingSeeks = 0
    private var seekSaveTask: Task<Void, Never>?
    /// How long the taps have to settle before the position goes to Audible.
    static let seekSaveDelay: TimeInterval = 2

    /// Pause in `minutes`, or turn the timer off when that choice is the one set.
    func toggleSleepTimer(minutes: Int) {
        sleepTask?.cancel()
        if sleepTimer?.minutes == minutes {
            sleepTimer = nil
            lastSleepMinutes = nil
            return
        }
        startSleepTimer(minutes: minutes)
    }

    private func startSleepTimer(minutes: Int) {
        sleepTask?.cancel()
        lastSleepMinutes = minutes
        sleptAt = nil
        let endsAt = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimer = (minutes, endsAt)
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled, let self else { return }
            self.sleepTimer = nil
            self.sleptAt = .now
            self.pause()
        }
    }

    /// A headset press or a shake: the timer starts over for as long as it
    /// was set, and a listening it just paused plays again. Answers whether
    /// it did anything.
    @discardableResult
    func restartSleepTimer() -> Bool {
        if let sleepTimer {
            startSleepTimer(minutes: sleepTimer.minutes)
            return true
        }
        if let minutes = lastSleepMinutes, let sleptAt,
           Date.now.timeIntervalSince(sleptAt) < Self.sleepRestartWindow {
            startSleepTimer(minutes: minutes)
            resume()
            return true
        }
        return false
    }

    /// Stop listening: the position is saved and the accessory goes.
    func stop() {
        saveNow()
        sleepTask?.cancel()
        sleepTimer = nil
        teardownStream()
        title = nil
        playback = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    #if DEBUG
    /// Shows a title as if it were playing, with no stream behind it: for
    /// previews and screenshots, where FairPlay cannot run.
    func showPreview(_ title: ListeningTitle, playback: Playback, playing: Bool = true) {
        self.title = title
        self.playback = playback
        phase = .ready
        duration = playback.duration
        chapters = playback.chapters
        elapsed = playback.resumeAt ?? 0
        isPlaying = playing
    }
    #endif

    // MARK: - Stream

    private func start(at position: TimeInterval?) {
        guard let title else { return }
        startTask?.cancel()
        startTask = Task { [weak self, client] in
            do {
                let playback = try await client.start(title.asin)
                guard let self, !Task.isCancelled, self.title?.asin == title.asin else { return }
                self.open(playback, at: position ?? playback.resumeAt ?? 0)
            } catch {
                guard let self, !Task.isCancelled, !isCancellation(error) else { return }
                self.phase = .failed(Self.message(for: error))
                _ = reportError(error)
            }
        }
    }

    private func open(_ playback: Playback, at position: TimeInterval) {
        self.playback = playback
        duration = playback.duration
        chapters = playback.chapters
        elapsed = position
        lastSaved = position

        let keys = FairPlayKeys(asin: playback.asin, certificate: playback.certificate, client: client)
        let session = AVContentKeySession(keySystem: .fairPlayStreaming)
        session.setDelegate(keys, queue: FairPlayKeys.queue)
        let asset = AVURLAsset(url: playback.streamURL)
        session.addContentKeyRecipient(asset)
        self.keys = keys
        keySession = session

        let item = AVPlayerItem(asset: asset)
        // Spoken word: keep the voice's pitch when the rate changes.
        item.audioTimePitchAlgorithm = .timeDomain
        // @Sendable: KVO calls back on whatever queue changed the value, and a
        // closure bound to the main actor traps there.
        observations.append(item.observe(\.status) { @Sendable [weak self] item, _ in
            let status = item.status
            let failure = item.error
            Task { @MainActor in self?.itemStatusChanged(status, error: failure) }
        })
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finished() }
        }
        player.replaceCurrentItem(with: item)
    }

    private var endObserver: NSObjectProtocol?

    /// The book is over: its end is saved on Audible — the nightly sync then
    /// files it as read — and the audiobook started most recently among those
    /// under way follows, as the next episode does.
    private func finished() {
        guard let playback else { return }
        elapsed = duration
        saveNow()
        Task { [weak self, client] in
            let next = try? await client.nextInProgress(playback.asin)
            guard let self, self.playback?.asin == playback.asin else { return }
            if let next { self.play(next) }
        }
    }

    private func itemStatusChanged(_ status: AVPlayerItem.Status, error: Error?) {
        switch status {
        case .readyToPlay where phase != .ready:
            if duration <= 0, let seconds = player.currentItem?.duration.seconds, seconds.isFinite {
                duration = seconds
            }
            phase = .ready
            let start = CMTime(seconds: elapsed, preferredTimescale: 1000)
            player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in self?.resume() }
            }
            updateNowPlaying()
        case .failed:
            // The signed link expires: a stream that played once is asked
            // again, from where it stopped, before giving up.
            if hasPlayed, !hasRetried {
                hasRetried = true
                let position = elapsed
                teardownStream()
                phase = .loading
                start(at: position)
                return
            }
            isPlaying = false
            phase = .failed(String(localized: "Lecture impossible"))
            if let error { _ = reportError(error) }
            updateNowPlaying()
        default:
            break
        }
    }

    private func teardownStream() {
        startTask?.cancel()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        observations.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let keySession, let asset = keySession.contentKeyRecipients.first {
            keySession.removeContentKeyRecipient(asset)
        }
        keySession = nil
        keys = nil
    }

    private static func message(for error: Error) -> String {
        switch error as? APIError {
        case let .domain(code, _)? where code == "AUDIBLE_LICENSE_DENIED":
            String(localized: "Audible refuse la lecture")
        case let .domain(code, _)? where code == "AUDIBLE_NOT_CONNECTED":
            String(localized: "Compte Audible déconnecté")
        default:
            String(localized: "Lecture impossible")
        }
    }

    // MARK: - Position

    /// Save the position on Audible, if it moved since the last save.
    private func saveNow() {
        guard let playback, phase == .ready else { return }
        let position = elapsed
        if let lastSaved, abs(lastSaved - position) < 1 { return }
        lastSaved = position
        lastSaveAt = .now
        Task { [client] in
            do {
                try await client.savePosition(playback.asin, playback.contentReference, position)
            } catch {
                guard !isCancellation(error) else { return }
                _ = reportError(error)
            }
        }
    }

    private func tick(_ time: CMTime) {
        guard phase == .ready, time.isNumeric, pendingSeeks == 0 else { return }
        // Over the half second to the next tick, so the bar glides.
        withAnimation(isPlaying ? .linear(duration: 0.5) : nil) { elapsed = time.seconds }
        if isPlaying { hasPlayed = true }
        if isPlaying, Date.now.timeIntervalSince(lastSaveAt) >= Self.saveInterval {
            saveNow()
        }
    }

    // MARK: - Observation

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
        rateObservation = player.observe(\.timeControlStatus) { @Sendable [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in
                guard let self, self.isPlaying != playing else { return }
                self.isPlaying = playing
                self.updateNowPlaying()
            }
        }
    }

    private var rateObservation: NSKeyValueObservation?

    private func observeApp() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, let raw, let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began: self.saveNow()
                case .ended:
                    if let options, AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                        self.resume()
                    }
                @unknown default: break
                }
            }
        }
        // A shake, as in Audible's own app: the sleep timer starts over.
        center.addObserver(forName: .deviceDidShake, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.restartSleepTimer() == true {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
        // Headphones pulled out: AVPlayer pauses itself; the position follows.
        center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated {
                if raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self?.saveNow()
                }
            }
        }
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
        try? session.setActive(true)
    }

    // MARK: - Now Playing

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.restartSleepTimer() { self.resume() }
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // While the timer runs, a press on the headset gives it its
                // minutes back rather than pausing; once it paused, it plays.
                if !self.restartSleepTimer() { self.togglePlayPause() }
            }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.skip(by: Self.skipInterval) }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.skip(by: -Self.skipInterval) }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            MainActor.assumeIsolated { self?.seek(to: position) }
            return .success
        }
        // A headset's double and triple press: the chapters, as Audible does.
        center.nextTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.nextChapter() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.previousChapter() }
            return .success
        }
    }

    /// What the lock screen and the Control Centre show. Written on every
    /// change of state, not on every tick: the system runs the clock itself
    /// from the elapsed time and the rate.
    private func updateNowPlaying() {
        guard let title else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let subtitle = title.subtitle { info[MPMediaItemPropertyArtist] = subtitle }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        if let number = progress.chapterNumber {
            info[MPNowPlayingInfoPropertyChapterNumber] = number - 1
            info[MPNowPlayingInfoPropertyChapterCount] = chapters.count
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// The lock screen's cover. Built away from the main actor: the system
    /// asks for the image on a queue of its own, and a closure made on the
    /// main actor traps there (it did on 2026-11-18).
    nonisolated private static func artwork(of image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func loadArtwork(for title: ListeningTitle) {
        guard let url = title.coverURL else { return }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data)
            else { return }
            guard let self, self.title?.asin == title.asin else { return }
            self.artwork = Self.artwork(of: image)
            self.updateNowPlaying()
        }
    }
}

/// Answers AVFoundation's FairPlay key requests: the SPC is built from the
/// licence's certificate and the `skd://` URI without its scheme, traded for
/// the CKC through the server, and handed back to the player.
private final class FairPlayKeys: NSObject, AVContentKeySessionDelegate, @unchecked Sendable {
    static let queue = DispatchQueue(label: "com.polyforms.shiori.fairplay")

    private let asin: String
    private let certificate: Data
    private let client: ListeningClient

    init(asin: String, certificate: Data, client: ListeningClient) {
        self.asin = asin
        self.certificate = certificate
        self.client = client
    }

    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        answer(keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        answer(keyRequest)
    }

    func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: Error) {
        _ = reportError(err)
    }

    private func answer(_ keyRequest: AVContentKeyRequest) {
        let uri = (keyRequest.identifier as? String) ?? ""
        let assetID = Data(uri.replacingOccurrences(of: "skd://", with: "").utf8)
        keyRequest.makeStreamingContentKeyRequestData(
            forApp: certificate, contentIdentifier: assetID, options: nil
        ) { [asin, client] spc, error in
            guard let spc else {
                keyRequest.processContentKeyResponseError(error ?? ListeningError.unreadableKey)
                return
            }
            Task {
                do {
                    let ckc = try await client.contentKey(asin, spc)
                    keyRequest.processContentKeyResponse(
                        AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc)
                    )
                } catch {
                    keyRequest.processContentKeyResponseError(error)
                }
            }
        }
    }
}
