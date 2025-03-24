import SwiftUI
import FirebaseAuth

struct RoleView: View {
    var userRole: String

    var body: some View {
        VStack {
            Text("🔷 Your role: \(userRole)")
                .font(.largeTitle)
                .bold()
                .padding()

            Button(action: logout) {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            print("🚪 User signed out")
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
        }
    }
}

