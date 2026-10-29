package io.github.denyssepta.miracastautoconnect

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class RemoteButtonService : AccessibilityService() {
    private lateinit var miracastDirectManager: MiracastDirectManager

    override fun onCreate() {
        super.onCreate()
        miracastDirectManager = MiracastDirectManager(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == 193 || event.keyCode == 194) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                miracastDirectManager.startDirectMiracastSession()
            }
            return true
        }
        return super.onKeyEvent(event)
    }
}
