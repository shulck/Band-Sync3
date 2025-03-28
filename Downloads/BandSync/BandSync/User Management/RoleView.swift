import SwiftUI
import FirebaseAuth

struct RoleView: View {
    var userRole: String
    @State private var showingLogoutConfirmation = false
    @State private var isLoggingOut = false

    var body: some View {
        ZStack {
            // Фоновый цвет
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Карточка роли с визуальным представлением
                RoleCardView(role: userRole)
                
                // Информационная карточка
                RoleInfoCardView(role: userRole)
                
                Spacer()
                
                // Кнопка выхода
                Button(action: {
                    showingLogoutConfirmation = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Sign Out")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding(.horizontal)
                .disabled(isLoggingOut)
            }
            .padding()
            
            // Индикатор выхода
            if isLoggingOut {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            
                            Text("Signing out...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    )
            }
        }
        .navigationTitle("Your Role")
        .alert(isPresented: $showingLogoutConfirmation) {
            Alert(
                title: Text("Sign Out Confirmation"),
                message: Text("Are you sure you want to sign out of BandSync?"),
                primaryButton: .destructive(Text("Sign Out")) {
                    withAnimation {
                        isLoggingOut = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        logout()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            print("🚪 User signed out")
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
        }
        isLoggingOut = false
    }
}

// MARK: - Supporting Components

// Карточка с визуальным представлением роли
struct RoleCardView: View {
    var role: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Круглая иконка с градиентом
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [roleColor.opacity(0.8), roleColor.opacity(0.4)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: roleColor.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: roleIcon)
                    .font(.system(size: 50, weight: .regular))
                    .foregroundColor(.white)
            }
            
            // Текст роли
            VStack(spacing: 8) {
                Text("Your role:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(role)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(roleColor)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // Определить цвет на основе роли
    var roleColor: Color {
        switch role {
        case "Admin":
            return .purple
        case "Manager":
            return .blue
        case "Musician":
            return .green
        case "Member":
            return .orange
        default:
            return .gray
        }
    }
    
    // Определить иконку на основе роли
    var roleIcon: String {
        switch role {
        case "Admin":
            return "crown.fill"
        case "Manager":
            return "person.2.fill"
        case "Musician":
            return "music.note"
        case "Member":
            return "person.fill"
        default:
            return "person.fill.questionmark"
        }
    }
}

// Информационная карточка о роли
struct RoleInfoCardView: View {
    var role: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Role Information")
                    .font(.headline)
            }
            
            Text(roleDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Список возможностей
            VStack(alignment: .leading, spacing: 12) {
                Text("Capabilities:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(roleCapabilities, id: \.self) { capability in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        
                        Text(capability)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // Описание роли
    var roleDescription: String {
        switch role {
        case "Admin":
            return "As an Admin, you have full control over the band's settings, members, and content. You can manage users, approve new members, and configure all aspects of BandSync."
        case "Manager":
            return "Managers help organize the band's activities, coordinate events, and assist with administration. You can create and edit events, manage setlists, and help with scheduling."
        case "Musician":
            return "As a Musician, you're an essential part of the band. You can view events, setlists, and participate in group discussions. Your focus is on the music!"
        case "Member":
            return "Members are part of the band group with basic access. You can view shared content, participate in discussions, and stay updated on band activities."
        default:
            return "This role provides specific access within BandSync. If you need more information, please contact your group's admin."
        }
    }
    
    // Список возможностей
    var roleCapabilities: [String] {
        switch role {
        case "Admin":
            return [
                "Manage members and roles",
                "Approve or reject join requests",
                "Create and edit all content",
                "Configure group settings",
                "Manage finances and payments"
            ]
        case "Manager":
            return [
                "Create and manage events",
                "Organize setlists and repertoire",
                "Coordinate schedules",
                "Send announcements to the band",
                "View financial information"
            ]
        case "Musician":
            return [
                "View and respond to events",
                "Access the band's setlists",
                "Participate in group discussions",
                "Submit song suggestions",
                "Track personal schedule"
            ]
        case "Member":
            return [
                "View band events and announcements",
                "Access shared content",
                "Participate in discussions",
                "View basic band information"
            ]
        default:
            return [
                "Specific permissions depend on your assigned role",
                "Contact your group's admin for more details"
            ]
        }
    }
}

