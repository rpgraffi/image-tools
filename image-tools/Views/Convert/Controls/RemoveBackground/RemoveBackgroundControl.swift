import SwiftUI

struct RemoveBackgroundControl: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    
    var body: some View {
        CircleIconToggle(
            isOn: $vm.removeBackground,
            icon: Image(systemName: "person.and.background.dotted"),
            text: nil
        )
        .help(String(localized:"Remove background"))
    }
}


