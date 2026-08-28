package com.bilhealth.bodyintelligencelog

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.text.method.LinkMovementMethod
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Button
import android.widget.TextView

/**
 * In-app Health Connect permissions rationale required by Android.
 *
 * This screen is intentionally local and contains no tracking, network call,
 * or health-data access. It explains the purpose of requested permissions and
 * remains available from the Health Connect permission surface.
 */
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val padding = (24 * resources.displayMetrics.density).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            setPadding(padding, padding, padding, padding)
        }

        content.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_rationale_title)
            textSize = 24f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        content.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_rationale_body)
            textSize = 16f
            setPadding(0, padding, 0, 0)
            movementMethod = LinkMovementMethod.getInstance()
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        content.addView(Button(this).apply {
            text = getString(R.string.health_permissions_privacy_policy_action)
            setPadding(padding, padding / 2, padding, padding / 2)
            setOnClickListener {
                val privacyPolicy = Uri.parse(
                    getString(R.string.health_privacy_policy_url),
                )
                runCatching {
                    startActivity(Intent(Intent.ACTION_VIEW, privacyPolicy))
                }
            }
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        setContentView(ScrollView(this).apply { addView(content) })
    }
}
