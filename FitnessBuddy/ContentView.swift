import SwiftUI

struct ContentView: View {
    @State private var currentEmojiIndex = 0
    private let emojis = ["🏃‍♂️", "🏋️‍♂️", "🏋️‍♀️", "🤸‍♂️", "🤸‍♀️"]
    @State private var animateShapes = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGray6), Color(UIColor.systemGray5)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                // Animated Background Shapes
                GeometryReader { geometry in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                        .position(x: animateShapes ? geometry.size.width * 0.2 : geometry.size.width * 0.8,
                                  y: animateShapes ? geometry.size.height * 0.3 : geometry.size.height * 0.7)
                        .animation(Animation.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animateShapes)
                    
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                        .position(x: animateShapes ? geometry.size.width * 0.8 : geometry.size.width * 0.2,
                                  y: animateShapes ? geometry.size.height * 0.8 : geometry.size.height * 0.3)
                        .animation(Animation.easeInOut(duration: 14).repeatForever(autoreverses: true), value: animateShapes)
                    
                    // New third circle moving diagonally
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)
                        .position(x: animateShapes ? geometry.size.width * 0.1 : geometry.size.width * 0.9,
                                  y: animateShapes ? geometry.size.height * 0.9 : geometry.size.height * 0.1)
                        .animation(Animation.easeInOut(duration: 20).repeatForever(autoreverses: true), value: animateShapes)
                }
                
                VStack {
                    Spacer()
                    
                    Text(emojis[currentEmojiIndex])
                        .font(.system(size: 100))
                        .padding(.bottom, 20)
                        .transition(.opacity)
                    
                    Text("Welcome to Fitness Buddy!")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Text("Your personal trainer for gym beginners. Start your fitness journey with guided workouts and tips.")
                        .font(.system(size: 18, design: .default))
                        .multilineTextAlignment(.center)
                        .padding([.leading, .trailing], 40)
                    
                    // Neumorphism Button
                    NavigationLink(destination: UserInputView()) {
                        Text("Get Started")
                            .font(.system(size: 20, design: .default))
                            .foregroundColor(.black)
                            .padding()
                            .frame(width: 200, height: 50)
                            .background(
                                Color.gray.opacity(0.2)
                                    .cornerRadius(10)
                                    .shadow(color: Color.white, radius: 10, x: -10, y: -10)
                                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 10, y: 10)
                            )
                    }
                    .padding(.top, 30)
                    
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                startEmojiTimer()
                animateShapes.toggle() // Start the shape animation
            }
        }
    }
    
    func startEmojiTimer() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            withAnimation {
                currentEmojiIndex = (currentEmojiIndex + 1) % emojis.count
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
