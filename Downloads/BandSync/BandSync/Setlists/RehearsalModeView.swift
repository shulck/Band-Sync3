import SwiftUI
import AVFoundation

struct RehearsalModeView: View {
    let setlist: Setlist
    @State private var currentSongIndex = 0
    @State private var timeElapsed: TimeInterval = 0
    @State private var isPlaying = true
    @State private var isPaused = false
    @State private var showingCompleteAlert = false
    @State private var showingNotes = false
    @State private var songNotes: [String: String] = [:]
    @State private var currentNote = ""
    @State private var showingSettings = false
    @State private var autoAdvance = true
    @State private var countdownTime = 5
    @State private var showingCountdown = false
    @State private var countdownValue = 5
    @State private var totalRehearsalTime: TimeInterval = 0
    @State private var rehearsalStartTime = Date()
    @State private var lastPauseTime: TimeInterval = 0
    @State private var tempoPanelVisible = false
    @State private var showingSetlistOverview = false
    @State private var tempoMultiplier: Double = 1.0

    // Audio metronome
    @State private var audioPlayer: AVAudioPlayer?
    @State private var metronomeEnabled = false
    @State private var beatsPerMinute = 120
    @State private var metronomeBeat = 4

    // Timers
    @State private var timer: Timer? = nil
    @State private var metronomeTimer: Timer? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var totalTimeTimer: Timer? = nil

    // Vibration settings
    @State private var vibrateOnSongChange = true

    // Computed properties
    private var currentSong: Song? {
        guard currentSongIndex < setlist.songs.count else { return nil }
        return setlist.songs[currentSongIndex]
    }

    private var progressPercentage: Double {
        guard let song = currentSong else { return 0 }
        return min(timeElapsed / song.duration, 1.0)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // Top information panel
                HStack {
                    VStack(alignment: .leading) {
                        Text(setlist.name)
                            .font(.title2)
                            .bold()

                        Button(action: {
                            showingSetlistOverview = true
                        }) {
                            Text("Overview (\(currentSongIndex + 1)/\(setlist.songs.count))")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }

                    Spacer()

                    // Total rehearsal time
                    VStack(alignment: .trailing) {
                        Text("Session time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(totalRehearsalTime))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                // Main content
                if showingCountdown {
                    // Display countdown
                    VStack(spacing: 20) {
                        Text("Next song in")
                            .font(.title3)

                        Text("\(countdownValue)")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.blue)

                        Text("Prepare for")
                            .font(.headline)

                        Text(setlist.songs[currentSongIndex + 1].title)
                            .font(.title3)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let song = currentSong {
                    // Main rehearsal mode
                    VStack(spacing: 12) {
                        // Metronome indicator panel
                        if metronomeEnabled {
                            HStack(spacing: 6) {
                                Image(systemName: "metronome")
                                    .foregroundColor(.orange)

                                Text("\(beatsPerMinute) BPM")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(20)
                        }

                        // Current song
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.1))

                            VStack(spacing: 16) {
                                Text("Current song")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text(song.title)
                                    .font(.system(size: 36, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                // Time counter
                                HStack(spacing: 25) {
                                    // Elapsed time
                                    VStack {
                                        Text("Elapsed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatTime(timeElapsed))
                                            .font(.system(size: 24, weight: .medium))
                                            .monospacedDigit()
                                    }

                                    // Divider
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.5))
                                        .frame(width: 1, height: 40)

                                    // Remaining time
                                    VStack {
                                        Text("Remaining")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatTime(max(0, song.duration - timeElapsed)))
                                            .font(.system(size: 24, weight: .medium))
                                            .monospacedDigit()
                                            .foregroundColor(timeWarningColor(timeRemaining: song.duration - timeElapsed))
                                    }
                                }
                                .padding(.vertical, 8)

                                // Progress indicator
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(height: 8)
                                            .cornerRadius(4)

                                        Rectangle()
                                            .fill(progressColor(percentage: progressPercentage))
                                            .frame(width: geometry.size.width * CGFloat(progressPercentage), height: 8)
                                            .cornerRadius(4)
                                    }
                                }
                                .frame(height: 8)
                                .padding(.horizontal)
                            }
                            .padding()
                        }
                        .frame(height: 240)
                        .padding(.horizontal)

                        // Actions for the current song
                        HStack(spacing: 16) {
                            // Notes
                            Button(action: {
                                currentNote = songNotes[song.id] ?? ""
                                showingNotes = true
                            }) {
                                VStack {
                                    Image(systemName: songNotes[song.id] != nil ? "note.text.fill" : "note.text")
                                        .font(.system(size: 20))
                                    Text("Notes")
                                        .font(.caption)
                                }
                                .frame(width: 70, height: 60)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }

                            // Metronome
                            Button(action: {
                                metronomeEnabled.toggle() // Just toggle the value
                                if metronomeEnabled {
                                    startMetronome() // Start the metronome
                                } else {
                                    stopMetronome() // Stop the metronome
                                }
                            }) {
                                VStack {
                                    Image(systemName: "metronome")
                                        .font(.system(size: 20))
                                        .foregroundColor(metronomeEnabled ? .orange : .primary)
                                    Text("Metronome")
                                        .font(.caption)
                                }
                                .frame(width: 70, height: 60)
                                .background(metronomeEnabled ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }

                            // Tempo
                            Button(action: {
                                tempoPanelVisible.toggle()
                            }) {
                                VStack {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 20))
                                        .foregroundColor(tempoMultiplier != 1.0 ? .blue : .primary)
                                    Text("Tempo")
                                        .font(.caption)
                                }
                                .frame(width: 70, height: 60)
                                .background(tempoMultiplier != 1.0 ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }

                            // Restart current song
                            Button(action: {
                                resetCurrentSong()
                            }) {
                                VStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 20))
                                    Text("Restart")
                                        .font(.caption)
                                }
                                .frame(width: 70, height: 60)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)

                        // Tempo panel (optional)
                        if tempoPanelVisible {
                            VStack(spacing: 8) {
                                Text("Tempo: x\(String(format: "%.1f", tempoMultiplier))")
                                    .font(.headline)

                                HStack {
                                    Text("Slower")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Slider(value: $tempoMultiplier, in: 0.5...1.5, step: 0.1)
                                        .onChange(of: tempoMultiplier) { newValue in
                                            updateSongDuration()
                                        }

                                    Text("Faster")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Button("Reset to Normal") {
                                    tempoMultiplier = 1.0
                                    updateSongDuration()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // Next song
                        if currentSongIndex < setlist.songs.count - 1 {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("Next:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text("\(currentSongIndex + 1)/\(setlist.songs.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text(setlist.songs[currentSongIndex + 1].title)
                                        .font(.headline)

                                    Spacer()

                                    Text(formatTime(setlist.songs[currentSongIndex + 1].duration))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Rehearsal completion
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Rehearsal completed!")
                            .font(.title)
                            .bold()

                        Text("Total time: \(formatTime(totalRehearsalTime))")
                            .font(.headline)

                        if !songNotes.isEmpty {
                            Button(action: {
                                showingSetlistOverview = true
                            }) {
                                Text("View All Notes")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(16)
                    .padding()
                }

                Spacer()

                // Bottom control panel
                if currentSong != nil {
                    HStack(spacing: 40) {
                        // Previous song button
                        Button(action: previousSong) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(currentSongIndex > 0 ? .blue : .gray)
                        }
                        .disabled(currentSongIndex <= 0)

                        // Play/Pause button
                        Button(action: togglePlayPause) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                        }

                        // Next song button
                        Button(action: {
                            if autoAdvance && isPlaying {
                                startCountdown()
                            } else {
                                nextSong()
                            }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(currentSongIndex < setlist.songs.count - 1 ? .blue : .gray)
                        }
                        .disabled(currentSongIndex >= setlist.songs.count - 1)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Rehearsal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }

                        Button(action: { showingSetlistOverview = true }) {
                            Label("Setlist Overview", systemImage: "list.bullet")
                        }

                        Button(action: {
                            timer?.invalidate()
                            timer = nil
                            showingCompleteAlert = true
                        }) {
                            Label("End Rehearsal", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                rehearsalStartTime = Date()
                startTimer()
                startTotalTimeTimer()
                setupAudioPlayer()
            }
            .onDisappear {
                stopAllTimers()
            }
            .alert(isPresented: $showingCompleteAlert) {
                Alert(
                    title: Text("End rehearsal?"),
                    message: Text("Rehearsal progress will be reset."),
                    primaryButton: .default(Text("Continue rehearsal")) {
                        if isPlaying {
                            startTimer()
                        }
                    },
                    secondaryButton: .destructive(Text("End")) {
                        // Return to the previous screen
                        // This will be handled in .onDisappear in SetlistView
                    }
                )
            }
            .sheet(isPresented: $showingNotes) {
                NavigationView {
                    VStack {
                        if let song = currentSong {
                            Text("Notes for: \(song.title)")
                                .font(.headline)
                                .padding()
                        }

                        TextEditor(text: $currentNote)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding()

                        Button("Save Notes") {
                            if let currentSong = currentSong {
                                songNotes[currentSong.id] = currentNote
                            }
                            showingNotes = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                    .navigationTitle("Song Notes")
                    .navigationBarItems(trailing: Button("Cancel") {
                        showingNotes = false
                    })
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    Form {
                        Section(header: Text("Playback Settings")) {
                            Toggle("Auto-advance to next song", isOn: $autoAdvance)

                            if autoAdvance {
                                Stepper("Countdown: \(countdownTime) seconds", value: $countdownTime, in: 0...10)
                            }

                            Toggle("Vibrate on song change", isOn: $vibrateOnSongChange)
                        }

                        Section(header: Text("Metronome")) {
                            Toggle("Enable metronome", isOn: $metronomeEnabled)
                                .onChange(of: metronomeEnabled) { newValue in
                                    if newValue {
                                        startMetronome()
                                    } else {
                                        stopMetronome()
                                    }
                                }

                            if metronomeEnabled {
                                HStack {
                                    Text("BPM:")
                                    Spacer()
                                    Button("-5") {
                                        beatsPerMinute = max(40, beatsPerMinute - 5)
                                        updateMetronome()
                                    }
                                    .buttonStyle(.bordered)

                                    Text("\(beatsPerMinute)")
                                        .frame(width: 60, alignment: .center)

                                    Button("+5") {
                                        beatsPerMinute = min(240, beatsPerMinute + 5)
                                        updateMetronome()
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Picker("Time Signature", selection: $metronomeBeat) {
                                    Text("2/4").tag(2)
                                    Text("3/4").tag(3)
                                    Text("4/4").tag(4)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .onChange(of: metronomeBeat) { _ in
                                    updateMetronome()
                                }
                            }
                        }

                        Section(header: Text("Rehearsal Information")) {
                            HStack {
                                Text("Current song")
                                Spacer()
                                Text(currentSong?.title ?? "None")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Total songs")
                                Spacer()
                                Text("\(setlist.songs.count)")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Total duration")
                                Spacer()
                                Text(formatTime(setlist.songs.reduce(0) { $0 + $1.duration }))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Settings")
                    .navigationBarItems(trailing: Button("Done") {
                        showingSettings = false
                    })
                }
            }
            .sheet(isPresented: $showingSetlistOverview) {
                NavigationView {
                    List {
                        ForEach(0..<setlist.songs.count, id: \.self) { index in
                            let song = setlist.songs[index]
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.headline)

                                    if songNotes[song.id] != nil {
                                        HStack {
                                            Image(systemName: "note.text")
                                                .foregroundColor(.blue)
                                            Text("Has notes")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(formatTime(song.duration))
                                        .font(.subheadline)

                                    if index == currentSongIndex {
                                        Text("Current")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    } else if index < currentSongIndex {
                                        Text("Completed")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentSongIndex = index
                                timeElapsed = 0
                                showingSetlistOverview = false
                            }
                        }
                    }
                    .navigationTitle("Setlist Overview")
                    .navigationBarItems(trailing: Button("Done") {
                        showingSetlistOverview = false
                    })
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Text("Tap on a song to jump to it")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Timer Functions

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isPlaying {
                timeElapsed += 0.1

                // Check if the time for the current song has expired
                if let song = currentSong, timeElapsed >= song.duration {
                    // Automatically move to the next song
                    if currentSongIndex < setlist.songs.count - 1 {
                        if autoAdvance {
                            startCountdown()
                        } else {
                            // Stop the timer at the end of the song if there is no auto-advance
                            isPlaying = false
                            timer?.invalidate()
                            timer = nil
                        }
                    } else {
                        // Last song completed
                        isPlaying = false
                        timer?.invalidate()
                        timer = nil
                    }
                }
            }
        }
    }

    private func startTotalTimeTimer() {
        totalTimeTimer?.invalidate()
        totalTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isPlaying {
                totalRehearsalTime += 1.0
            }
        }
    }

    private func stopAllTimers() {
        timer?.invalidate()
        timer = nil

        totalTimeTimer?.invalidate()
        totalTimeTimer = nil

        metronomeTimer?.invalidate()
        metronomeTimer = nil

        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - Metronome Functions

    private func setupAudioPlayer() {
        if let soundURL = Bundle.main.url(forResource: "metronome_click", withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Error loading sound: \(error.localizedDescription)")
            }
        }
    }

    private func startMetronome() {
        stopMetronome()

        let interval = 60.0 / Double(beatsPerMinute)

        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            audioPlayer?.play()
        }
    }

    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }

    private func updateMetronome() {
        if metronomeEnabled {
            stopMetronome()
            startMetronome()
        }
    }

    // MARK: - Navigation Functions

    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startTimer()
            if metronomeEnabled {
                startMetronome()
            }
        } else {
            if metronomeEnabled {
                stopMetronome()
            }
        }
    }

    private func nextSong() {
        if currentSongIndex < setlist.songs.count - 1 {
            currentSongIndex += 1
            timeElapsed = 0

            if vibrateOnSongChange {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func previousSong() {
        if currentSongIndex > 0 {
            currentSongIndex -= 1
            timeElapsed = 0

            if vibrateOnSongChange {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func resetCurrentSong() {
        timeElapsed = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func startCountdown() {
        // Stop the main timer during the countdown
        timer?.invalidate()
        timer = nil

        // Stop the metronome
        if metronomeEnabled {
            stopMetronome()
        }

        showingCountdown = true
        countdownValue = countdownTime

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownValue > 0 {
                countdownValue -= 1

                // Vibrate on each second of the countdown
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                // Countdown completed
                countdownTimer?.invalidate()
                showingCountdown = false

                // Move to the next song
                nextSong()

                // Restart the main timer
                startTimer()

                // Restart the metronome
                if metronomeEnabled {
                    startMetronome()
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updateSongDuration() {
        // Adjust the playback speed without changing the actual song duration
        // This is just a visual representation for the band members
    }

    private func timeWarningColor(timeRemaining: TimeInterval) -> Color {
        if timeRemaining <= 10 {
            return .red
        } else if timeRemaining <= 30 {
            return .orange
        } else {
            return .primary
        }
    }

    private func progressColor(percentage: Double) -> Color {
        if percentage < 0.5 {
            return .blue
        } else if percentage < 0.75 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview
struct RehearsalModeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RehearsalModeView(setlist: Setlist(
                id: "1",
                name: "Preview Setlist",
                songs: [
                    Song(id: "1", title: "Intro", duration: 120),
                    Song(id: "2", title: "Main Song", duration: 240),
                    Song(id: "3", title: "Bridge", duration: 180),
                    Song(id: "4", title: "Finale", duration: 210)
                ]
            ))
        }
    }
}
