package pro.onetrace.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import pro.onetrace.sdk.OneTrace
import pro.onetrace.sdk.OneTraceConfig

/**
 * The `pro.onetrace/sdk` channel over the native OneTrace SDK. The SDK starts when Dart calls `OneTrace.init()`, after
 * the Flutter activity was created, so the activity is attached to it explicitly: its launch intent may carry a tapped
 * notification, and in-app messages are shown over it.
 */
class OneTracePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "pro.onetrace/sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> init(call)
            "track" -> OneTrace.track(call.string("event"), call.map("properties"))
            "screen" -> OneTrace.screen(call.string("name"), call.map("properties"))
            "identify" -> OneTrace.identify(call.argument<String>("userId"), call.map("traits"))
            "alias" -> OneTrace.alias(call.string("userId"))
            "reset" -> OneTrace.reset()
            "flush" -> OneTrace.flush()
            "setPushToken" -> OneTrace.setPushToken(
                call.argument<String>("token"),
                if (call.argument<String>("provider") == "apns") OneTrace.PushProvider.APNS else OneTrace.PushProvider.FCM,
            )
            "notificationPermissionChanged" -> OneTrace.notificationPermissionChanged()
            "notificationReceived" -> OneTrace.notificationReceived(call.strings("data"))
            "notificationOpened" -> OneTrace.notificationOpened(activity ?: context, call.strings("data"))
            "pauseInAppMessages" -> OneTrace.pauseInAppMessages(call.argument<Boolean>("paused") == true)
            "fetchInAppMessages" -> OneTrace.fetchInAppMessages()
            "anonymousId" -> return result.success(OneTrace.anonymousId)
            "userId" -> return result.success(OneTrace.userId)
            "installationId" -> return result.success(OneTrace.installationId)
            else -> return result.notImplemented()
        }

        result.success(null)
    }

    private fun init(call: MethodCall) {
        OneTrace.setWrapper(call.string("wrapper"), call.string("wrapperVersion"))
        OneTrace.init(
            context,
            OneTraceConfig(
                writeKey = call.string("writeKey"),
                host = call.string("host"),
                flushAt = call.argument<Int>("flushAt") ?: 20,
                flushIntervalSeconds = call.argument<Number>("flushIntervalSeconds")?.toLong() ?: 30,
                maxQueueSize = call.argument<Int>("maxQueueSize") ?: 1000,
                trackLifecycle = call.argument<Boolean>("trackLifecycle") ?: true,
                openPushLinks = call.argument<Boolean>("openPushLinks") ?: true,
                debug = call.argument<Boolean>("debug") ?: false,
            ),
        )
        activity?.let(OneTrace::attachActivity)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        OneTrace.attachActivity(binding.activity)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activity = null
    }

    /** A notification tapped while the activity was running (`singleTop`); other plugins still see the intent. */
    override fun onNewIntent(intent: Intent): Boolean {
        OneTrace.handleIntent(activity ?: context, intent)

        return false
    }

    private fun MethodCall.string(key: String): String = argument<String>(key).orEmpty()

    private fun MethodCall.map(key: String): Map<String, Any?> = argument<Map<String, Any?>>(key).orEmpty()

    private fun MethodCall.strings(key: String): Map<String, String> = argument<Map<String, String>>(key).orEmpty()
}
