import SwiftUI
import Photos
import Speech
import AVFoundation

struct SettingsView: View {
    @ObservedObject var voiceViewModel: VoiceTriggerViewModel
    @ObservedObject var cameraController: CameraController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("appearance_mode") private var appearanceMode: String = "Auto"
    
    private var selectedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    
    // Local state for defaults (independent of current session)
    @State private var defaultCamera: CameraPosition = .back
    @State private var defaultTimerDuration: TimerDuration = .off
    @State private var defaultAspectRatio: AspectRatio = .ratio4x3
    @State private var defaultShowGridLines: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Camera Defaults Section
                        SettingsSection(title: "CAMERA DEFAULTS") {
                            // Default Camera
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SettingsIconBox(icon: "camera.fill", color: Color(hex: "3b82f6"))
                                        
                                        Text("Default Camera")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Button {
                                            cameraController.saveDefaultCameraPosition(.back)
                                            defaultCamera = .back
                                        } label: {
                                            Text("Back")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    defaultCamera == .back
                                                        ? Color(hex: "6366f1")
                                                        : Color(.secondarySystemFill)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        
                                        Button {
                                            cameraController.saveDefaultCameraPosition(.front)
                                            defaultCamera = .front
                                        } label: {
                                            Text("Front")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    defaultCamera == .front
                                                        ? Color(hex: "6366f1")
                                                        : Color(.secondarySystemFill)
                                                )
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            // Countdown Delay
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SettingsIconBox(icon: "timer", color: Color(hex: "f97316"))
                                        
                                        Text("Countdown Delay")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach([TimerDuration.off, .three, .five, .ten], id: \.self) { duration in
                                            Button {
                                                cameraController.saveDefaultTimerDuration(duration)
                                                defaultTimerDuration = duration
                                            } label: {
                                                Text(duration == .off ? "Off" : duration.displayName)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        defaultTimerDuration == duration
                                                            ? Color(hex: "6366f1")
                                                            : Color(.secondarySystemFill)
                                                    )
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Aspect Ratio
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SettingsIconBox(icon: "arrow.up.left.and.arrow.down.right", color: Color(hex: "14b8a6"))
                                        
                                        Text("Aspect Ratio")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(AspectRatio.allCases, id: \.self) { ratio in
                                            Button {
                                                cameraController.saveDefaultAspectRatio(ratio)
                                                defaultAspectRatio = ratio
                                            } label: {
                                                Text(ratio.rawValue)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        defaultAspectRatio == ratio
                                                            ? Color(hex: "6366f1")
                                                            : Color(.secondarySystemFill)
                                                    )
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Composition Section
                        SettingsSection(title: "COMPOSITION") {
                            SettingsRow {
                                HStack {
                                    SettingsIconBox(icon: "grid", color: Color(hex: "8b5cf6"))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Grid Lines")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text("Rule of thirds overlay")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { defaultShowGridLines },
                                        set: { newValue in
                                            defaultShowGridLines = newValue
                                            cameraController.saveDefaultShowGridLines(newValue)
                                            cameraController.showGridLines = newValue
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(Color(hex: "8b5cf6"))
                                }
                            }
                        }
                        
                        // Voice Trigger Section
                        SettingsSection(title: "VOICE TRIGGER") {
                            NavigationLink {
                                VoiceTriggerSettingsView(voiceViewModel: voiceViewModel, cameraController: cameraController)
                            } label: {
                                SettingsRow {
                                    HStack {
                                        SettingsIconBox(icon: "mic.fill", color: Color(hex: "6366f1"))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Voice Trigger")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                            Text("Phrase: \"\(voiceViewModel.triggerPhrase)\"")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(.tertiaryLabel))
                                    }
                                }
                            }
                        }
                        
                        
                        // Appearance Section
                        SettingsSection(title: "APPEARANCE") {
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SettingsIconBox(icon: "circle.lefthalf.filled", color: Color(hex: "a855f7"))
                                        
                                        Text("Theme")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(["Auto", "Light", "Dark"], id: \.self) { mode in
                                            Button {
                                                appearanceMode = mode
                                            } label: {
                                                Text(mode)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(appearanceMode == mode ? .white : .primary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        appearanceMode == mode
                                                            ? Color(hex: "6366f1")
                                                            : Color(.secondarySystemFill)
                                                    )
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Permissions Section
                        SettingsSection(title: "PERMISSIONS") {
                            Button {
                                handlePhotoLibraryTap()
                            } label: {
                                SettingsRow {
                                    HStack {
                                        SettingsIconBox(icon: "photo.on.rectangle.angled", color: Color(hex: "ec4899"))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Photo Library")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                            Text(photoLibraryDescription)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(photoLibraryStatusText)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(photoLibraryStatusColor)
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 16)
                }
            }
            .onAppear {
                checkPhotoLibraryStatus()
                loadDefaults()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(selectedColorScheme)
        }
    }
    
    private var photoLibraryDescription: String {
        switch photoLibraryStatus {
        case .authorized:
            return "Full access granted"
        case .limited:
            return "Limited access"
        case .denied, .restricted:
            return "Access denied"
        case .notDetermined:
            return "Tap to grant access"
        @unknown default:
            return "Unknown"
        }
    }

    private var photoLibraryStatusText: String {
        switch photoLibraryStatus {
        case .authorized:
            return "Granted"
        case .limited:
            return "Limited"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var photoLibraryStatusColor: Color {
        switch photoLibraryStatus {
        case .authorized:
            return .green
        case .limited:
            return .orange
        case .denied, .restricted:
            return Color(hex: "e94560")
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private func checkPhotoLibraryStatus() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    private func handlePhotoLibraryTap() {
        switch photoLibraryStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.photoLibraryStatus = status
                }
            }
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }
    
    private func loadDefaults() {
        let defaults = UserDefaults.standard
        
        // Load camera position
        if let positionRaw = defaults.string(forKey: "camera_position"),
           let position = CameraPosition(rawValue: positionRaw) {
            defaultCamera = position
        }
        
        // Load timer duration
        let timerRaw = defaults.integer(forKey: "timer_duration")
        if let timer = TimerDuration(rawValue: timerRaw) {
            defaultTimerDuration = timer
        }
        
        // Load aspect ratio
        if let ratioRaw = defaults.string(forKey: "aspect_ratio"),
           let ratio = AspectRatio(rawValue: ratioRaw) {
            defaultAspectRatio = ratio
        }
        
        // Load grid lines
        defaultShowGridLines = defaults.bool(forKey: "show_grid_lines")
        cameraController.showGridLines = defaultShowGridLines
    }
}

// MARK: - Voice Trigger Settings View

struct VoiceTriggerSettingsView: View {
    @ObservedObject var voiceViewModel: VoiceTriggerViewModel
    @ObservedObject var cameraController: CameraController
    @Environment(\.dismiss) private var dismiss
    @State private var editedPhrase: String = ""
    @State private var isEditing: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: String = ""
    @State private var wasListeningBeforeEntering: Bool = false
    @FocusState private var textFieldFocused: Bool
    @StateObject private var testSession = VoiceTestSession()
    
    let suggestedPhrases = ["Say Cheese", "Smile", "Capture", "Take Photo", "Click", "Snap"]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    if isEditing {
                        savePhrase()
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Trigger Phrase Section
                        SettingsSection(title: "TRIGGER PHRASE") {
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Current phrase")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if isEditing {
                                            Button("Done") {
                                                savePhrase()
                                            }
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "22c55e"))
                                        } else {
                                            Button("Edit") {
                                                editedPhrase = voiceViewModel.triggerPhrase
                                                isEditing = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    textFieldFocused = true
                                                }
                                            }
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "3b82f6"))
                                        }
                                    }
                                    
                                    if isEditing {
                                        TextField("Enter phrase", text: $editedPhrase)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .padding(12)
                                            .background(Color(.secondarySystemFill))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .focused($textFieldFocused)
                                            .onSubmit {
                                                savePhrase()
                                            }
                                    } else {
                                        Text("\"\(voiceViewModel.triggerPhrase)\"")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            
                            // Suggested phrases
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggestions")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(suggestedPhrases, id: \.self) { phrase in
                                        Button {
                                            voiceViewModel.triggerPhrase = phrase
                                            voiceViewModel.handleTriggerPhraseChange()
                                            editedPhrase = phrase
                                            isEditing = false
                                            textFieldFocused = false
                                        } label: {
                                            Text(phrase)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(voiceViewModel.triggerPhrase == phrase ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    voiceViewModel.triggerPhrase == phrase
                                                        ? Color(hex: "e94560")
                                                        : Color(.secondarySystemFill)
                                                )
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        // Microphone Source Section
                        SettingsSection(title: "MICROPHONE SOURCE") {
                            ForEach(voiceViewModel.audioInputs, id: \.id) { device in
                                Button {
                                    voiceViewModel.selectAudioInput(id: device.id)
                                } label: {
                                    MicrophoneOption(
                                        title: device.name,
                                        subtitle: device.kind.rawValue,
                                        isSelected: voiceViewModel.selectedAudioInputID == device.id
                                    )
                                }
                            }
                        }
                        
                        // Test Section
                        SettingsSection(title: "TEST") {
                            SettingsRow {
                                VStack(spacing: 16) {
                                    // Test result display
                                    if !testResult.isEmpty {
                                        VStack(spacing: 8) {
                                            Text("Heard:")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            Text("\"\(testResult)\"")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(testResult.lowercased().contains(voiceViewModel.triggerPhrase.lowercased()) ? Color(hex: "22c55e") : .primary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    
                                    // Test button
                                    Button {
                                        if isTesting {
                                            stopTesting()
                                        } else {
                                            startTesting()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: isTesting ? "stop.circle.fill" : "mic.circle.fill")
                                                .font(.system(size: 20))
                                            Text(isTesting ? "Stop Listening" : "Test Voice Recognition")
                                        }
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(isTesting ? Color(hex: "e94560") : Color(hex: "6366f1"))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    if isTesting {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: "22c55e"))
                                                .frame(width: 8, height: 8)
                                            Text("Listening... say \"\(voiceViewModel.triggerPhrase)\"")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 16)
                }
            }
        .navigationTitle("Voice Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            editedPhrase = voiceViewModel.triggerPhrase
            voiceViewModel.refreshAudioInputs()
            testResult = ""
            isTesting = false
            
            // Stop the main voice listener to avoid audio session conflicts
            wasListeningBeforeEntering = voiceViewModel.isListening
            if voiceViewModel.isListening {
                voiceViewModel.stopListening()
            }
        }
        .onDisappear {
            // Always stop the test session when leaving
            testSession.stop()
            isTesting = false
            testResult = ""
            voiceViewModel.lastTranscription = nil
            
            // Restore the main listener if it was on before
            if wasListeningBeforeEntering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    voiceViewModel.startListening()
                }
            }
        }
        .onReceive(testSession.$transcription) { transcription in
            if isTesting, !transcription.isEmpty {
                testResult = transcription
            }
        }
    }
    
    private func savePhrase() {
        let trimmed = editedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            voiceViewModel.triggerPhrase = trimmed
            voiceViewModel.handleTriggerPhraseChange()
        } else {
            editedPhrase = voiceViewModel.triggerPhrase
        }
        isEditing = false
        textFieldFocused = false
    }
    
    private func startTesting() {
        testResult = ""
        isTesting = true
        testSession.start()
    }
    
    private func stopTesting() {
        testSession.stop()
        isTesting = false
        testResult = ""
    }
}

private final class VoiceTestSession: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcription: String = ""
    @Published var isRunning: Bool = false
    
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    
    override init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        speechRecognizer?.delegate = self
    }
    
    func start() {
        guard !isRunning else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }
        
        transcription = ""
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.inputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }
                
                if let result {
                    DispatchQueue.main.async {
                        self.transcription = result.bestTranscription.formattedString
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    // Auto-restart on transient errors
                    if let error, self.isRunning {
                        let desc = error.localizedDescription.lowercased()
                        if desc.contains("no speech") || desc.contains("retry") {
                            self.restart()
                            return
                        }
                    }
                }
            }
        } catch {
            stop()
        }
    }
    
    func stop() {
        isRunning = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        DispatchQueue.main.async {
            self.transcription = ""
        }
    }
    
    private func restart() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.isRunning else { return }
            self.start()
        }
    }
}

// MARK: - Helper Views

struct SettingsSection<Content: View>: View {
    let title: String?
    let content: () -> Content
    
    init(title: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .padding(.horizontal, 16)
            }
            
            VStack(spacing: 1) {
                content()
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
    }
}

struct SettingsIconBox: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.2))
                .frame(width: 36, height: 36)
            
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
        }
        .padding(.trailing, 12)
    }
}

struct MicrophoneOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    
    var body: some View {
        SettingsRow {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color(hex: "3b82f6"))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        )
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: "3b82f6") : Color.clear, lineWidth: 1)
        )
    }
}

// Simple FlowLayout for phrase chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, 
                                      y: bounds.minY + result.positions[index].y), 
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

#Preview {
    SettingsView(voiceViewModel: VoiceTriggerViewModel(), cameraController: CameraController())
        .preferredColorScheme(.dark)
}
