import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct TimedSetlistCreatorView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var concertDuration: Int = 60 // в минутах
    @State private var setlistName: String = ""
    @State private var availableSongs: [Song] = []
    @State private var selectedSongs: [Song] = []
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var totalSelectedDuration: TimeInterval = 0
    @State private var searchText = ""
    
    // Вычисляем общую продолжительность в формате "чч:мм:сс"
    private var formattedTotalDuration: String {
        let minutes = Int(totalSelectedDuration) / 60
        let seconds = Int(totalSelectedDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Оставшееся время (в секундах)
    private var remainingTime: TimeInterval {
        return TimeInterval(concertDuration * 60) - totalSelectedDuration
    }
    
    // Форматированное оставшееся время
    private var formattedRemainingTime: String {
        if remainingTime < 0 {
            let minutes = Int(abs(remainingTime)) / 60
            let seconds = Int(abs(remainingTime)) % 60
            return String(format: "-%d:%02d", minutes, seconds)
        } else {
            let minutes = Int(remainingTime) / 60
            let seconds = Int(remainingTime) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Цвет для оставшегося времени
    private var remainingTimeColor: Color {
        if remainingTime < 0 {
            return .red
        } else if remainingTime < 300 { // Меньше 5 минут
            return .orange
        } else {
            return .green
        }
    }
    
    // Отфильтрованные доступные песни
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return availableSongs
        } else {
            return availableSongs.filter { $0.title.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый цвет
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Верхняя секция с настройками
                    VStack(spacing: 16) {
                        // Заголовок сет-листа
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Setlist Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            
                            TextField("Enter setlist name", text: $setlistName)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        
                        // Настройки продолжительности
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Show Duration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                
                                Menu {
                                    ForEach([30, 45, 60, 75, 90, 120, 150, 180], id: \.self) { duration in
                                        Button("\(duration) minutes") {
                                            concertDuration = duration
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.blue)
                                        
                                        Text("\(concertDuration) minutes")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        
                        // Карточка отслеживания времени
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            
                            VStack(spacing: 16) {
                                // Продолжительность и оставшееся время
                                HStack(spacing: 24) {
                                    // Общая продолжительность
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Total Duration")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(formattedTotalDuration)
                                            .font(.title3)
                                            .fontWeight(.medium)
                                            .monospacedDigit()
                                    }
                                    
                                    Divider()
                                        .frame(height: 40)
                                    
                                    // Оставшееся время
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Remaining Time")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(formattedRemainingTime)
                                            .font(.title3)
                                            .fontWeight(.medium)
                                            .monospacedDigit()
                                            .foregroundColor(remainingTimeColor)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Индикатор прогресса
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Фоновый прогресс
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 8)
                                        
                                        // Заполненный прогресс
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(remainingTimeColor)
                                            .frame(width: min(geometry.size.width * CGFloat(totalSelectedDuration / (TimeInterval(concertDuration) * 60)), geometry.size.width), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(16)
                        }
                        .frame(height: 110)
                    }
                    .padding()
                    
                    // Основное содержимое
                    if isLoading {
                        SetlistLoadingView(message: "Loading songs...")
                            .padding()
                    } else if let error = error {
                        SetlistErrorStateView(
                            message: error,
                            buttonText: "Try Again",
                            action: loadAvailableSongs
                        )
                        .padding()
                    } else {
                        VStack(spacing: 0) {
                            // Секция поиска
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                
                                TextField("Search songs", text: $searchText)
                                    .disableAutocorrection(true)
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                            
                            Divider()
                                .padding(.bottom, 8)
                            
                            // Вкладки выбранных и доступных песен
                            TabView {
                                // Вкладка выбранных песен
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Selected Songs")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        Spacer()
                                        
                                        Text("\(selectedSongs.count) songs")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                    }
                                    
                                    if selectedSongs.isEmpty {
                                        SetlistEmptyStateView(
                                            icon: "music.note.list",
                                            title: "No Songs Selected",
                                            message: "Add songs from the list below to create your timed setlist"
                                        )
                                    } else {
                                        List {
                                            ForEach(selectedSongs) { song in
                                                SelectedSongRow(
                                                    song: song,
                                                    onRemove: { removeSong(song) }
                                                )
                                            }
                                            .onMove { from, to in
                                                selectedSongs.move(fromOffsets: from, toOffset: to)
                                                updateTotalDuration()
                                            }
                                        }
                                        .listStyle(PlainListStyle())
                                    }
                                }
                                .tabItem {
                                    Image(systemName: "music.note.list")
                                    Text("Selected")
                                }
                                
                                // Вкладка доступных песен
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Available Songs")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        Spacer()
                                        
                                        Text("\(filteredSongs.count) songs")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                    }
                                    
                                    if filteredSongs.isEmpty {
                                        if searchText.isEmpty {
                                            SetlistEmptyStateView(
                                                icon: "music.note",
                                                title: "No Songs Available",
                                                message: "Create songs in other setlists first, then you can use them here"
                                            )
                                        } else {
                                            SetlistEmptyStateView(
                                                icon: "magnifyingglass",
                                                title: "No Results",
                                                message: "No songs match your search for \"\(searchText)\""
                                            )
                                        }
                                    } else {
                                        List {
                                            ForEach(filteredSongs) { song in
                                                AvailableSongRow(
                                                    song: song,
                                                    isSelected: selectedSongs.contains(song),
                                                    onAdd: { addSong(song) }
                                                )
                                            }
                                        }
                                        .listStyle(PlainListStyle())
                                    }
                                }
                                .tabItem {
                                    Image(systemName: "music.note")
                                    Text("Available")
                                }
                            }
                        }
                    }
                    
                    // Нижняя панель с кнопками
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Save Setlist") {
                            saveSetlist()
                        }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: selectedSongs.isEmpty || setlistName.isEmpty))
                        .disabled(selectedSongs.isEmpty || setlistName.isEmpty)
                    }
                    .padding()
                    .background(
                        Color(.systemBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
                    )
                }
            }
            .navigationTitle("Create Timed Setlist")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAvailableSongs()
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadAvailableSongs() {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Вы не авторизованы. Пожалуйста, войдите в систему."
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        // Загружаем все песни из всех сет-листов
        let db = Firestore.firestore()
        db.collection("setlists")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, err in
                if let err = err {
                    error = "Ошибка загрузки сет-листов: \(err.localizedDescription)"
                    isLoading = false
                    return
                }
                
                var allSongs: [Song] = []
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    
                    if let songsData = data["songs"] as? [[String: Any]] {
                        for songData in songsData {
                            if let id = songData["id"] as? String,
                               let title = songData["title"] as? String,
                               let duration = songData["duration"] as? TimeInterval {
                                
                                let tempoBPM = songData["tempoBPM"] as? Int
                                
                                let song = Song(
                                    id: id,
                                    title: title,
                                    duration: duration,
                                    tempoBPM: tempoBPM
                                )
                                
                                // Добавляем только если такой песни еще нет в списке
                                if !allSongs.contains(where: { $0.id == song.id }) {
                                    allSongs.append(song)
                                }
                            }
                        }
                    }
                }
                
                // Сортируем по названию
                availableSongs = allSongs.sorted { $0.title < $1.title }
                isLoading = false
            }
    }
    
    private func addSong(_ song: Song) {
        if !selectedSongs.contains(song) {
            selectedSongs.append(song)
            updateTotalDuration()
        }
    }
    
    private func removeSong(_ song: Song) {
        if let index = selectedSongs.firstIndex(where: { $0.id == song.id }) {
            selectedSongs.remove(at: index)
            updateTotalDuration()
        }
    }
    
    private func updateTotalDuration() {
        totalSelectedDuration = selectedSongs.reduce(0) { $0 + $1.duration }
    }
    
    private func saveSetlist() {
        guard !setlistName.isEmpty, !selectedSongs.isEmpty else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Вы не авторизованы. Пожалуйста, войдите в систему."
            return
        }
        
        let setlistId = UUID().uuidString
        let newSetlist = Setlist(
            id: setlistId,
            name: setlistName,
            songs: selectedSongs
        )
        
        let db = Firestore.firestore()
        let setlistData: [String: Any] = [
            "id": setlistId,
            "name": setlistName,
            "userId": userId,
            "songs": selectedSongs.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "duration": song.duration,
                    "tempoBPM": song.tempoBPM ?? 120
                ]
            }
        ]
        
        db.collection("setlists").document(setlistId).setData(setlistData) { error in
            if let error = error {
                print("❌ Ошибка сохранения сет-листа: \(error.localizedDescription)")
                self.error = "Ошибка сохранения: \(error.localizedDescription)"
            } else {
                print("✅ Сет-лист успешно сохранен")
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

// Переименовано для избежания конфликтов
struct SetlistLoadingView: View {
    var message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: 360))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: UUID()
                    )
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

// Переименовано для избежания конфликтов
struct SetlistErrorStateView: View {
    var message: String
    var buttonText: String
    var action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Songs")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: action) {
                Text(buttonText)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

// Переименовано для избежания конфликтов
struct SetlistEmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
                .padding()
                .background(Circle().fill(Color.gray.opacity(0.1)))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

struct SelectedSongRow: View {
    var song: Song
    var onRemove: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Индикатор перетаскивания
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            // Информация о песне
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if let tempoBPM = song.tempoBPM {
                        SongBadge(
                            icon: "metronome",
                            text: "\(tempoBPM) BPM",
                            color: .orange
                        )
                    }
                    
                    SongBadge(
                        icon: "clock",
                        text: formatDuration(song.duration),
                        color: .blue
                    )
                }
            }
            
            Spacer()
            
            // Кнопка удаления
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AvailableSongRow: View {
    var song: Song
    var isSelected: Bool
    var onAdd: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Информация о песне
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .secondary : .primary)
                
                HStack(spacing: 12) {
                    if let tempoBPM = song.tempoBPM {
                        SongBadge(
                            icon: "metronome",
                            text: "\(tempoBPM) BPM",
                            color: .orange,
                            isDimmed: isSelected
                        )
                    }
                    
                    SongBadge(
                        icon: "clock",
                        text: formatDuration(song.duration),
                        color: .blue,
                        isDimmed: isSelected
                    )
                }
            }
            
            Spacer()
            
            // Кнопка добавления
            Button(action: onAdd) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .green : .blue)
            }
            .disabled(isSelected)
        }
        .padding(.vertical, 8)
        .opacity(isSelected ? 0.6 : 1.0)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SongBadge: View {
    var icon: String
    var text: String
    var color: Color
    var isDimmed: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDimmed ? Color.gray.opacity(0.1) : color.opacity(0.1))
        )
        .foregroundColor(isDimmed ? .gray : color)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isDisabled ? Color.gray : Color.blue
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
