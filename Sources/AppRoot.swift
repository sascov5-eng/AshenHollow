import SwiftUI
import SpriteKit

@main
struct AshenHollowApp: App {
    var body: some Scene {
        WindowGroup {
            DemoLauncherView()
        }
    }
}

private struct DemoLauncherView: View {
    @State private var launchMode: DemoLaunchMode?

    var body: some View {
        if let launchMode {
            GameView(launchMode: launchMode)
                .ignoresSafeArea()
        } else {
            VStack(spacing: 18) {
                Text("ASHEN HOLLOW")
                    .font(.title.bold())

                if DemoSaveStore().hasSave {
                    Button("CONTINUE") {
                        launchMode = .continueGame
                    }
                }

                Button("NEW GAME") {
                    launchMode = .newGame
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .foregroundStyle(Color.white)
            .ignoresSafeArea()
        }
    }
}
