import SwiftUI

struct GameView: View {
    let launchMode: DemoLaunchMode

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("ASHEN HOLLOW")
                    .font(.largeTitle)
                    .foregroundColor(.white)

                Text("iOS launch test")
                    .foregroundColor(.gray)

                Text("Build OK")
                    .foregroundColor(.green)
            }
        }
    }
}
