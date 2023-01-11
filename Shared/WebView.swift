//
//  SampleView.swift
//
//  Created by jjonami on 2021/02/03.

import SwiftUI

import UIKit
import SwiftUI
import Combine
import WebKit


// 주고받을 형식에 대한 프로토콜 생성
protocol WebViewHandlerDelegate {
    func receivedJsonValueFromWebView(value: [String: Any?])
    func receivedStringValueFromWebView(value: String)
}

struct WebView: UIViewRepresentable {
    var url: WebUrl
    @ObservedObject var viewModel: WebViewModel
    
    func receivedJsonValueFromWebView(value: [String : Any?]) {
        print("JSON 데이터가 웹으로부터 옴: \(value)")
    }
    
    func receivedStringValueFromWebView(value: String) {
        print("String 데이터가 웹으로부터 옴: \(value)")
    }
    
    // 변경 사항을 전달하는 데 사용하는 사용자 지정 인스턴스를 만듭니다.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 뷰 객체를 생성하고 초기 상태를 구성합니다. 딱 한 번만 호출됩니다.
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false  // JavaScript가 사용자 상호 작용없이 창을 열 수 있는지 여부
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController.add(self.makeCoordinator(), name: "iOSNative")
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator    // 웹보기의 탐색 동작을 관리하는 데 사용하는 개체
        webView.allowsBackForwardNavigationGestures = true    // 가로로 스와이프 동작이 페이지 탐색을 앞뒤로 트리거하는지 여부
        webView.scrollView.isScrollEnabled = true    // 웹보기와 관련된 스크롤보기에서 스크롤 가능 여부
        return webView
    }
    
    // 지정된 뷰의 상태를 다음의 새 정보로 업데이트합니다.
    func updateUIView(_ webView: WKWebView, context: Context) {
        if url == .localUrl {
            // Load local website
            if let url = Bundle.main.url(forResource: "LocalWebsite", withExtension: "html", subdirectory: "www") {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
        } else if url == .publicUrl {
            // Load a public website, for example I used here google.com
            if let url = URL(string: "https://www.google.com") {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    // 탐색 변경을 수락 또는 거부하고 탐색 요청의 진행 상황을 추적
    class Coordinator : NSObject, WKNavigationDelegate {
        
        var parent: WebView
        var delegate: WebViewHandlerDelegate?
        var valueSubscriber: AnyCancellable? = nil
        var webViewNavigationSubscriber: AnyCancellable? = nil
        
        
        // 생성자
        init(_ uiWebView: WebView) {
            self.parent = uiWebView
            self.delegate = parent as? WebViewHandlerDelegate
        }
        
        // 소멸자
        deinit {
            valueSubscriber?.cancel()
            webViewNavigationSubscriber?.cancel()
        }
        
        // 탐색이 완료 되었음
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Get the title of loaded webcontent
            webView.evaluateJavaScript("document.title") { (response, error) in
                if let error = error {
                    print("Error getting title")
                    print(error.localizedDescription)
                }
                
                guard let title = response as? String else {
                    return
                }
                
                self.parent.viewModel.showWebTitle.send(title)
            }
            
            /* An observer that observes 'viewModel.valuePublisher' to get value from TextField and
             pass that value to web app by calling JavaScript function */
            valueSubscriber = parent.viewModel.valuePublisher.receive(on: RunLoop.main).sink(receiveValue: { value in
                let javascriptFunction = "valueGotFromIOS(\(value));"
                webView.evaluateJavaScript(javascriptFunction) { (response, error) in
                    if let error = error {
                        print("Error calling javascript:valueGotFromIOS()")
                        print(error.localizedDescription)
                    } else {
                        print("Called javascript:valueGotFromIOS()")
                    }
                }
            })
            
            // Page loaded so no need to show loader anymore
            self.parent.viewModel.showLoader.send(false)
            print("탐색이 완료")
        }
        
        // 웹보기가 기본 프레임에 대한 내용을 수신하기 시작했음
        func webView(_ webView: WKWebView,
                     didCommit navigation: WKNavigation!) {
            parent.viewModel.showLoader.send(true)
            print("내용을 수신하기 시작");
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.viewModel.showLoader.send(false)
        }
        
        // 초기 탐색 프로세스 중에 오류가 발생했음 - Error Handler
        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation: WKNavigation!,
                     withError: Error) {
            parent.viewModel.showLoader.send(false)
            print("초기 탐색 프로세스 중에 오류가 발생했음")
        }
        
        // 탐색 중에 오류가 발생했음 - Error Handler
        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            parent.viewModel.showLoader.send(false)
            print("탐색 중에 오류가 발생했음")
            print(error)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            
            print("기본 프레임에서 탐색이 시작되었음")
            parent.viewModel.showLoader.send(true)
            self.webViewNavigationSubscriber = self.parent.viewModel
                .webViewNavigationPublisher.receive(on: RunLoop.main)
                .sink(receiveValue:
                        { navigation in
                            switch navigation {
                            case .backward:
                                if webView.canGoBack {
                                    webView.goBack()
                                }
                            case .forward:
                                if webView.canGoForward {
                                    webView.goForward()
                                }
                            case .reload:
                                webView.reload()
                            }
                        })
        }
        
        
        // 지정된 기본 설정 및 작업 정보를 기반으로 새 콘텐츠를 탐색 할 수있는 권한을 대리인에게 요청
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            //            if let host = navigationAction.request.url?.host {
            //                // 특정 도메인을 제외한 도메인을 연결하지 못하게 할 수 있다.
            //                if host != "lawshop.kr" {
            //                    return decisionHandler(.cancel)
            //                }
            //            }
            return decisionHandler(.allow)
        }
        
        
        
    }
}

// Coordinator 클래스에 WKScriptMessageHandler 프로토콜 추가 적용
extension WebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Make sure that your passed delegate is called
        if message.name == "iOSNative" {
            if let body = message.body as? [String: Any?] {
                print("JSON value received from web is: \(body)")
            } else if let body = message.body as? String {
                print("String value received from web is: \(body)")
            }
        }
    }
}
