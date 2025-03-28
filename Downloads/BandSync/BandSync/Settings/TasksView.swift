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
                TasksLoadingView()
            } else {
                VStack(spacing: 0) {
                    // Стилизованный фильтр
                    VStack(spacing: 12) {
                        Text("Filter tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        Picker("Filter", selection: $filter) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("All").tag(TaskFilter.all)
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                Text("Pending").tag(TaskFilter.pending)
                            }
                            
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Completed").tag(TaskFilter.completed)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    
                    if filteredTasks.isEmpty {
                        TaskEmptyStateView(filter: filter)
                    } else {
                        List {
                            ForEach(filteredTasks) { task in
                                EnhancedTaskRow(task: task, onToggleComplete: { toggleTask(task) })
                            }
                            .onDelete(perform: deleteTasks)
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add")
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            EnhancedAddTaskView(onAdd: addTask)
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

// Обновленный вид строки задачи
struct EnhancedTaskRow: View {
    let task: Task
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .stroke(task.completed ? Color.green : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                    
                    if task.completed {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .strikethrough(task.completed)
                    .fontWeight(.medium)
                    .foregroundColor(task.completed ? .secondary : .primary)
                
                HStack(spacing: 12) {
                    TaskInfoBadge(
                        icon: "calendar",
                        text: formattedDate(task.dueDate),
                        isPastDue: isPastDue(task.dueDate) && !task.completed
                    )
                    
                    TaskInfoBadge(
                        icon: "person",
                        text: task.assigneeName
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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

// Бейдж с информацией о задаче
struct TaskInfoBadge: View {
    var icon: String
    var text: String
    var isPastDue: Bool = false
    
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
            RoundedRectangle(cornerRadius: 4)
                .fill(isPastDue ? Color.red.opacity(0.1) : Color(.systemGray6))
        )
        .foregroundColor(isPastDue ? .red : .secondary)
    }
}

// Пустое состояние для задач
struct TaskEmptyStateView: View {
    var filter: TasksView.TaskFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: iconForFilter)
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
                .padding()
                .background(Circle().fill(Color.gray.opacity(0.1)))
            
            Text(messageForFilter)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(subtitleForFilter)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
    
    var iconForFilter: String {
        switch filter {
        case .all: return "tray"
        case .pending: return "clock"
        case .completed: return "checkmark.circle"
        }
    }
    
    var messageForFilter: String {
        switch filter {
        case .all: return "No tasks yet"
        case .pending: return "No pending tasks"
        case .completed: return "No completed tasks"
        }
    }
    
    var subtitleForFilter: String {
        switch filter {
        case .all:
            return "Tap the + button to add your first task"
        case .pending:
            return "All your tasks are completed"
        case .completed:
            return "Complete some tasks to see them here"
        }
    }
}

// Индикатор загрузки специфический для TasksView
struct TasksLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading tasks...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// Улучшенный вид добавления задачи
struct EnhancedAddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    @State private var assignee = "self" // Default to self
    @State private var assignees: [TaskUserInfo] = []
    @State private var isLoading = true
    @State private var userName = ""
    @State private var userId = ""
    
    let onAdd: (Task) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    TasksLoadingView()
                } else {
                    Form {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Task Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter task title", text: $title)
                                    .font(.headline)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 6)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Due Date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .datePickerStyle(GraphicalDatePickerStyle())
                                    .padding(.vertical, 6)
                            }
                        } header: {
                            SectionHeaderView(title: "TASK DETAILS", icon: "list.bullet.clipboard")
                        }
                        
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose Assignee")
                                    .font(.headline)
                                    .padding(.bottom, 8)
                                
                                Button(action: { assignee = "self" }) {
                                    AssigneeRow(
                                        name: "Me (\(userName))",
                                        isSelected: assignee == "self"
                                    )
                                }
                                
                                ForEach(assignees) { user in
                                    Button(action: { assignee = user.id }) {
                                        AssigneeRow(
                                            name: user.name,
                                            isSelected: assignee == user.id
                                        )
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        } header: {
                            SectionHeaderView(title: "ASSIGN TO", icon: "person.fill")
                        }
                        
                        Section {
                            Button(action: addTask) {
                                Text("Add Task")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                    .background(
                                        title.isEmpty ?
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.8)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ) :
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                    )
                                    .cornerRadius(10)
                            }
                            .disabled(title.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
            )
            .onAppear {
                getCurrentUser()
                fetchGroupMembers()
            }
        }
    }
    
    // Строка для выбора исполнителя
    struct AssigneeRow: View {
        var name: String
        var isSelected: Bool
        
        var body: some View {
            HStack {
                Text(name)
                    .font(.body)
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
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
                        
                        self.assignees = documents.compactMap { document -> TaskUserInfo? in
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
                            return TaskUserInfo(id: id, name: name, email: email)
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

// Отдельная модель для TasksView, чтобы избежать конфликтов
struct TaskUserInfo: Identifiable {
    var id: String
    var name: String
    var email: String
}
