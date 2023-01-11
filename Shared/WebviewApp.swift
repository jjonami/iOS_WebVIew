//
//  WebviewApp.swift
//  Shared
//
//  Created by YoungEun Jo on 2023/01/09.
//

import SwiftUI

@main
struct WebviewApp: App {
    var url: String = "https://codecocos.github.io/"
    @ObservedObject var viewModel = WebViewModel()
    
var body: some Scene {
        WindowGroup {
            SampleView()
            
        }
    }
}
