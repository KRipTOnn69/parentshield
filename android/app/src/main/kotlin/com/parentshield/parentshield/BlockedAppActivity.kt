package com.parentshield.parentshield

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

class BlockedAppActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_blocked_app)

        val appName = intent.getStringExtra("app_name") ?: "This app"
        val customMessage = intent.getStringExtra("custom_message")

        findViewById<TextView>(R.id.tvAppName).text = appName
        findViewById<TextView>(R.id.tvReason).text = customMessage
            ?: "Your parent has restricted access to $appName. Ask your parent to unblock it if needed."

        findViewById<Button>(R.id.btnGoHome).setOnClickListener {
            goHome()
        }
    }

    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }
}
