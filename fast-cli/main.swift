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

typealias FastEvents = (speed: Int, unit: String)

class NotificationScriptMessageHandler: NSObject, WKScriptMessageHandler {

    /// This was supposed to be a Subscriber but I kept getting a `Fatal error: API Violation: received an unexpected value before receiving a Subscription: file`. Perhaps I should make a custom publisher? 🤷‍♀️
    let observer: PassthroughSubject<FastEvents, Never>

    init(observer: PassthroughSubject<FastEvents, Never>) {
        self.observer = observer
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? NSDictionary,
            let units = dict["units"] as? String,
            let valueString = dict["value"] as? String,
            let value = Int(valueString) else {
                return
        }
        /// Possible substitution: let value = (dict["value"] as? String).map{ Int($0) }
        _ = observer.send((value, units as String))
    }
}

let userContentController = WKUserContentController()
let subject = PassthroughSubject<FastEvents, Never>()
let handler = NotificationScriptMessageHandler(observer: subject)
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


let nonDuplicateEvents = subject.removeDuplicates { (x, y) -> Bool in
    return x.0 == y.0 && x.1 == y.1
}

_ = nonDuplicateEvents.first().sink { (_) in
    print("Started receiving speed data - waiting for it to stabilize.")
}

enum TimeoutError {
    case stoppedReceivingEvents
}
_ = nonDuplicateEvents.scan(nil, { (_, currentEvent) in
        return currentEvent
    }).timeout(5.0, scheduler: DispatchQueue.main)
    .last()
    .sink(receiveValue: { (event) in
        if let finalEvent = event {
            print("Your speed is \(finalEvent.speed) \(finalEvent.unit)")
            NSApplication.shared.terminate(nil)
        }
    })


var delegate: XCCheckDelegate? = XCCheckDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
delegate = nil
