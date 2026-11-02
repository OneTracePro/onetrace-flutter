import Flutter
import OneTrace
import UIKit

/// The `pro.onetrace/sdk` channel over the native OneTrace SDK.
public class OneTraceFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pro.onetrace/sdk", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(OneTraceFlutterPlugin(), channel: channel)
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
