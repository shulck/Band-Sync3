import SwiftUI
import FirebaseFirestore

struct SetlistPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedSetlist: [String]
    @State private var availableSetlists: [Setlist] = []
    @State private var selectedSetlistId: String?

    var body: some View {
        NavigationView {
            VStack {
                if availableSetlists.isEmpty {
                    VStack {
                        Text("No setlists available")
                            .font(.headline)
                            .padding()

                        Text("Create a setlist in the Setlists tab first")
                            .foregroundColor(.secondary)

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Close")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(availableSetlists) { setlist in
                            Button(action: {
                                selectedSetlistId = setlist.id
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(setlist.name)
                                            .font(.headline)
                                        Text("\(setlist.songs.count) songs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedSetlistId == setlist.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .listStyle(PlainListStyle())

                    Button(action: {
                        if let selectedId = selectedSetlistId,
                           let setlist = availableSetlists.first(where: { $0.id == selectedId }) {
                            selectedSetlist = setlist.songs.map { $0.title }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Apply Setlist")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedSetlistId == nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .disabled(selectedSetlistId == nil)
                    .padding(.vertical)
                }
            }
            .navigationTitle("Choose Setlist")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                fetchSetlists()
            }
        }
    }

    func fetchSetlists() {
        // Loading real setlists from Firebase Firestore
        let db = Firestore.firestore()
        db.collection("setlists").getDocuments { snapshot, error in
            if let error = error {
                print("Error loading setlists: \(error.localizedDescription)")
                return
            }

            if let snapshot = snapshot {
                self.availableSetlists = snapshot.documents.compactMap { document -> Setlist? in
                    let data = document.data()
                    guard let name = data["name"] as? String else { return nil }

                    // Get array of songs
                    var songs: [Song] = []
                    if let songsData = data["songs"] as? [[String: Any]] {
                        songs = songsData.compactMap { songData -> Song? in
                            guard let title = songData["title"] as? String,
                                  let duration = songData["duration"] as? Double else {
                                return nil
                            }

                            let id = songData["id"] as? String ?? UUID().uuidString
                            let tempoBPM = songData["tempoBPM"] as? Int

                            return Song(id: id, title: title, duration: duration, tempoBPM: tempoBPM)
                        }
                    }

                    return Setlist(id: document.documentID, name: name, songs: songs)
                }
            }
        }
    }
}
