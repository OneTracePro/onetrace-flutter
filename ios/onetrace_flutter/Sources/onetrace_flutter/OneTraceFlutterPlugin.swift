import Flutter
import OneTrace
import UIKit

/// The `pro.onetrace/sdk` channel over the native OneTrace SDK, and the `pro.onetrace/feed_unread` event channel with the
/// unread count of the message feed while Dart listens to it.
public class OneTraceFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pro.onetrace/sdk", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(OneTraceFlutterPlugin(), channel: channel)
        FlutterEventChannel(name: "pro.onetrace/feed_unread", binaryMessenger: registrar.messenger())
            .setStreamHandler(FeedUnreadStream())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "init":
            OneTrace.setWrapper(name: args.string("wrapper"), version: args.string("wrapperVersion"))
            OneTrace.setup(OneTraceConfig(
                writeKey: args.string("writeKey"),
                host: args.string("host"),
                flushAt: args["flushAt"] as? Int ?? 20,
                flushInterval: TimeInterval(args["flushIntervalSeconds"] as? Int ?? 30),
                maxQueueSize: args["maxQueueSize"] as? Int ?? 1000,
                trackLifecycle: args["trackLifecycle"] as? Bool ?? true,
                openPushLinks: args["openPushLinks"] as? Bool ?? true,
                debug: args["debug"] as? Bool ?? false
            ))
        case "track":
            OneTrace.track(args.string("event"), args.values("properties"))
        case "screen":
            OneTrace.screen(args.string("name"), args.values("properties"))
        case "identify":
            OneTrace.identify(args["userId"] as? String, traits: args.values("traits"), userHash: args["userHash"] as? String)
        case "alias":
            OneTrace.alias(args.string("userId"), userHash: args["userHash"] as? String)
        case "reset":
            OneTrace.reset()
        case "flush":
            OneTrace.flush()
        case "setPushToken":
            OneTrace.setPushToken(args["token"] as? String, provider: args["provider"] as? String == "fcm" ? .fcm : .apns)
        case "notificationPermissionChanged":
            OneTrace.notificationPermissionChanged()
        case "notificationReceived":
            OneTrace.handleNotificationReceived(args["data"] as? [String: Any] ?? [:])
        case "notificationOpened":
            OneTrace.handleNotificationOpen(args["data"] as? [String: Any] ?? [:])
        case "pauseInAppMessages":
            OneTrace.pauseInAppMessages(args["paused"] as? Bool ?? false)
        case "fetchInAppMessages":
            OneTrace.fetchInAppMessages()
        case "fetchFeed":
            return OneTrace.fetchFeed { cards in result(cards.map(\.channelValue)) }
        case "feedCards":
            return result(OneTrace.feedCards.map(\.channelValue))
        case "feedUnreadCount":
            return result(OneTrace.feedUnreadCount)
        case "feedCardShown":
            if let card = Self.card(args) {
                OneTrace.feedCardShown(card)
            }
        case "feedCardClicked":
            if let card = Self.card(args) {
                OneTrace.feedCardClicked(card)
            }
        case "feedCardDismissed":
            if let card = Self.card(args) {
                OneTrace.feedCardDismissed(card)
            }
        case "openFeed":
            let language = args["language"] as? String
            Task { @MainActor in OneTrace.presentFeed(language: language) }
        case "anonymousId":
            return result(OneTrace.anonymousId)
        case "userId":
            return result(OneTrace.userId)
        case "installationId":
            return result(OneTrace.installationId)
        default:
            return result(FlutterMethodNotImplemented)
        }

        result(nil)
    }

    /// A card of the loaded feed by the token Dart passes; nil when it is no longer there.
    private static func card(_ args: [String: Any]) -> OneTraceFeedCard? {
        let token = args.string("token")
        return OneTrace.feedCards.first { $0.token == token }
    }
}

/// The unread count while Dart listens: the native observer starts on listen and is cancelled on cancel.
private final class FeedUnreadStream: NSObject, FlutterStreamHandler {
    private var observation: OneTraceObservation?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        observation?.cancel()
        observation = OneTrace.observeFeedUnread { events($0) }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        observation?.cancel()
        observation = nil
        return nil
    }
}

private extension OneTraceFeedCard {
    /// The card for the channel: dates as milliseconds since the epoch, `NSNull` for missing values.
    var channelValue: [String: Any] {
        [
            "token": token,
            "layout": layout.rawValue,
            "title": title,
            "body": Self.value(body),
            "imageUrl": Self.value(imageURL?.absoluteString),
            "buttonText": Self.value(buttonText),
            "buttonUrl": Self.value(buttonURL?.absoluteString),
            "pinned": pinned,
            "read": read,
            "createdAt": Self.value(createdAt.map(Self.milliseconds)),
            "expiresAt": Self.value(expiresAt.map(Self.milliseconds)),
            "opensOnTap": opensOnTap,
        ]
    }

    private static func value(_ value: Any?) -> Any {
        value ?? NSNull()
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String {
        self[key] as? String ?? ""
    }

    /// Event properties and traits: `NSNull` from the channel becomes nil.
    func values(_ key: String) -> [String: Any?] {
        (self[key] as? [String: Any] ?? [:]).mapValues { $0 is NSNull ? nil : $0 }
    }
}
