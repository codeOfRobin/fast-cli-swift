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

typealias FastEvents = (speed: Int, unit: String)

enum TimeoutError {
    case stoppedReceivingEvents
}

let STDERR = FileHandle.standardError
let STDOUT = FileHandle.standardOutput

extension FileHandle {
    internal func write(string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

class FastCLIDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {

    /// This was supposed to be a Subscriber but I kept getting a `Fatal error: API Violation: received an unexpected value before receiving a Subscription: file`. Perhaps I should make a custom publisher? 🤷‍♀️
    var observer: PassthroughSubject<FastEvents, Never>?
    var webView: WKWebView?
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let userContentController = WKUserContentController()
        let subject = PassthroughSubject<FastEvents, Never>()

        /// Why can't this be a subscriber?
        userContentController.add(self, name: "notification")

        let source = """
document.querySelector("#speed-value").addEventListener('DOMSubtreeModified', function(e) {
    let units = document.querySelector("#speed-units").innerText
    let value = e.srcElement.innerText
    if (value) {
        window.webkit.messageHandlers.notification.postMessage({ value: value, units: units });
    }
})
"""

        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: CGRect.init(origin: .zero, size: CGSize(width: 100, height: 100)), configuration: configuration)
        
        self.webView = webView
        self.observer = subject
        
        let nonDuplicateEvents = subject.removeDuplicates { (x, y) -> Bool in
            return x.0 == y.0 && x.1 == y.1
        }

        /// Apparently, these need to exist and cant' be a `_`?
        let x = nonDuplicateEvents.first().sink { (_) in
            STDOUT.write(string: "Started receiving speed data - waiting for it to stabilize.")
        }
        
        /// Apparently, these need to exist and cant' be a `_`?
        let y = nonDuplicateEvents.scan(nil, { (_, currentEvent) in
                return currentEvent
            }).timeout(5.0, scheduler: DispatchQueue.main)
            .last()
            .sink(receiveValue: { (event) in
                if let finalEvent = event {
                    STDOUT.write(string: "Your speed is \(finalEvent.speed) \(finalEvent.unit)")
                    NSApplication.shared.terminate(nil)
                }
            })
        cancellables.insert(x)
        cancellables.insert(y)
        
        let fastURL = URL(string: "https://fast.com")!
        webView.load(URLRequest(url: fastURL))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? NSDictionary,
            let units = dict["units"] as? String,
            let valueString = dict["value"] as? String,
            let value = Int(valueString) else {
                return
        }
        /// Possible substitution: let value = (dict["value"] as? String).map{ Int($0) }
        let _ = observer?.send((value, units as String))
    }
}

var delegate: FastCLIDelegate? = FastCLIDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
delegate = nil
