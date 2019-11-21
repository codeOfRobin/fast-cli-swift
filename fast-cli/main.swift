//
//  main.swift
//  fast-cli
//
//  Created by Robin Malhotra on 17/11/19.
//  Copyright © 2019 Robin Malhotra. All rights reserved.
//

import Foundation
import WebKit
import AppKit
import Combine


let fastURL = URL(string: "https://fast.com")!

class NotificationScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.body)
    }
}

let userContentController = WKUserContentController()
let handler = NotificationScriptMessageHandler()
userContentController.add(handler, name: "notification")

let source = """
document.querySelector("#speed-value").addEventListener('DOMSubtreeModified', function(e) {
    let units = document.querySelector("#speed-units").innerText
    let value = e.srcElement.innerText
    if (value) {
        window.webkit.messageHandlers.notification.postMessage({ value: value, units: units });
    }
})
"""

let userScript = WKUserScript(source: source,
                              injectionTime: .atDocumentEnd,
                              forMainFrameOnly: true)
userContentController.addUserScript(userScript)

let configuration = WKWebViewConfiguration()
configuration.userContentController = userContentController

let webview = WKWebView(frame: CGRect.init(origin: .zero, size: CGSize(width: 100, height: 100)), configuration: configuration)
webview.load(URLRequest.init(url: fastURL))

class XCCheckDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
    }
}

var delegate: XCCheckDelegate? = XCCheckDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
delegate = nil
