//
//  SampleView.swift
//
//  Created by jjonami on 2021/02/03.

import Foundation
import Combine

class WebViewModel: ObservableObject {
    
    var webViewNavigationPublisher = PassthroughSubject<WebViewNavigation, Never>()
    var showWebTitle = PassthroughSubject<String, Never>()
    var showLoader = PassthroughSubject<Bool, Never>()
    var valuePublisher = PassthroughSubject<String, Never>()
    
}


enum WebViewNavigation {
    case backward, forward, reload
}

enum WebUrl {
    case localUrl, publicUrl
}
