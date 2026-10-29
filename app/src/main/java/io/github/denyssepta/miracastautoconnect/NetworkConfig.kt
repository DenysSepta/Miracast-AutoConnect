package io.github.denyssepta.miracastautoconnect

/**
 * Default LAN ports used by the Android trigger and Windows listener.
 * Keep the Android and Windows configurations in sync when changing ports.
 */
object NetworkConfig {
    const val UDP_TRIGGER_PORT = 8888
    const val MS_MICE_COMPATIBILITY_PORT = 7250
}
