//
//  Copyright 2020 PLAID, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import KarteCore
import KarteUtilities
import WebKit

internal class IAMProcess: NSObject {
    static let processPool = WKProcessPool()

    var sceneId: SceneId
    private var window: IAMWindow?
    private var webView: IAMWebView?
    private var configuration: IAMProcessConfiguration
    private var isWindowFucus = false

    var isActivated: Bool {
        webView != nil
    }

    var isPresenting: Bool {
        window != nil
    }

    var isSuppressed = false

    init(view: UIView, configuration: IAMProcessConfiguration) {
        self.sceneId = SceneId(view: view)
        self.configuration = configuration

        super.init()
        setupWebView()
    }

    func terminate() {
        self.window = nil
        self.webView = nil
    }

    func handle(response: [String: JSONValue]) {
        setWindowFocus(response: response)
        webView?.handle(response: response)
    }

    func handleChangePv() {
        webView?.handleChangePv()
    }

    func handleView(values: [String: JSONValue]) {
        webView?.handleView(values: values)
    }

    func activate() {
        if webView == nil {
            setupWebView()
        }
        guard let webView = webView else {
            Logger.debug(tag: .inAppMessaging, message: "Can't activate WebView because WebView is not initialized.")
            return
        }
        if webView.bindForWindowIfNeeded() {
            Logger.debug(tag: .inAppMessaging, message: "WebView is bound to Window.")
        } else {
            Logger.debug(tag: .inAppMessaging, message: "WebView is not bound to Window.")
        }
    }

    func reload() {
        reload(url: configuration.generateOverlayURL())
    }

    func reload(url: URL?) {
        guard let url = url else {
            return
        }
        webView?.reload(url: url)
    }

    func dismiss(mode: IAMWebView.ResetMode = .hard) {
        webView?.reset(mode: mode)
    }

    deinit {
    }
}

extension IAMProcess {
    func viewDidAppearFromViewController(_ viewController: UIViewController) {
        Logger.verbose(tag: .inAppMessaging, message: "ViewDidAppear: \(viewController)")
        if RemoteViewDetector.detect(viewController, lessThanWindowLevel: IAMWindow.windowLevel) {
            Logger.debug(tag: .inAppMessaging, message: "Detected the remote view: \(viewController)")
            webView?.reset(mode: .hard)
        }
    }

    func presentViewController(_ viewController: UIViewController, in window: UIWindow?) {
        Logger.verbose(tag: .inAppMessaging, message: "PresentViewController: \(viewController)")
        resetIfNeeded(viewController: viewController, in: window)
    }

    func dismissViewController(_ viewController: UIViewController, in window: UIWindow?) {
        Logger.verbose(tag: .inAppMessaging, message: "DismissViewController: \(viewController)")
        resetIfNeeded(viewController: viewController, in: window)
    }

    func pushViewController(_ viewController: UIViewController?, to navigationController: UINavigationController, in window: UIWindow?) {
        Logger.verbose(tag: .inAppMessaging, message: "PushViewController: \(viewController?.description ?? "")")
        resetIfNeeded(viewController: navigationController, in: window)
    }

    func popViewController(_ viewController: UIViewController?, from navigationController: UINavigationController, in window: UIWindow?) {
        Logger.verbose(tag: .inAppMessaging, message: "PopViewController: \(viewController?.description ?? "")")
        resetIfNeeded(viewController: navigationController, in: window)
    }

    func setSelectedViewController(_ viewController: UIViewController, in window: UIWindow?) {
        Logger.verbose(tag: .inAppMessaging, message: "SetSelectedViewController: \(viewController)")
        resetIfNeeded(viewController: viewController, in: window)
    }
}

extension IAMProcess {
    private func setupWebView() {
        if let url = configuration.generateOverlayURL() {
            let configuration = WKWebViewConfiguration()
            configuration.processPool = InAppMessaging.shared.processPool ?? IAMProcess.processPool
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
            if #available(iOS 16.0, *) {
                configuration.allowsInlineMediaPlayback = true
            }
            if #available(iOS 14.0, *), configuration.responds(to: #selector(setter: WKWebViewConfiguration.limitsNavigationsToAppBoundDomains)) {
                configuration.limitsNavigationsToAppBoundDomains = true
            }

            let userContentController = WKUserContentController()
            for name in JsMessageName.allCases {
                userContentController.add(self, name: name.rawValue)
            }
            configuration.userContentController = userContentController

            let webView = IAMWebView(sceneId: sceneId, configuration: configuration, url: url)
            webView.delegate = self

            self.webView = webView

            activate()
        }
    }

    private func setWindowFocus(response: [String: JSONValue]) {
        let messages = response.jsonArray(forKey: "messages") ?? []
        guard !messages.isEmpty else {
            return
        }

        let focusables = messages.dictionaries.map {
            $0.bool(forKeyPath: "action.native_app_window_focusable") ?? false
        }
        self.isWindowFucus = focusables.contains(true)
    }

    private func resetIfNeeded(viewController: UIViewController, in window: UIWindow?) {
        if shouldReset(from: viewController, in: window) {
            Logger.verbose(tag: .inAppMessaging, message: "Will hide in-app messaging.")
            webView?.reset(mode: .soft)
            configuration.app.pvService?.changePv(sceneId)
        }
    }

    private func shouldReset(from viewController: UIViewController, in window: UIWindow?) -> Bool {
        guard let window = window, !window.isKind(of: IAMWindow.self) else {
            return false
        }
        guard IAMWindow.windowLevel > window.windowLevel else {
            return false
        }

        var viewController = viewController
        while let parentViewController = viewController.parent {
            viewController = parentViewController
        }

        var modalPresentationStyle = viewController.modalPresentationStyle
        if window.traitCollection.containsTraits(in: UITraitCollection(horizontalSizeClass: .compact)) {
            if modalPresentationStyle == .pageSheet || modalPresentationStyle == .formSheet {
                modalPresentationStyle = .fullScreen
            }
        }

        if let presentationController = viewController.popoverPresentationController, modalPresentationStyle == .popover {
            if #available(iOS 8.3, *) {
                if let style = presentationController.delegate?.adaptivePresentationStyle?(for: presentationController, traitCollection: window.traitCollection) {
                    modalPresentationStyle = style
                } else if let style = presentationController.delegate?.adaptivePresentationStyle?(for: presentationController) {
                    modalPresentationStyle = style
                } else {
                    modalPresentationStyle = presentationController.adaptivePresentationStyle
                }
            }
        }

        let isFullScreen = modalPresentationStyle == .fullScreen || modalPresentationStyle == .currentContext
        let isHeadWindow: Bool
        if let headWindow = WindowDetector.retrieveRelatedWindows(view: window).first {
            isHeadWindow = window == headWindow
        } else {
            isHeadWindow = false
        }

        return isFullScreen && isHeadWindow
    }

    private func handleJsMessage(_ message: JsMessage) {
        switch message {
        case .event(let data):
            handleJsMessageEvent(data)

        case .openUrl(let data):
            handleJsMessageOpenURL(data)

        case .stateChanged(let data):
            handleJsMessageStateChanged(data)

        case .visibility(let data):
            handleJsMessageVisibility(data)
        }
    }

    private func handleJsMessageEvent(_ data: JsMessage.EventData) {
        Tracker.track(view: window, data: data)
        notifyCampaignOpenOrClose(data)
    }

    private func handleJsMessageOpenURL(_ data: JsMessage.OpenURLData) {
        webView?.openURL(data.url, isReset: !data.isTargetBlank)
    }

    private func handleJsMessageStateChanged(_ data: JsMessage.StateChangedData) {
        webView?.changeJavaScript(state: data.state)
    }

    private func handleJsMessageVisibility(_ data: JsMessage.VisibilityData) {
        webView?.changeVisibility(state: data.state)
    }

    private func notifyCampaignOpenOrClose(_ data: JsMessage.EventData) {
        let values = data.values
        guard let campaignId = values.string(forKeyPath: "message.campaign_id"), let shortenId = values.string(forKeyPath: "message.shorten_id") else {
            return
        }

        switch data.eventName {
        case .messageOpen:
            notifyCampaignOpen(campaignId: campaignId, shortenId: shortenId)

        case .messageClick, .messageClose:
            notifyCampaignClose(campaignId: campaignId, shortenId: shortenId)

        default:
            break
        }
    }

    private func notifyCampaignOpen(campaignId: String, shortenId: String) {
        let iam = InAppMessaging.shared
        guard let delegate = iam.delegate else {
            return
        }

        if #available(iOS 13.0, *) {
            let selector = #selector(InAppMessagingDelegate.inAppMessagingIsPresented(_:campaignId:shortenId:onScene:))
            if (delegate as AnyObject).responds(to: selector), let scene = window?.windowScene {
                delegate.inAppMessagingIsPresented?(iam, campaignId: campaignId, shortenId: shortenId, onScene: scene)
                return
            }
        }
        delegate.inAppMessagingIsPresented?(iam, campaignId: campaignId, shortenId: shortenId)
    }

    private func notifyCampaignClose(campaignId: String, shortenId: String) {
        let iam = InAppMessaging.shared
        guard let delegate = iam.delegate else {
            return
        }

        if #available(iOS 13.0, *) {
            let selector = #selector(InAppMessagingDelegate.inAppMessagingIsDismissed(_:campaignId:shortenId:onScene:))
            if (delegate as AnyObject).responds(to: selector), let scene = window?.windowScene {
                delegate.inAppMessagingIsDismissed?(iam, campaignId: campaignId, shortenId: shortenId, onScene: scene)
                return
            }
        }
        delegate.inAppMessagingIsDismissed?(iam, campaignId: campaignId, shortenId: shortenId)
    }
}

extension IAMProcess: IAMWebViewDelegate {
    func showInAppMessagingWebView(_ webView: IAMWebView) -> Bool {
        if let superview = webView.superview, superview.isKind(of: IAMWindow.self) {
            Logger.verbose(tag: .inAppMessaging, message: "Cancelled showing in-app messaging because already presented.")
            return true
        }

        if RemoteViewDetector.detect(lessThanWindowLevel: IAMWindow.windowLevel, scenePersistentIdentifier: sceneId.identifier) {
            Logger.info(tag: .inAppMessaging, message: "Cancelled showing in-app messaging because detected remote view.")
            return false
        }

        if let window = IAMWindow(sceneId: sceneId) {
            window.present(webView: webView, isFocus: isWindowFucus)
            self.window = window
            return true
        } else {
            Logger.warn(tag: .inAppMessaging, message: "Cancelled showing in-app messaging because scene not found.")
            return false
        }
    }

    func hideInAppMessagingWebView(_ webView: IAMWebView) -> Bool {
        if window != nil {
            self.window = nil
        }
        return true
    }

    func inAppMessagingWebView(_ webView: IAMWebView, shouldOpenURL url: URL) -> Bool {
        let iam = InAppMessaging.shared
        guard let delegate = iam.delegate else {
            return true
        }

        if #available(iOS 13.0, *) {
            let selector = #selector(InAppMessagingDelegate.inAppMessaging(_:shouldOpenURL:onScene:))
            if (delegate as AnyObject).responds(to: selector), let scene = WindowSceneDetector.retrieveWindowScene(from: sceneId.identifier) {
                // swiftlint:disable:next force_unwrapping
                return delegate.inAppMessaging!(iam, shouldOpenURL: url, onScene: scene)
            }
        }
        return delegate.inAppMessaging?(iam, shouldOpenURL: url) ?? true
    }
}

extension IAMProcess: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let message = try? JsMessage(scriptMessage: message) else {
            Logger.debug(tag: .inAppMessaging, message: "Can't parse message.")
            return
        }

        Logger.debug(tag: .inAppMessaging, message: "Received message: \(message)")
        handleJsMessage(message)
    }
}
