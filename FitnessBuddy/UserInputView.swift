import SwiftUI

struct UserInputView: View {
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var experienceLevel: String = "Beginner 🏃‍♂️"
    
    let experienceLevels = ["Beginner 🏃‍♂️", "Intermediate 🏋️‍♀️", "Advanced 🧗‍♂️"]
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.systemGray6), Color(UIColor.systemGray5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .center, spacing: 20) {
                Text("Let's Get to Know You!")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 40)
                
                Group {
                    TextField("Name", text: $name)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.vertical, 10)
                    
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.vertical, 10)
                    
                    TextField("Height (ft/in)", text: $height)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.vertical, 10)
                    
                    TextField("Weight (lbs)", text: $weight)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.vertical, 10)
                    
                    Picker(selection: $experienceLevel, label: Text("Experience Level")) {
                        ForEach(experienceLevels, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.vertical, 10)
                }
                .padding([.leading, .trailing], 40)
                
                Spacer()
                
                Button(action: {
                    // Action to save the data and navigate to the next screen
                }) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding([.leading, .trailing], 40)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct UserInputView_Previews: PreviewProvider {
    static var previews: some View {
        UserInputView()
    }
}
