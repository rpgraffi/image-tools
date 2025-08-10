//
//  image_toolsApp.swift
//  image-tools
//
//  Created by Raphael Wennmacher on 07.08.25.
//

import SwiftUI

@main
struct ImageToolsApp: App {
    @StateObject private var vm = ImageToolsViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(vm: vm)
                .background(.clear)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
