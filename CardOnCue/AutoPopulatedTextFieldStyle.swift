import SwiftUI

/// Custom text field style that provides visual indicators for auto-populated fields
struct AutoPopulatedTextFieldStyle: TextFieldStyle {
    let isAutoPopulated: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                isAutoPopulated
                    ? Color.appBlue.opacity(0.05)
                    : Color.white
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isAutoPopulated ? Color.appBlue.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
            .appLightTextFieldContent()
    }
}

#Preview {
    VStack(spacing: 20) {
        FormSection(title: "Regular Field", icon: "person.fill") {
            TextField("Enter name", text: .constant(""))
                .textFieldStyle(AutoPopulatedTextFieldStyle(isAutoPopulated: false))
        }

        FormSection(title: "Auto-populated Field", icon: "person.fill") {
            TextField("Enter name", text: .constant("John Smith"))
                .textFieldStyle(AutoPopulatedTextFieldStyle(isAutoPopulated: true))
        }
    }
    .padding()
    .background(Color.appBackground)
}
