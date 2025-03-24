import SwiftUI
import FirebaseFirestore
import MapKit

struct ContactsView: View {
    @State private var contacts: [Contact] = []
    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var showingMap = false
    @State private var selectedContact: Contact?

    // Get filtered contacts
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter { contact in
                contact.name.lowercased().contains(searchText.lowercased()) ||
                contact.venue.lowercased().contains(searchText.lowercased()) ||
                contact.role.lowercased().contains(searchText.lowercased())
            }
        }
    }

    // Group contacts by role
    var groupedContacts: [String: [Contact]] {
        Dictionary(grouping: filteredContacts) { $0.role }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Search
                SearchBar(text: $searchText)

                // View toggle (list/map)
                Picker("View", selection: $showingMap) {
                    Label("List", systemImage: "list.bullet").tag(false)
                    Label("Map", systemImage: "map").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if showingMap {
                    // Display map with markers
                    MapView(contacts: filteredContacts, selectedContact: $selectedContact)
                } else {
                    // Display contacts list
                    List {
                        ForEach(groupedContacts.keys.sorted(), id: \.self) { role in
                            Section(header: Text(role)) {
                                ForEach(groupedContacts[role]!) { contact in
                                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                                        ContactRow(contact: contact)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .onAppear(perform: fetchContacts)
            .navigationTitle(Text(LocalizedStringKey("contacts")))
            .sheet(isPresented: $showingAddContact) {
                AddContactView { newContact in
                    contacts.append(newContact)
                    saveContact(newContact)
                }
            }
            .sheet(item: $selectedContact) { contact in
                ContactDetailView(contact: contact)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddContact = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    func fetchContacts() {
        let db = Firestore.firestore()
        db.collection("contacts").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching contacts: \(error.localizedDescription)")
                return
            }

            if let snapshot = snapshot {
                self.contacts = snapshot.documents.compactMap { doc -> Contact? in
                    let data = doc.data()

                    // Check for all required fields
                    guard let name = data["name"] as? String,
                          let role = data["role"] as? String,
                          let phone = data["phone"] as? String else {
                        return nil
                    }

                    return Contact(
                        id: doc.documentID,
                        name: name,
                        role: role,
                        phone: phone,
                        email: data["email"] as? String ?? "",
                        venue: data["venue"] as? String ?? "",
                        rating: data["rating"] as? Int ?? 0,
                        notes: data["notes"] as? String ?? "",
                        latitude: data["latitude"] as? Double,
                        longitude: data["longitude"] as? Double
                    )
                }

                // If no data, load demo data
                if self.contacts.isEmpty {
                    self.loadDemoContacts()
                }
            }
        }
    }

    func loadDemoContacts() {
        // Demo contact data
        let demoContacts = [
            Contact(id: "1", name: "John Smith", role: "Organizer", phone: "+1 (555) 123-4567", email: "john@example.com", venue: "Club X", rating: 5, notes: "Great venue with professional staff", latitude: 50.450001, longitude: 30.523333),
            Contact(id: "2", name: "Jane Doe", role: "Venue Manager", phone: "+1 (555) 987-6543", email: "jane@example.com", venue: "Festival Hall", rating: 4, notes: "Good communication, responds quickly", latitude: 50.447731, longitude: 30.542721),
            Contact(id: "3", name: "Mike Johnson", role: "Sound Engineer", phone: "+1 (555) 234-5678", email: "mike@example.com", venue: "Studio Y", rating: 5, notes: "Top quality sound equipment", latitude: 50.465541, longitude: 30.519253),
            Contact(id: "4", name: "Sarah Williams", role: "Hotel Manager", phone: "+1 (555) 876-5432", email: "sarah@example.com", venue: "Grand Hotel", rating: 3, notes: "Decent accommodation near venues", latitude: 50.445000, longitude: 30.520000),
            Contact(id: "5", name: "Robert Davis", role: "Transport", phone: "+1 (555) 345-6789", email: "robert@example.com", venue: "City Transport", rating: 4, notes: "Reliable transportation services", latitude: 50.440000, longitude: 30.530000)
        ]

        contacts = demoContacts
    }

    func saveContact(_ contact: Contact) {
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "name": contact.name,
            "role": contact.role,
            "phone": contact.phone,
            "email": contact.email,
            "venue": contact.venue,
            "rating": contact.rating,
            "notes": contact.notes
        ]

        if let latitude = contact.latitude, let longitude = contact.longitude {
            data["latitude"] = latitude
            data["longitude"] = longitude
        }

        db.collection("contacts").document(contact.id).setData(data) { error in
            if let error = error {
                print("Error saving contact: \(error.localizedDescription)")
            }
        }
    }
}

// Search bar component
struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false

    var body: some View {
        HStack {
            TextField("Search contacts...", text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)

                        if isEditing {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .padding(.horizontal, 10)
                .onTapGesture {
                    self.isEditing = true
                }

            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
                    // Hide keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Text("Cancel")
                }
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
        .padding(.vertical, 8)
    }
}

// Contact row view
struct ContactRow: View {
    var contact: Contact

    var body: some View {
        VStack(alignment: .leading) {
            Text(contact.name)
                .font(.headline)
            Text("\(contact.role) - \(contact.venue)")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("📞 \(contact.phone)")
                .foregroundColor(.blue)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// Contact detail view
struct ContactDetailView: View {
    var contact: Contact
    @State private var showingMap = false
    @Environment(\.presentationMode) var presentationMode

    var hasLocation: Bool {
        return contact.latitude != nil && contact.longitude != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with name and role
                VStack(alignment: .center) {
                    Text(contact.name)
                        .font(.largeTitle)
                        .bold()

                    Text(contact.role)
                        .font(.title2)
                        .foregroundColor(.gray)

                    // Rating
                    HStack {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= contact.rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()

                // Main information
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "building.2", title: "Venue", value: contact.venue)
                    InfoRow(icon: "phone", title: "Phone", value: contact.phone)
                    InfoRow(icon: "envelope", title: "Email", value: contact.email)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // Notes
                if !contact.notes.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Text(contact.notes)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Map (if coordinates are available)
                if hasLocation {
                    VStack {
                        Button(action: {
                            showingMap = true
                        }) {
                            HStack {
                                Image(systemName: "map")
                                Text("Show on Map")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        if showingMap {
                            ContactMapView(coordinate: CLLocationCoordinate2D(
                                latitude: contact.latitude!,
                                longitude: contact.longitude!),
                                           contactName: contact.name,
                                           contactVenue: contact.venue)
                                .frame(height: 300)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }

                // Action buttons
                HStack {
                    Button(action: {
                        // Call
                        let tel = "tel://\(contact.phone.replacingOccurrences(of: " ", with: ""))"
                        if let url = URL(string: tel), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Call")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button(action: {
                        // Send email
                        let mailto = "mailto:\(contact.email)"
                        if let url = URL(string: mailto), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Email")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Contact Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Component for displaying information in a row
struct InfoRow: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(title)
                .bold()
                .frame(width: 60, alignment: .leading)

            Text(value)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// Map for displaying contacts
struct MapView: View {
    var contacts: [Contact]
    @Binding var selectedContact: Contact?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.450001, longitude: 30.523333),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: contacts.filter { $0.latitude != nil && $0.longitude != nil }) { contact in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: contact.latitude!, longitude: contact.longitude!)) {
                Button(action: {
                    selectedContact = contact
                }) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)

                        Text(contact.name)
                            .font(.caption)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                            .padding(2)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

// Map for displaying a single contact
struct ContactMapView: View {
    var coordinate: CLLocationCoordinate2D
    var contactName: String
    var contactVenue: String

    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D, contactName: String, contactVenue: String) {
        self.coordinate = coordinate
        self.contactName = contactName
        self.contactVenue = contactVenue

        // Initialize region
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [MapItem(id: "1", coordinate: coordinate, name: contactName, venue: contactVenue)]) { item in
            MapAnnotation(coordinate: item.coordinate) {
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)

                    Text(item.name)
                        .font(.caption)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(4)
                        .padding(2)
                }
            }
        }
    }
}

// Helper structure for displaying items on the map
struct MapItem: Identifiable {
    var id: String
    var coordinate: CLLocationCoordinate2D
    var name: String
    var venue: String
}

// Form for adding a new contact
struct AddContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var role = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var venue = ""
    @State private var notes = ""
    @State private var rating = 3
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var showingLocationPicker = false

    var roles = ["Organizer", "Venue Manager", "Sound Engineer", "Hotel Manager", "Transport", "Other"]

    var onAdd: (Contact) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information")) {
                    TextField("Name", text: $name)
                    Picker("Role", selection: $role) {
                        ForEach(roles, id: \.self) {
                            Text($0)
                        }
                    }
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(header: Text("Venue")) {
                    TextField("Venue Name", text: $venue)
                    HStack {
                        Text("Rating")
                        Spacer()
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    rating = index
                                }
                        }
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                Section(header: Text("Location")) {
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Text("Set Location")
                            Spacer()
                            if latitude != nil && longitude != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    // Here should be the integration with LocationPicker
                    // In this example, it's a placeholder

                    if latitude != nil && longitude != nil {
                        Text("Location Set: \(latitude!), \(longitude!)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Section {
                    Button("Save Contact") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || role.isEmpty || phone.isEmpty)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingLocationPicker) {
                // Placeholder for LocationPicker
                // In a real app, this would be a location picker component
                VStack {
                    Text("Location Picker")
                        .font(.title)
                        .padding()

                    Button("Set Demo Location") {
                        // Kyiv, Ukraine
                        latitude = 50.450001
                        longitude = 30.523333
                        showingLocationPicker = false
                    }
                    .padding()

                    Button("Cancel") {
                        showingLocationPicker = false
                    }
                    .padding()
                }
            }
        }
    }

    func saveContact() {
        let newContact = Contact(
            id: UUID().uuidString,
            name: name,
            role: role,
            phone: phone,
            email: email,
            venue: venue,
            rating: rating,
            notes: notes,
            latitude: latitude,
            longitude: longitude
        )

        onAdd(newContact)
        presentationMode.wrappedValue.dismiss()
    }
}

// Contact model
struct Contact: Identifiable {
    var id: String
    var name: String
    var role: String
    var phone: String
    var email: String
    var venue: String
    var rating: Int
    var notes: String
    var latitude: Double?
    var longitude: Double?
}
