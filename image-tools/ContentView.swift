//
//  ContentView.swift
//  image-tools
//
//  Created by Raphael Wennmacher on 07.08.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ImageToolsViewModel()
    @StateObject private var formatDropdown = FormatDropdownController()

    var body: some View {
        MainView(vm: vm)
            .environmentObject(formatDropdown)
    }
}

#Preview {
    MainView(vm: ImageToolsViewModel())
        .environmentObject(FormatDropdownController())
}
