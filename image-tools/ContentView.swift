import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel

    var body: some View {
        MainView()
    }
}

#Preview {
    MainView()
        .environmentObject(ImageToolsViewModel())
}
