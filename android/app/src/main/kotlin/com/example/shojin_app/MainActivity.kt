package com.tsukuba.atcoder.shojin

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.shojin_app/patcher"
    private var installResultPendingIntent: PendingIntent? = null
    private var installResultChannel: MethodChannel.Result? = null

    companion object {
        private const val ACTION_INSTALL_COMPLETE = "com.example.shojin_app.INSTALL_COMPLETE"
        private const val EXTRA_STATUS = "EXTRA_STATUS"
        private const val REQUEST_CODE_INSTALL = 123
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val apkPath = call.argument<String>("apkPath")
                if (apkPath != null) {
                    installResultChannel = result
                    installApk(apkPath)
                } else {
                    result.error("INVALID_ARGUMENT", "apkPath is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun installApk(apkPath: String) {
        try {
            val file = File(apkPath)
            if (!file.exists()) {
                installResultChannel?.error("FILE_NOT_FOUND", "APK file not found at $apkPath", null)
                return
            }

            val packageInstaller = applicationContext.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            val sessionId = packageInstaller.createSession(params)
            val session = packageInstaller.openSession(sessionId)

            val outputStream = session.openWrite("shojin_app_update", 0, file.length())
            val inputStream = file.inputStream()
            inputStream.copyTo(outputStream)
            session.fsync(outputStream)
            outputStream.close()
            inputStream.close()

            val intent = Intent(ACTION_INSTALL_COMPLETE)
            intent.setPackage(applicationContext.packageName)
            // intent.action is already set by the constructor Intent(ACTION_INSTALL_COMPLETE)
            // If you use new Intent(), then you need intent.action = ACTION_INSTALL_COMPLETE
            // Add sessionId to intent extras if needed for more complex scenarios,
            // but for basic status, it might not be strictly necessary if we only handle one install at a time.

            installResultPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getBroadcast(applicationContext, REQUEST_CODE_INSTALL, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
            } else {
                PendingIntent.getBroadcast(applicationContext, REQUEST_CODE_INSTALL, intent, PendingIntent.FLAG_UPDATE_CURRENT)
            }

            session.commit(installResultPendingIntent!!.intentSender)
            session.close()
            // The result will be sent via BroadcastReceiver
        } catch (e: Exception) {
            installResultChannel?.error("INSTALL_FAILED", "Failed to install APK: ${e.message}", e.toString())
        }
    }

    private val installBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_INSTALL_COMPLETE) {
                val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
                val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "No message"

                val resultData = mutableMapOf<String, Any>()

                when (status) {
                    PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                        val confirmationIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                        if (confirmationIntent != null) {
                            // This intent should be started by the system automatically.
                            // If not, we might need to start it here, but typically the system handles this.
                            // For now, we assume the system handles it. If issues arise, we might need to start it:
                            // context.startActivity(confirmationIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            // However, this part is tricky as the receiver might not be the right place to start an activity
                            // that requires user interaction without careful handling.
                            // The primary purpose here is to get the final status.
                            // The user action itself is handled by the system dialog.
                            // We don't send a result back to Flutter yet, as the action is pending.
                            return
                        } else {
                            resultData["status"] = PackageInstaller.STATUS_FAILURE // Or a custom code
                            resultData["message"] = "Confirmation intent was null, but user action is pending."
                            installResultChannel?.success(resultData)
                        }
                    }
                    PackageInstaller.STATUS_SUCCESS -> {
                        resultData["status"] = 0 // Success
                        resultData["message"] = "Installation successful"
                        installResultChannel?.success(resultData)
                    }
                    PackageInstaller.STATUS_FAILURE -> {
                        resultData["status"] = 1 // Generic failure
                        resultData["message"] = "Installation failed: $message"
                        installResultChannel?.error("INSTALL_FAILURE_DEVICE", message, null)
                    }
                    PackageInstaller.STATUS_FAILURE_ABORTED -> {
                        resultData["status"] = 3 // User cancelled
                        resultData["message"] = "Installation cancelled by user: $message"
                        installResultChannel?.success(resultData) // Or error, depending on how Flutter expects it
                    }
                    PackageInstaller.STATUS_FAILURE_BLOCKED -> {
                        resultData["status"] = 2 // Blocked
                        resultData["message"] = "Installation blocked: $message"
                        installResultChannel?.error("INSTALL_BLOCKED", message, null)
                    }
                    PackageInstaller.STATUS_FAILURE_CONFLICT -> {
                        resultData["status"] = 4 // Conflict
                        resultData["message"] = "Installation conflict: $message"
                        installResultChannel?.error("INSTALL_CONFLICT", message, null)
                    }
                    PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> {
                        resultData["status"] = 5 // Incompatible
                        resultData["message"] = "Installation incompatible: $message"
                        installResultChannel?.error("INSTALL_INCOMPATIBLE", message, null)
                    }
                    PackageInstaller.STATUS_FAILURE_INVALID -> {
                        resultData["status"] = 6 // Invalid APK
                        resultData["message"] = "Installation invalid APK: $message"
                        installResultChannel?.error("INSTALL_INVALID_APK", message, null)
                    }
                    PackageInstaller.STATUS_FAILURE_STORAGE -> {
                        resultData["status"] = 7 // Storage issue
                        resultData["message"] = "Installation storage issue: $message"
                        installResultChannel?.error("INSTALL_STORAGE_ISSUE", message, null)
                    }
                    else -> {
                        resultData["status"] = status // Unknown status
                        resultData["message"] = "Installation unknown status $status: $message"
                        installResultChannel?.error("INSTALL_UNKNOWN_STATUS", message, status.toString())
                    }
                }
                // Clean up
                installResultChannel = null
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val filter = IntentFilter(ACTION_INSTALL_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(installBroadcastReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(installBroadcastReceiver, filter)
        }
    }

    override fun onPause() {
        super.onPause()
        unregisterReceiver(installBroadcastReceiver)
    }
}

// Create a new file for the BroadcastReceiver: InstallReceiver.kt
// (This is just a placeholder, the actual receiver logic is now inside MainActivity for simplicity,
// but it's good practice to have it in a separate file if it grows complex or is used by other components)
// package com.example.shojin_app
//
// import android.content.BroadcastReceiver
// import android.content.Context
// import android.content.Intent
// import android.content.pm.PackageInstaller
// import android.util.Log
//
// class InstallReceiver : BroadcastReceiver() {
//     override fun onReceive(context: Context, intent: Intent) {
//         // This receiver is now defined and registered within MainActivity.
//         // If you want to keep it separate, you'd need to ensure MainActivity can access the result.
//         // For this implementation, we've integrated it into MainActivity.
//         // The intent that triggers this receiver is created in MainActivity's installApk method.
//         // It should carry the status of the installation.
//
//         // Example of how it would look if it were separate and needed to send data back,
//         // perhaps via another broadcast or by updating a shared state.
//         // However, for direct MethodChannel communication, integrating it or having a clear callback mechanism
//         // to MainActivity is simpler.
//
//         // val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
//         // Log.d("InstallReceiver", "Installation status: $status")
//         // val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
//         // Log.d("InstallReceiver", "Installation message: $message")

//         // If this receiver were truly separate and needed to communicate back to Flutter,
//         // it would be more complex. It might need to start MainActivity with specific extras,
//         // or use a service, or write to SharedPreferences that Flutter then reads.
//         // The current integrated approach in MainActivity is more direct for this use case.
//     }
// }
