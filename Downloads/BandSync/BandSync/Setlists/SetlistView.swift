import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class SetlistManager: ObservableObject {
    @Published var setlists: [Setlist] = []

    func fetchSetlists() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let db = Firestore.firestore()
        db.collection("setlists")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading setlists: \(error.localizedDescription)")
                    return
                }

                self.setlists = snapshot?.documents.compactMap { document -> Setlist? in
                    let data = document.data()

                    guard let id = data["id"] as? String,
                          let name = data["name"] as? String,
                          let songsData = data["songs"] as? [[String: Any]] else {
                        return nil
                    }

                    let songs = songsData.compactMap { songData -> Song? in
                        guard let id = songData["id"] as? String,
                              let title = songData["title"] as? String,
                              let duration = songData["duration"] as? TimeInterval else {
                            return nil
                        }

                        let tempoBPM = songData["tempoBPM"] as? Int

                        return Song(
                            id: id,
                            title: title,
                            duration: duration,
                            tempoBPM: tempoBPM
                        )
                    }

                    return Setlist(id: id, name: name, songs: songs)
                } ?? []

                self.setlists.sort { $0.name < $1.name }
            }
    }

    func deleteSetlist(_ setlistId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let db = Firestore.firestore()
        db.collection("setlists").document(setlistId).delete { error in
            if let error = error {
                print("Error deleting setlist: \(error.localizedDescription)")
            } else {
                self.fetchSetlists()
            }
        }
    }

    func saveSetlist(_ setlist: Setlist, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "SetlistManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }

        let db = Firestore.firestore()
        let setlistData: [String: Any] = [
            "id": setlist.id,
            "name": setlist.name,
            "userId": userId,
            "songs": setlist.songs.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "duration": song.duration,
                    "tempoBPM": song.tempoBPM ?? 120
                ]
            }
        ]

        db.collection("setlists").document(setlist.id).setData(setlistData) { error in
            if error == nil {
                self.fetchSetlists()
            }
            completion(error)
        }
    }
}

struct SetlistView: View {
    @State private var setlists: [Setlist] = []
    @State private var isLoading = true
    @State private var showingAddSetlist = false
    @State private var showingTimedSetlistCreator = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var searchText = ""

    var filteredSetlists: [Setlist] {
        if searchText.isEmpty {
            return setlists
        } else {
            return setlists.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search setlists", text: $searchText)
                        .font(.system(size: 16))

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)

                HStack(spacing: 16) {
                    ActionButton(
                        title: "New Setlist",
                        icon: "music.note.list",
                        color: .blue
                    ) {
                        showingAddSetlist = true
                    }

                    ActionButton(
                        title: "Timed Setlist",
                        icon: "clock",
                        color: .purple
                    ) {
                        showingTimedSetlistCreator = true
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                if isLoading {
                    SetlistsListLoadingView()
                        .padding(.top, 40)
                } else if setlists.isEmpty {
                    EmptySetlistView()
                } else {
                    HStack {
                        Text("Your Setlists")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(filteredSetlists.count) setlists")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    if filteredSetlists.isEmpty {
                        NoSearchResultsView(searchText: searchText)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredSetlists) { setlist in
                                    SetlistCard(
                                        setlist: setlist,
                                        onExport: {
                                            exportSetlistToPDF(setlist)
                                        },
                                        onDelete: deleteSetlist
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("Setlists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddSetlist = true }) {
                        Label("New Setlist", systemImage: "music.note.list")
                    }

                    Button(action: { showingTimedSetlistCreator = true }) {
                        Label("Timed Setlist", systemImage: "clock")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddSetlist) {
            AddSetlistView(onAdd: addSetlist)
        }
        .sheet(isPresented: $showingTimedSetlistCreator) {
            TimedSetlistCreatorView()
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear(perform: fetchSetlists)
        .refreshable {
            await refreshSetlists()
        }
    }

    func fetchSetlists() {
        isLoading = true

        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not logged in"
            showingError = true
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("setlists")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                isLoading = false

                if let error = error {
                    errorMessage = "Error loading setlists: \(error.localizedDescription)"
                    showingError = true
                    return
                }

                self.setlists = snapshot?.documents.compactMap { document -> Setlist? in
                    let data = document.data()

                    guard let id = data["id"] as? String,
                          let name = data["name"] as? String,
                          let songsData = data["songs"] as? [[String: Any]] else {
                        return nil
                    }

                    let songs = songsData.compactMap { songData -> Song? in
                        guard let id = songData["id"] as? String,
                              let title = songData["title"] as? String,
                              let duration = songData["duration"] as? TimeInterval else {
                            return nil
                        }

                        let tempoBPM = songData["tempoBPM"] as? Int

                        return Song(
                            id: id,
                            title: title,
                            duration: duration,
                            tempoBPM: tempoBPM
                        )
                    }

                    return Setlist(id: id, name: name, songs: songs)
                } ?? []

                // Сортировка по имени
                self.setlists.sort { $0.name < $1.name }
            }
    }

    func refreshSetlists() async {
        return await withCheckedContinuation { continuation in
            fetchSetlists()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }

    func addSetlist(_ setlist: Setlist) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not logged in"
            showingError = true
            return
        }

        let db = Firestore.firestore()
        let setlistData: [String: Any] = [
            "id": setlist.id,
            "name": setlist.name,
            "userId": userId,
            "songs": setlist.songs.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "duration": song.duration,
                    "tempoBPM": song.tempoBPM ?? 120
                ]
            }
        ]

        db.collection("setlists").document(setlist.id).setData(setlistData) { error in
            if let error = error {
                errorMessage = "Error saving setlist: \(error.localizedDescription)"
                showingError = true
            } else {
                fetchSetlists()
            }
        }
    }

    func deleteSetlist(_ setlistId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not logged in"
            showingError = true
            return
        }

        let db = Firestore.firestore()
        db.collection("setlists").document(setlistId).delete { error in
            if let error = error {
                errorMessage = "Error deleting setlist: \(error.localizedDescription)"
                showingError = true
            } else {
                fetchSetlists()
            }
        }
    }

    func exportSetlistToPDF(_ setlist: Setlist) {
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first,
               let rootVC = window.rootViewController {
                SetlistPDFExporter.sharePDF(from: setlist, in: rootVC)
            }
        }
    }
}

struct Setlist: Identifiable {
    var id: String
    var name: String
    var songs: [Song]
}

struct Song: Identifiable, Equatable {
    var id: String
    var title: String
    var duration: TimeInterval
    var tempoBPM: Int?

    static func == (lhs: Song, rhs: Song) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ActionButton: View {
    var title: String
    var icon: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
            )
            .foregroundColor(color)
        }
    }
}

struct SetlistCard: View {
    var setlist: Setlist
    var onExport: () -> Void
    var onDelete: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setlist.name)
                            .font(.system(size: 20, weight: .bold))

                        HStack(spacing: 16) {
                            Label("\(setlist.songs.count) songs", systemImage: "music.note")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Label(formattedTotalDuration, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    NavigationLink(destination: SetlistDetailView(setlist: setlist, onDelete: onDelete)) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                }

                if !setlist.songs.isEmpty {
                    ForEach(Array(setlist.songs.prefix(3).enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(song.title)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(formattedDuration(song.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if index < min(2, setlist.songs.count - 1) {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }

                    if setlist.songs.count > 3 {
                        Text("+ \(setlist.songs.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Button(action: onExport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.15))
            }
            .foregroundColor(.green)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    var formattedTotalDuration: String {
        let totalSeconds = setlist.songs.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SetlistsListLoadingView: View {
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

            Text("Loading setlists...")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Please wait")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptySetlistView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 70))
                .padding()
                .foregroundColor(.blue.opacity(0.5))
                .background(Circle().fill(Color.blue.opacity(0.1)))

            Text("No Setlists Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create your first setlist to organize songs for your band's performances")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Button(action: {
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New Setlist")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 16)

            Spacer()
        }
    }
}

struct NoSearchResultsView: View {
    var searchText: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .padding()
                .foregroundColor(.gray.opacity(0.5))
                .background(Circle().fill(Color.gray.opacity(0.1)))

            Text("No Results")
                .font(.title3)
                .fontWeight(.semibold)

            Text("No setlists match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct SetlistDetailView: View {
    var setlist: Setlist
    var onDelete: (String) -> Void
    @State private var editedSetlist: Setlist
    @State private var isEditing = false
    @State private var showingAddSong = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @Environment(\.presentationMode) var presentationMode

    init(setlist: Setlist, onDelete: @escaping (String) -> Void) {
        self.setlist = setlist
        self.onDelete = onDelete
        _editedSetlist = State(initialValue: setlist)
    }

    var body: some View {
        VStack {
            List {
                Section {
                    if isEditing {
                        ForEach(editedSetlist.songs) { song in
                            SongEditableRow(song: song, onUpdate: { updatedSong in
                                updateSong(updatedSong)
                            })
                        }
                        .onDelete(perform: deleteSongs)
                        .onMove(perform: moveSongs)
                    } else {
                        ForEach(Array(setlist.songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(index: index + 1, song: song)
                        }
                    }
                } header: {
                    HStack {
                        Text("SONGS")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if isEditing {
                            Button(action: {
                                showingAddSong = true
                            }) {
                                Label("Add Song", systemImage: "plus")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } footer: {
                    Text("Total Duration: \(formattedTotalDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))

            if isEditing {
                HStack(spacing: 20) {
                    Button("Cancel") {
                        editedSetlist = setlist
                        isEditing = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)

                    Button("Save") {
                        saveSetlist()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle(setlist.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Menu {
                        Button(action: {
                            isEditing = true
                        }) {
                            Label("Edit Setlist", systemImage: "pencil")
                        }

                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete Setlist", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSong) {
            AddSongView { newSong in
                var updatedSongs = editedSetlist.songs
                updatedSongs.append(newSong)
                editedSetlist = Setlist(
                    id: editedSetlist.id,
                    name: editedSetlist.name,
                    songs: updatedSongs
                )
            }
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Delete Setlist?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete(setlist.id)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(setlist.name)'? This action cannot be undone.")
        }
    }

    var formattedTotalDuration: String {
        let totalSeconds = (isEditing ? editedSetlist : setlist).songs.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func updateSong(_ updatedSong: Song) {
        if let index = editedSetlist.songs.firstIndex(where: { $0.id == updatedSong.id }) {
            var updatedSongs = editedSetlist.songs
            updatedSongs[index] = updatedSong
            editedSetlist = Setlist(
                id: editedSetlist.id,
                name: editedSetlist.name,
                songs: updatedSongs
            )
        }
    }

    func deleteSongs(at offsets: IndexSet) {
        var updatedSongs = editedSetlist.songs
        updatedSongs.remove(atOffsets: offsets)
        editedSetlist = Setlist(
            id: editedSetlist.id,
            name: editedSetlist.name,
            songs: updatedSongs
        )
    }

    func moveSongs(from source: IndexSet, to destination: Int) {
        var updatedSongs = editedSetlist.songs
        updatedSongs.move(fromOffsets: source, toOffset: destination)
        editedSetlist = Setlist(
            id: editedSetlist.id,
            name: editedSetlist.name,
            songs: updatedSongs
        )
    }

    func saveSetlist() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You're not logged in"
            showingError = true
            return
        }

        let db = Firestore.firestore()
        let setlistData: [String: Any] = [
            "id": editedSetlist.id,
            "name": editedSetlist.name,
            "userId": userId,
            "songs": editedSetlist.songs.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "duration": song.duration,
                    "tempoBPM": song.tempoBPM ?? 120
                ]
            }
        ]

        db.collection("setlists").document(editedSetlist.id).setData(setlistData) { error in
            if let error = error {
                errorMessage = "Error saving setlist: \(error.localizedDescription)"
                showingError = true
            } else {
                // После успешного сохранения просто выключаем режим редактирования
                isEditing = false

                // И выходим на предыдущий экран
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct SongEditableRow: View {
    let song: Song
    let onUpdate: (Song) -> Void
    @State private var isEditing = false
    @State private var title: String
    @State private var minutes: String
    @State private var seconds: String
    @State private var tempoBPM: String

    init(song: Song, onUpdate: @escaping (Song) -> Void) {
        self.song = song
        self.onUpdate = onUpdate

        let mins = Int(song.duration) / 60
        let secs = Int(song.duration) % 60

        _title = State(initialValue: song.title)
        _minutes = State(initialValue: "\(mins)")
        _seconds = State(initialValue: String(format: "%02d", secs))
        _tempoBPM = State(initialValue: song.tempoBPM != nil ? "\(song.tempoBPM!)" : "")
    }

    var body: some View {
        if isEditing {
            VStack(spacing: 16) {
                TextField("Song Title", text: $title)
                    .font(.system(size: 16, weight: .medium))

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("0", text: $minutes)
                                .keyboardType(.numberPad)
                                .frame(width: 40)

                            Text(":")
                                .foregroundColor(.secondary)

                            TextField("00", text: $seconds)
                                .keyboardType(.numberPad)
                                .frame(width: 40)
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tempo (BPM)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("120", text: $tempoBPM)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                    }
                }

                HStack {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .foregroundColor(.blue)

                    Spacer()

                    Button("Save") {
                        saveSongChanges()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
        } else {
            HStack(spacing: 16) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .medium))

                    HStack(spacing: 16) {
                        Label(formattedDuration(song.duration), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let tempoBPM = song.tempoBPM {
                            Label("\(tempoBPM) BPM", systemImage: "metronome")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func saveSongChanges() {
        let mins = Int(minutes) ?? 0
        let secs = Int(seconds) ?? 0
        let tempo = Int(tempoBPM)

        let duration = TimeInterval(mins * 60 + secs)

        let updatedSong = Song(
            id: song.id,
            title: title,
            duration: duration,
            tempoBPM: tempo
        )

        onUpdate(updatedSong)
        isEditing = false
    }
}

struct AddSongView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var minutes = "3"
    @State private var seconds = "00"
    @State private var tempoBPM = "120"

    var onAdd: (Song) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("SONG INFORMATION")) {
                    TextField("Song Title", text: $title)
                }

                Section(header: Text("DURATION")) {
                    HStack {
                        TextField("Minutes", text: $minutes)
                            .keyboardType(.numberPad)

                        Text(":")

                        TextField("Seconds", text: $seconds)
                            .keyboardType(.numberPad)
                    }
                }

                Section(header: Text("TEMPO")) {
                    HStack {
                        TextField("BPM", text: $tempoBPM)
                            .keyboardType(.numberPad)

                        Text("BPM")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(action: addSong) {
                        Text("Add Song")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Add Song")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    func addSong() {
        guard !title.isEmpty else { return }

        let mins = Int(minutes) ?? 3
        let secs = Int(seconds) ?? 0
        let tempo = Int(tempoBPM) ?? 120

        let newSong = Song(
            id: UUID().uuidString,
            title: title,
            duration: TimeInterval(mins * 60 + secs),
            tempoBPM: tempo
        )

        onAdd(newSong)
        presentationMode.wrappedValue.dismiss()
    }
}

struct SongRow: View {
    var index: Int
    var song: Song

    var body: some View {
        HStack(spacing: 16) {
            Text("\(index).")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 30, alignment: .leading)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 16, weight: .medium))

                HStack(spacing: 16) {
                    Label(formattedDuration(song.duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let tempoBPM = song.tempoBPM {
                        Label("\(tempoBPM) BPM", systemImage: "metronome")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AddSetlistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var setlistName = ""
    @State private var songs: [Song] = []

    var onAdd: (Setlist) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Setlist Name", text: $setlistName)
                } header: {
                    Text("SETLIST INFORMATION")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: addNewSong) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Song")
                                .foregroundColor(.primary)
                        }
                    }

                    ForEach(songs) { song in
                        SongEditorRow(song: song, onUpdate: updateSong, onDelete: { deleteSong(song) })
                    }
                    .onMove { from, to in
                        songs.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("SONGS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: saveSetlist) {
                        Text("Save Setlist")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                            .bold()
                    }
                    .disabled(setlistName.isEmpty)
                }
            }
            .navigationTitle("Create Setlist")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    func addNewSong() {
        let newSong = Song(
            id: UUID().uuidString,
            title: "",
            duration: 180,
            tempoBPM: 120
        )
        songs.append(newSong)
    }

    func updateSong(_ updatedSong: Song) {
        if let index = songs.firstIndex(where: { $0.id == updatedSong.id }) {
            songs[index] = updatedSong
        }
    }

    func deleteSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
    }

    func saveSetlist() {
        guard !setlistName.isEmpty else { return }

        let newSetlist = Setlist(
            id: UUID().uuidString,
            name: setlistName,
            songs: songs
        )

        onAdd(newSetlist)
        presentationMode.wrappedValue.dismiss()
    }
}

struct SongEditorRow: View {
    let song: Song
    let onUpdate: (Song) -> Void
    let onDelete: () -> Void
    @State private var title: String
    @State private var minutes: String
    @State private var seconds: String
    @State private var tempoBPM: String

    init(song: Song, onUpdate: @escaping (Song) -> Void, onDelete: @escaping () -> Void) {
        self.song = song
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        let mins = Int(song.duration) / 60
        let secs = Int(song.duration) % 60

        _title = State(initialValue: song.title)
        _minutes = State(initialValue: "\(mins)")
        _seconds = State(initialValue: String(format: "%02d", secs))
        _tempoBPM = State(initialValue: song.tempoBPM != nil ? "\(song.tempoBPM!)" : "")
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Song Title", text: $title)
                .onChange(of: title) { _ in updateSong() }

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("0", text: $minutes)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .onChange(of: minutes) { _ in updateSong() }

                        Text(":")
                            .foregroundColor(.secondary)

                        TextField("00", text: $seconds)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .onChange(of: seconds) { _ in updateSong() }
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tempo (BPM)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("120", text: $tempoBPM)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .onChange(of: tempoBPM) { _ in updateSong() }
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 8)
    }

    func updateSong() {
        let mins = Int(minutes) ?? 0
        let secs = Int(seconds) ?? 0
        let tempo = Int(tempoBPM)

        let duration = TimeInterval(mins * 60 + secs)

        let updatedSong = Song(
            id: song.id,
            title: title,
            duration: duration,
            tempoBPM: tempo
        )

        onUpdate(updatedSong)
    }
}


