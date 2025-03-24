import SwiftUI

struct PINSetupView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var pinCode = ""
    @State private var confirmPinCode = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create PIN Code")
                .font(.title)
                .bold()
            
            Text("This PIN will be used as an additional security factor")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            SecureField("Enter PIN (6 digits)", text: $pinCode)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: pinCode) { newValue in
                    if newValue.count > 6 {
                        pinCode = String(newValue.prefix(6))
                    }
                }
            
            SecureField("Confirm PIN", text: $confirmPinCode)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: confirmPinCode) { newValue in
                    if newValue.count > 6 {
                        confirmPinCode = String(newValue.prefix(6))
                    }
                }
            
            Button(action: savePIN) {
                Text("Save PIN")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!isFormValid)
            .padding(.horizontal)
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("PIN Setup"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successfully") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    private var isFormValid: Bool {
        return pinCode.count == 6 && pinCode == confirmPinCode && pinCode.allSatisfy { $0.isNumber }
    }
    
    private func savePIN() {
        do {
            try PINCodeManager.shared.savePINCode(pinCode)
            alertMessage = "PIN code set successfully!"
            showingAlert = true
        } catch {
            alertMessage = "Error saving PIN: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}
