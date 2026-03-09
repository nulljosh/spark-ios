import SwiftUI

@main
struct SparkApp: App {
    @State private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(appState)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: showSplash)
            .task {
                try? await Task.sleep(for: .seconds(1.2))
                showSplash = false
            }
        }
    }
}

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.sparkBlue
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.white)

                Text("Spark")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
