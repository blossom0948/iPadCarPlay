import AVFoundation
import Combine
import Foundation
import MediaPlayer

struct AudioTrack: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let title: String

    init(fileName: String) {
        id = UUID()
        self.fileName = fileName
        title = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    }
}

@MainActor
final class LocalAudioPlayer: ObservableObject {
    @Published private(set) var tracks: [AudioTrack] = []
    @Published private(set) var currentTrackID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var importMessage: String?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var savedVolume: Float?
    private let audioDirectory: URL
    private let indexURL: URL
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var completionObserver: NSObjectProtocol?

    init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        audioDirectory = applicationSupport.appendingPathComponent("ETS2CarPlay/Music", isDirectory: true)
        indexURL = audioDirectory.appendingPathComponent("library.json")
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL), let saved = try? JSONDecoder().decode([AudioTrack].self, from: data) {
            tracks = saved.filter { FileManager.default.fileExists(atPath: audioURL(for: $0).path) }
        }
        configureAudioSession()
        installProgressObserver()
        installRemoteCommands()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
        let center = MPRemoteCommandCenter.shared()
        for (command, target) in remoteTargets { command.removeTarget(target) }
        _ = center
    }

    var currentTrack: AudioTrack? { tracks.first { $0.id == currentTrackID } }
    var progress: Double { duration > 0 ? min(max(currentTime / duration, 0), 1) : 0 }

    func importFiles(_ urls: [URL]) {
        var imported = 0
        for source in urls {
            let canRead = source.startAccessingSecurityScopedResource()
            defer { if canRead { source.stopAccessingSecurityScopedResource() } }
            let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension
            let destination = audioDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                tracks.append(AudioTrack(fileName: destination.lastPathComponent))
                imported += 1
            } catch {
                importMessage = "파일을 가져오지 못했습니다: \(source.lastPathComponent)"
            }
        }
        saveLibrary()
        if imported > 0 { importMessage = "음악 파일 \(imported)개를 추가했습니다." }
    }

    func remove(_ track: AudioTrack) {
        if currentTrackID == track.id { stop() }
        tracks.removeAll { $0.id == track.id }
        try? FileManager.default.removeItem(at: audioURL(for: track))
        saveLibrary()
    }

    func play(_ track: AudioTrack) {
        guard let index = tracks.firstIndex(of: track) else { return }
        currentTrackID = track.id
        if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
        let item = AVPlayerItem(url: audioURL(for: track))
        player.replaceCurrentItem(with: item)
        completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.playbackDidFinish() }
        }
        player.play()
        isPlaying = true
        currentTime = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            let seconds = player.currentItem?.duration.seconds ?? 0
            duration = seconds.isFinite ? seconds : 0
            updateNowPlaying()
        }
        _ = index
    }

    func togglePlayback() {
        guard currentTrackID != nil else { return }
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard currentTrackID != nil else { return }
        if duration > 0, currentTime >= duration - 0.25 {
            player.seek(to: .zero)
            currentTime = 0
        }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
            self.completionObserver = nil
        }
        isPlaying = false
        currentTrackID = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func next() {
        guard let currentTrackID, let index = tracks.firstIndex(where: { $0.id == currentTrackID }), !tracks.isEmpty else { return }
        play(tracks[(index + 1) % tracks.count])
    }

    func previous() {
        guard let currentTrackID, let index = tracks.firstIndex(where: { $0.id == currentTrackID }), !tracks.isEmpty else { return }
        play(tracks[(index - 1 + tracks.count) % tracks.count])
    }

    func seek(to progress: Double) {
        guard duration > 0 else { return }
        let seconds = min(max(progress, 0), 1) * duration
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
        updateNowPlaying()
    }

    func duckForSpeech() {
        let isEnabled = UserDefaults.standard.object(forKey: "duckAudioForVoice") as? Bool ?? true
        guard isEnabled else { return }
        guard savedVolume == nil else { return }
        savedVolume = player.volume
        player.volume = max(0.15, player.volume * 0.28)
    }

    func restoreVolumeAfterSpeech() {
        guard let savedVolume else { return }
        player.volume = savedVolume
        self.savedVolume = nil
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            importMessage = "오디오 출력을 시작하지 못했습니다."
        }
    }

    private func installProgressObserver() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let seconds = self.player.currentItem?.duration.seconds, seconds.isFinite { self.duration = seconds }
                self.updateNowPlaying()
            }
        }
    }

    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        let play = center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        let pause = center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        let next = center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        let previous = center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        remoteTargets = [(center.playCommand, play), (center.pauseCommand, pause), (center.nextTrackCommand, next), (center.previousTrackCommand, previous)]
    }

    private func updateNowPlaying() {
        guard let currentTrack else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: "iPad 음악 보관함",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    private func audioURL(for track: AudioTrack) -> URL { audioDirectory.appendingPathComponent(track.fileName) }

    private func saveLibrary() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func playbackDidFinish() {
        isPlaying = false
        currentTime = duration
        updateNowPlaying()
    }
}
