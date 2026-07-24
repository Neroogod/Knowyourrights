package ng.knowyourrights.knowyourrights_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ng.knowyourrights/safety"
    private val smsPermissionRequest = 7042
    private var pendingSms: Pair<String, String>? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            if (call.method != "sendDirectSms") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val phone = call.argument<String>("phone")
            val message = call.argument<String>("message")
            if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                result.error("invalid_arguments", "Phone and message are required", null)
                return@setMethodCallHandler
            }
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) !=
                    PackageManager.PERMISSION_GRANTED
            ) {
                pendingSms = phone to message
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.SEND_SMS),
                    smsPermissionRequest,
                )
            } else {
                sendSms(phone, message, result)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermissionRequest) return
        val sms = pendingSms
        val result = pendingResult
        pendingSms = null
        pendingResult = null
        if (
            sms != null &&
            result != null &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            sendSms(sms.first, sms.second, result)
        } else {
            result?.error("permission_denied", "SMS permission was denied", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun sendSms(phone: String, message: String, result: MethodChannel.Result) {
        try {
            SmsManager.getDefault().sendTextMessage(phone, null, message, null, null)
            result.success(true)
        } catch (error: Exception) {
            result.error("sms_failed", "Android could not send the SMS", null)
        }
    }
}
