package io.github.denyssepta.miracastautoconnect

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.NetworkInterface

class MiracastDirectManager(private val context: Context) {
    companion object {
        private const val TAG = "MiracastAutoConnect"
        private const val DEBOUNCE_MS = 2000L
        private const val BURST_COUNT = 3
        private const val BURST_DELAY_MS = 100L

        @Volatile
        private var lastSessionTimestamp = 0L

        fun buildMsMiceMessage(ipAddress: String, port: Int = NetworkConfig.MS_MICE_COMPATIBILITY_PORT) =
            "MS-MICE_CONNECT_REQ:$ipAddress:$port"

        fun buildLegacyMessage(ipAddress: String, port: Int = NetworkConfig.MS_MICE_COMPATIBILITY_PORT) =
            "CONNECT_MIRACAST:$ipAddress:$port"

        fun isVirtualOrP2pInterface(name: String): Boolean {
            val lowerName = name.lowercase()
            return listOf("p2p", "tun", "tap", "docker", "dummy", "vbox", "virbr", "rmnet")
                .any(lowerName::contains)
        }
    }

    @Synchronized
    fun startDirectMiracastSession() {
        val now = System.currentTimeMillis()
        if (now - lastSessionTimestamp < DEBOUNCE_MS) {
            Log.d(TAG, "Ignoring duplicate trigger (debounce active)")
            return
        }
        lastSessionTimestamp = now
        Log.i(TAG, "Receiver launch attempt result: ${openSystemMiracastReceiver()}")
        sendOOBTriggerToPC()
    }

    fun openSystemMiracastReceiver(): Boolean {
        val vendorPackages = listOf(
            "com.xiaomi.mitv.smartshare",
            "com.samsung.android.smartmirroring",
            "com.mediatek.ww.wifidisplay",
            "com.mstar.android.miracast",
            "com.realtek.miracast",
            "com.actions.wifidisplay",
            "com.eostek.tv.player",
            "com.cvte.tv.miracast"
        )

        for (pkg in vendorPackages) {
            try {
                val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    context.startActivity(launchIntent)
                    Log.i(TAG, "Launched receiver activity for package: $pkg")
                    return true
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not launch package: $pkg", e)
            }
        }

        val fallbackIntents = listOf(
            Intent(Settings.ACTION_CAST_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent().setClassName("com.android.settings", "com.android.settings.wfd.WifiDisplaySettings")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent("android.settings.WIFI_DISPLAY_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent("android.settings.CAST_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )

        for (intent in fallbackIntents) {
            try {
                context.startActivity(intent)
                Log.i(TAG, "Opened receiver/settings via intent: ${intent.action ?: intent.component}")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "Fallback receiver intent failed", e)
            }
        }

        Log.w(TAG, "No compatible Miracast receiver activity was found")
        return false
    }

    fun sendOOBTriggerToPC() {
        CoroutineScope(Dispatchers.IO).launch {
            val localIp = getLocalIpAddress()
            val messages = listOf(buildMsMiceMessage(localIp), buildLegacyMessage(localIp))
            val targets = linkedSetOf<InetAddress>()

            try {
                targets.add(InetAddress.getByName("255.255.255.255"))
            } catch (e: Exception) {
                Log.w(TAG, "Could not resolve limited broadcast address", e)
            }
            getSubnetBroadcastAddress()?.let(targets::add)

            if (targets.isEmpty()) {
                Log.e(TAG, "No broadcast targets available")
                return@launch
            }

            try {
                DatagramSocket().use { socket ->
                    socket.broadcast = true
                    repeat(BURST_COUNT) { index ->
                        for (target in targets) {
                            for (message in messages) {
                                val data = message.toByteArray(Charsets.US_ASCII)
                                for (port in intArrayOf(NetworkConfig.UDP_TRIGGER_PORT, NetworkConfig.MS_MICE_COMPATIBILITY_PORT)) {
                                    socket.send(DatagramPacket(data, data.size, target, port))
                                }
                            }
                        }
                        if (index < BURST_COUNT - 1) delay(BURST_DELAY_MS)
                    }
                }
                Log.i(TAG, "UDP trigger burst sent; local IPv4=$localIp")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send UDP trigger", e)
            }
        }
    }

    fun getLocalIpAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return "0.0.0.0"
            var bestCandidate = "0.0.0.0"
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (!networkInterface.isUp || networkInterface.isLoopback) continue
                if (isVirtualOrP2pInterface(networkInterface.name)) continue

                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    val host = address.hostAddress ?: continue
                    if (address.isLoopbackAddress || host.contains(':')) continue
                    val name = networkInterface.name.lowercase()
                    if (name.startsWith("wlan") || name.startsWith("eth")) return host
                    bestCandidate = host
                }
            }
            return bestCandidate
        } catch (e: Exception) {
            Log.e(TAG, "Could not determine LAN IPv4 address", e)
        }
        return "0.0.0.0"
    }

    fun getSubnetBroadcastAddress(): InetAddress? {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (!networkInterface.isUp || networkInterface.isLoopback) continue
                if (isVirtualOrP2pInterface(networkInterface.name)) continue
                for (address in networkInterface.interfaceAddresses) {
                    val broadcast = address.broadcast
                    if (broadcast != null && !broadcast.isLoopbackAddress) return broadcast
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not determine subnet broadcast address", e)
        }
        return null
    }
}
