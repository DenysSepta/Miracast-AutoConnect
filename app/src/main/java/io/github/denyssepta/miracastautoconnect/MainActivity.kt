package io.github.denyssepta.miracastautoconnect

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val manager = MiracastDirectManager(this)
        manager.startDirectMiracastSession()
        Toast.makeText(this, "Miracast connection requested", Toast.LENGTH_SHORT).show()
        finish()
    }
}
