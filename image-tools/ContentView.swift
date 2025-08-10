//
//  ContentView.swift
//  image-tools
//
//  Created by Raphael Wennmacher on 07.08.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ImageToolsViewModel()

    var body: some View {
        MainView(vm: vm)
    }
}

#Preview {
    MainView(vm: ImageToolsViewModel())
}
