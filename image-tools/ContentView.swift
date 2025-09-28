//
//  ContentView.swift
//  image-tools
//
//  Created by Raphael Wennmacher on 07.08.25.
//

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
