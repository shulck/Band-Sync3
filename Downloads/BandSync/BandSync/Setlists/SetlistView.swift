import SwiftUI
import FirebaseFirestore
import FirebaseAuth
struct SetlistView: View {
    @State private var setlists: [Setlist] = []
    @State private var selectedSetlist: Setlist?
    @State private var isAddingNewSong = false
    @State private var showingEditSetlist = false
    @State private var totalDuration: TimeInterval = 0
    @State private var showingRehearsalMode = false
    @State private var isAddingSetlist = false
    @State private var selectedSong: Song?
    @State private var isEditingSong = false
    @State private var demoDataLoaded = false // Added to track demo data loading

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if setlists.isEmpty {
                    // Empty state view
                    VStack {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 70))
                            .foregroundColor(.gray)
                            .padding()

                        Text("No Setlists")
                            .font(.title)
                            .padding(.bottom, 5)

                        Text("Create your first setlist to organize your songs for performances")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)

                        Button("Create New Setlist") {
                            isAddingSetlist = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 20)

                        Spacer()
                    }
                    .padding()
                } else {
                    HStack(spacing: 0) {
                        // Setlist list column
                        VStack {
                            List {
                                ForEach(setlists) { setlist in
                                    SetlistRow(setlist: setlist, isSelected: selectedSetlist?.id == setlist.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedSetlist = setlist
                                            calculateTotalDuration()
                                        }
                                }
                                .onDelete(perform: deleteSetlist)
                            }
                            .listStyle(PlainListStyle())
                        }
                        .frame(width: selectedSetlist != nil ? UIScreen.main.bounds.width * 0.4 : UIScreen.main.bounds.width)

                        // Details view
                        if let setlist = selectedSetlist {
                            SetlistDetailView(
                                setlist: setlist,
                                totalDuration: totalDuration,
                                onEdit: { showingEditSetlist = true },
                                onExport: { exportToPDF() },
                                onRehearsal: { showingRehearsalMode = true },
                                onAddSong: { isAddingNewSong = true },
                                onMoveSongs: moveSongs,
                                onEditSong: { song in
                                    selectedSong = song
                                    isEditingSong = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Setlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isAddingSetlist = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingNewSong) {
                AddSongView { newSong in
                    if var setlist = selectedSetlist {
                        setlist.songs.append(newSong)
                        // Save the updated setlist to Firebase
                        updateSetlistInFirebase(setlist)
                    }
                }
            }
            .sheet(isPresented: $showingEditSetlist) {
                if let setlist = selectedSetlist {
                    EditSetlistView(setlist: setlist) { updatedSetlist in
                        updateSetlist(updatedSetlist)
                    }
                }
            }
            .sheet(isPresented: $isAddingSetlist) {
                CreateSetlistView { newSetlist in
                    saveSetlistToFirebase(newSetlist)
                }
            }

            .sheet(isPresented: $showingRehearsalMode) {
                if let setlist = selectedSetlist {
                    NavigationView {
                        RehearsalModeView(setlist: setlist)
                    }
                }
            }
            .sheet(isPresented: $isEditingSong) {
                if let song = selectedSong, var setlist = selectedSetlist {
                    EditSongView(song: song) { updatedSong in
                        if let index = setlist.songs.firstIndex(where: { $0.id == updatedSong.id }) {
                            setlist.songs[index] = updatedSong
                            updateSetlist(setlist)
                            calculateTotalDuration()
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchSetlistsFromFirebase()
        }
    }

    func loadSetlists() {
        // Force creation of demo data if the list is empty and demo data is not loaded
        if setlists.isEmpty && !demoDataLoaded {
            // Create at least one setlist
            let demoSongs = [
                Song(title: "First Song", duration: 180, tempoBPM: 120),
                Song(title: "Second Song", duration: 240, tempoBPM: 132)
            ]

            let demoSetlist = Setlist(name: "My First Setlist", songs: demoSongs)

            setlists = [demoSetlist]
            selectedSetlist = demoSetlist
            calculateTotalDuration()
            demoDataLoaded = true // Set the flag that demo data is loaded
        }
    }
    func fetchSetlistsFromFirebase() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot load setlists: missing user ID")
            return
        }

        let db = Firestore.firestore()
        db.collection("setlists")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading setlists: \(error.localizedDescription)")
                    return
                }

                self.setlists = snapshot?.documents.compactMap { document in
                    let data = document.data()
                    let songs = (data["songs"] as? [[String: Any]] ?? []).map { songData in
                        Song(
                            id: songData["id"] as? String ?? UUID().uuidString,
                            title: songData["title"] as? String ?? "",
                            duration: songData["duration"] as? TimeInterval ?? 0,
                            tempoBPM: songData["tempoBPM"] as? Int
                        )
                    }

                    return Setlist(
                        id: data["id"] as? String ?? UUID().uuidString,
                        name: data["name"] as? String ?? "",
                        songs: songs
                    )
                } ?? []

                // Select the first setlist if available
                if !self.setlists.isEmpty {
                    self.selectedSetlist = self.setlists.first
                    self.calculateTotalDuration()
                }
            }
    }

    func saveSetlistToFirebase(_ setlist: Setlist) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot save setlist: missing user ID")
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
                print("❌ Error saving setlist: \(error.localizedDescription)")
            } else {
                print("✅ Setlist \(setlist.name) successfully saved")
            }
        }
    }
    func updateSetlistInFirebase(_ updatedSetlist: Setlist) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot update setlist: missing user ID")
            return
        }

        let setlistData: [String: Any] = [
            "id": updatedSetlist.id,
            "name": updatedSetlist.name,
            "userId": userId,
            "songs": updatedSetlist.songs.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "duration": song.duration,
                    "tempoBPM": song.tempoBPM ?? 120
                ]
            }
        ]

        let db = Firestore.firestore()
        db.collection("setlists").document(updatedSetlist.id).setData(setlistData) { error in
            if let error = error {
                print("❌ Error updating setlist: \(error.localizedDescription)")
            } else {
                print("✅ Setlist \(updatedSetlist.name) successfully updated")
                // Reload setlists after update
                DispatchQueue.main.async {
                    self.fetchSetlistsFromFirebase()
                }
            }
        }
    }
    func calculateTotalDuration() {
        if let setlist = selectedSetlist {
            totalDuration = setlist.songs.reduce(0) { $0 + $1.duration }
        }
    }

    func updateSetlist(_ updatedSetlist: Setlist) {
        if let index = setlists.firstIndex(where: { $0.id == updatedSetlist.id }) {
            setlists[index] = updatedSetlist
            selectedSetlist = updatedSetlist
            calculateTotalDuration()
        }
    }

    func deleteSetlist(at offsets: IndexSet) {
        // Создаем копию сетлистов для удаления
        let setlistsToDelete = offsets.map { setlists[$0] }
        
        // Удаляем из локального массива
        setlists.remove(atOffsets: offsets)

        // Удаляем из Firebase
        let db = Firestore.firestore()
        setlistsToDelete.forEach { setlist in
            db.collection("setlists").document(setlist.id).delete { error in
                if let error = error {
                    print("❌ Ошибка при удалении сетлиста: \(error.localizedDescription)")
                    // Возможно, стоит показать пользователю сообщение об ошибке
                }
            }
        }

        // Обновляем выбранный сетлист
        if let firstSetlist = setlists.first {
            selectedSetlist = firstSetlist
            calculateTotalDuration()
        } else {
            selectedSetlist = nil
        }
    }

    func moveSongs(from source: IndexSet, to destination: Int) {
        if var setlist = selectedSetlist {
            setlist.songs.move(fromOffsets: source, toOffset: destination)
            updateSetlist(setlist)
        }
    }

    func exportToPDF() {
        guard let setlist = selectedSetlist else { return }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller")
            return
        }

        SetlistPDFExporter.sharePDF(from: setlist, in: rootViewController)
    }

}

struct Song: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var duration: TimeInterval
    var tempoBPM: Int? = 120
    var notes: String? = nil
}

struct Setlist: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var songs: [Song]
}

struct SetlistRow: View {
    let setlist: Setlist
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(setlist.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text("\(setlist.songs.count) songs")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let totalDuration = setlist.songs.reduce(0) { $0 + $1.duration }
                    Text(formatDuration(totalDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SetlistDetailView: View {
    let setlist: Setlist
    let totalDuration: TimeInterval
    let onEdit: () -> Void
    let onExport: () -> Void
    let onRehearsal: () -> Void
    let onAddSong: () -> Void
    let onMoveSongs: (IndexSet, Int) -> Void
    let onEditSong: (Song) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text(setlist.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: onExport) {
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: onRehearsal) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                HStack {
                    Text("Total: \(formatDuration(totalDuration))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            List {
                ForEach(setlist.songs) { song in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.body)

                            if let tempoBPM = song.tempoBPM {
                                Text("\(tempoBPM) BPM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text(formatDuration(song.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(action: {
                            onEditSong(song)
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .onMove(perform: onMoveSongs)
                .onDelete { indexSet in
                    var updatedSetlist = setlist
                    updatedSetlist.songs.remove(atOffsets: indexSet)
                    onMoveSongs(indexSet, updatedSetlist.songs.count)
                }
            }
            .listStyle(PlainListStyle())

            Button(action: onAddSong) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Song")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AddSongView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var tempoBPM = 120

    var onAdd: (Song) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Song Details")) {
                    TextField("Song Title", text: $title)

                    HStack {
                        Text("Duration:")
                        Spacer()
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { i in
                                Text("\(i) min").tag(i)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Text(":")

                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60) { i in
                                Text(String(format: "%02d sec", i)).tag(i)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    HStack {
                        Text("Tempo (BPM):")
                        Spacer()
                        TextField("BPM", value: $tempoBPM, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                }

                Section {
                    Button("Add Song") {
                        let duration = TimeInterval(minutes * 60 + seconds)
                        let newSong = Song(title: title, duration: duration, tempoBPM: tempoBPM)
                        onAdd(newSong)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty || (minutes == 0 && seconds == 0))
                }
            }
            .navigationTitle("Add Song")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct EditSongView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var tempoBPM: Int

    let song: Song
    let onSave: (Song) -> Void

    init(song: Song, onSave: @escaping (Song) -> Void) {
        self.song = song
        self.onSave = onSave

        _title = State(initialValue: song.title)
        _minutes = State(initialValue: Int(song.duration) / 60)
        _seconds = State(initialValue: Int(song.duration) % 60)
        _tempoBPM = State(initialValue: song.tempoBPM ?? 120)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Song Details")) {
                    TextField("Song Title", text: $title)

                    HStack {
                        Text("Duration:")
                        Spacer()
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { i in
                                Text("\(i) min").tag(i)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Text(":")

                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60) { i in
                                Text(String(format: "%02d sec", i)).tag(i)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    HStack {
                        Text("Tempo (BPM):")
                        Spacer()
                        TextField("BPM", value: $tempoBPM, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                }

                Section {
                    Button("Save Changes") {
                        let updatedSong = Song(
                            id: song.id,
                            title: title,
                            duration: TimeInterval(minutes * 60 + seconds),
                            tempoBPM: tempoBPM
                        )
                        onSave(updatedSong)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty || (minutes == 0 && seconds == 0))
                }
            }
            .navigationTitle("Edit Song")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct CreateSetlistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var setlistName = ""
    var onCreate: (Setlist) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Setlist Name")) {
                    TextField("Enter Setlist Name", text: $setlistName)
                }

                Section {
                    Button("Create") {
                        let newSetlist = Setlist(name: setlistName, songs: [])
                        onCreate(newSetlist)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(setlistName.isEmpty)
                }
            }
            .navigationTitle("New Setlist")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct EditSetlistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    var setlist: Setlist
    var onSave: (Setlist) -> Void

    init(setlist: Setlist, onSave: @escaping (Setlist) -> Void) {
        self.setlist = setlist
        self.onSave = onSave
        _name = State(initialValue: setlist.name)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Setlist Name")) {
                    TextField("Enter Setlist Name", text: $name)
                }

                Section {
                    Button("Save Changes") {
                        var updatedSetlist = setlist
                        updatedSetlist.name = name
                        onSave(updatedSetlist)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("Edit Setlist")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
