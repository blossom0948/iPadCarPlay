import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceAssistant: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var response = ""
    @Published private(set) var permissionMessage: String?

    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private weak var audioPlayer: LocalAudioPlayer?
    private var commandHandler: ((String) async -> String)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func startListening(audioPlayer: LocalAudioPlayer, commandHandler: @escaping (String) async -> String) {
        guard !isListening else { stopListening(); return }
        self.audioPlayer = audioPlayer
        self.commandHandler = commandHandler
        transcript = ""
        response = ""
        permissionMessage = nil
        Task {
            let speechPermission = await requestSpeechPermission()
            let microphonePermission = await requestMicrophonePermission()
            guard speechPermission == .authorized, microphonePermission else {
                permissionMessage = "음성 인식과 마이크 사용 권한을 설정 앱에서 허용해 주세요."
                return
            }
            beginRecognition()
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    func speak(_ text: String, audioPlayer: LocalAudioPlayer) {
        response = text
        self.audioPlayer = audioPlayer
        audioPlayer.duckForSpeech()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        audioPlayer?.restoreVolumeAfterSpeech()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        audioPlayer?.restoreVolumeAfterSpeech()
    }

    private func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in continuation.resume(returning: allowed) }
        }
    }

    private func beginRecognition() {
        guard let recognizer, recognizer.isAvailable else {
            permissionMessage = "현재 한국어 음성 인식을 사용할 수 없습니다."
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try audioSession.setActive(true)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            recognitionRequest = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            permissionMessage = nil
            audioPlayer?.duckForSpeech()

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard result != nil || error != nil else { return }
                Task { @MainActor in self?.handleRecognition(result: result, error: error) }
            }
        } catch {
            permissionMessage = "마이크를 시작하지 못했습니다: \(error.localizedDescription)"
            cleanupRecognition()
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            transcript = result.bestTranscription.formattedString
            if result.isFinal { completeCommand() }
        }
        if error != nil {
            cleanupRecognition()
            if !transcript.isEmpty { completeCommand() }
            else {
                restorePlaybackAudioSession()
                permissionMessage = "음성을 인식하지 못했습니다. 다시 눌러 주세요."
            }
        }
    }

    private func completeCommand() {
        guard !transcript.isEmpty else { cleanupRecognition(); return }
        let recognizedText = transcript
        cleanupRecognition()
        restorePlaybackAudioSession()
        Task { @MainActor in
            let answer: String
            if let commandHandler { answer = await commandHandler(recognizedText) }
            else { answer = "명령을 처리하지 못했습니다." }
            if let audioPlayer { speak(answer, audioPlayer: audioPlayer) }
            else { response = answer }
        }
    }

    private func restorePlaybackAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        audioPlayer?.restoreVolumeAfterSpeech()
    }

    private func cleanupRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
}
