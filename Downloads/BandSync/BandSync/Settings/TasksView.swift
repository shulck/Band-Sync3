import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TasksView: View {
    @State private var tasks: [Task] = []
    @State private var isLoading = true
    @State private var showingAddTask = false
    @State private var filter: TaskFilter = .all
    
    enum TaskFilter {
        case all, completed, pending
    }
    
    var filteredTasks: [Task] {
        switch filter {
        case .all:
            return tasks
        case .completed:
            return tasks.filter { $0.completed }
        case .pending:
            return tasks.filter { !$0.completed }
        }
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading tasks...")
            } else {
                VStack {
                    Picker("Filter", selection: $filter) {
                        Text("All").tag(TaskFilter.all)
                        Text("Pending").tag(TaskFilter.pending)
                        Text("Completed").tag(TaskFilter.completed)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if filteredTasks.isEmpty {
                        VStack {
                            Spacer()
                            Text(emptyStateMessage)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding()
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filteredTasks) { task in
                                TaskRow(task: task, onToggleComplete: { toggleTask(task) })
                            }
                            .onDelete(perform: deleteTasks)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(onAdd: addTask)
        }
        .onAppear(perform: fetchTasks)
        .refreshable {
            await refreshTasks()
        }
    }
    
    var emptyStateMessage: String {
        switch filter {
        case .all:
            return "No tasks yet.\nTap the + button to add a new task."
        case .completed:
            return "No completed tasks."
        case .pending:
            return "No pending tasks."
        }
    }
    
    func fetchTasks() {
        isLoading = true
        
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        // First get the user's group ID
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                isLoading = false
                return
            }
            
            // Now fetch tasks for this group
            db.collection("tasks")
                .whereField("groupId", isEqualTo: groupId)
                .order(by: "dueDate")
                .getDocuments { snapshot, error in
                    isLoading = false
                    
                    if let error = error {
                        print("Error fetching tasks: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        return
                    }
                    
                    self.tasks = documents.compactMap { document -> Task? in
                        let data = document.data()
                        
                        guard let title = data["title"] as? String,
                              let completed = data["completed"] as? Bool,
                              let timestamp = data["dueDate"] as? Timestamp,
                              let assigneeId = data["assigneeId"] as? String,
                              let assigneeName = data["assigneeName"] as? String else {
                            return nil
                        }
                        
                        return Task(
                            id: document.documentID,
                            title: title,
                            completed: completed,
                            dueDate: timestamp.dateValue(),
                            assigneeId: assigneeId,
                            assigneeName: assigneeName
                        )
                    }
                }
        }
    }
    
    func refreshTasks() async {
        // Use Swift concurrency for the refresh action
        return await withCheckedContinuation { continuation in
            fetchTasks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
    
    func toggleTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("tasks").document(task.id).updateData([
            "completed": !task.completed
        ]) { error in
            if let error = error {
                print("Error updating task: \(error.localizedDescription)")
            } else {
                // Update local state only after successful Firestore update
                tasks[index].completed.toggle()
            }
        }
    }
    
    func deleteTasks(at offsets: IndexSet) {
        let db = Firestore.firestore()
        
        for index in offsets {
            let task = filteredTasks[index]
            db.collection("tasks").document(task.id).delete { error in
                if let error = error {
                    print("Error deleting task: \(error.localizedDescription)")
                }
            }
        }
        
        // Remove from the local array
        let tasksToDelete = offsets.map { filteredTasks[$0] }
        tasks.removeAll { task in
            tasksToDelete.contains { $0.id == task.id }
        }
    }
    
    func addTask(_ task: Task) {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        // Get the user's group ID
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                return
            }
            
            guard let document = document,
                  let data = document.data(),
                  let groupId = data["groupId"] as? String else {
                return
            }
            
            // Create the task with the group ID
            var taskData = [
                "title": task.title,
                "completed": task.completed,
                "dueDate": Timestamp(date: task.dueDate),
                "assigneeId": task.assigneeId,
                "assigneeName": task.assigneeName,
                "groupId": groupId,
                "createdBy": user.uid,
                "createdAt": Timestamp(date: Date())
            ]
            
            // Add a new task to Firestore
            db.collection("tasks").addDocument(data: taskData) { error in
                if let error = error {
                    print("Error adding task: \(error.localizedDescription)")
                } else {
                    // Refresh the task list
                    fetchTasks()
                }
            }
        }
    }
}

struct Task: Identifiable {
    var id: String
    var title: String
    var completed: Bool
    var dueDate: Date
    var assigneeId: String
    var assigneeName: String
}

struct TaskRow: View {
    let task: Task
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggleComplete) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.completed ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.completed)
                    .fontWeight(.medium)
                
                HStack {
                    Text("Due: \(formattedDate(task.dueDate))")
                        .font(.caption)
                        .foregroundColor(isPastDue(task.dueDate) && !task.completed ? .red : .secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Assigned to: \(task.assigneeName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func isPastDue(_ date: Date) -> Bool {
        return date < Date()
    }
}

struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var assignee = "self" // Default to self
    @State private var assignees: [UserInfo] = []
    @State private var isLoading = true
    @State private var userName = ""
    @State private var userId = ""
    
    let onAdd: (Task) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section(header: Text("Assign To")) {
                    Picker("Assignee", selection: $assignee) {
                        Text("Me").tag("self")
                        
                        ForEach(assignees) { user in
                            Text(user.name).tag(user.id)
                        }
                    }
                }
                
                Section {
                    Button("Add Task") {
                        addTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("New Task")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                getCurrentUser()
                fetchGroupMembers()
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .background(Color.white.opacity(0.7))
                    }
                }
            )
        }
    }
    
    func getCurrentUser() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        userId = user.uid
        userName = user.displayName ?? "Unknown"
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document, let data = document.data() {
                userName = data["name"] as? String ?? userName
            }
        }
    }
    
    func fetchGroupMembers() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let groupId = data["groupId"] as? String {
                
                // Fetch all members in this group
                db.collection("users")
                    .whereField("groupId", isEqualTo: groupId)
                    .getDocuments { snapshot, error in
                        isLoading = false
                        
                        if let error = error {
                            print("Error fetching group members: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            return
                        }
                        
                        self.assignees = documents.compactMap { document -> UserInfo? in
                            let data = document.data()
                            let id = document.documentID
                            
                            // Skip the current user (as they're available as "Me")
                            if id == user.uid {
                                return nil
                            }
                            
                            guard let name = data["name"] as? String else {
                                return nil
                            }
                            
                            let email = data["email"] as? String ?? ""
                            return UserInfo(id: id, name: name, email: email)
                        }
                    }
            } else {
                isLoading = false
            }
        }
    }
    
    func addTask() {
        // Determine the assignee
        let assigneeId: String
        let assigneeName: String
        
        if assignee == "self" {
            assigneeId = userId
            assigneeName = userName
        } else {
            if let selectedUser = assignees.first(where: { $0.id == assignee }) {
                assigneeId = selectedUser.id
                assigneeName = selectedUser.name
            } else {
                // Fallback to current user if something went wrong
                assigneeId = userId
                assigneeName = userName
            }
        }
        
        // Create the task
        let task = Task(
            id: UUID().uuidString, // This will be replaced by Firestore
            title: title,
            completed: false,
            dueDate: dueDate,
            assigneeId: assigneeId,
            assigneeName: assigneeName
        )
        
        // Call the callback
        onAdd(task)
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
}
