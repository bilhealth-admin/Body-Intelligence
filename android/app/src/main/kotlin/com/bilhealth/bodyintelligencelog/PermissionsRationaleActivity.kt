package com.bilhealth.bodyintelligencelog

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.method.LinkMovementMethod
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * In-app Health Connect permissions rationale required by Android.
 *
 * This screen is intentionally local and contains no tracking, network call,
 * or health-data access. It explains the purpose of requested permissions and
 * remains available from the Health Connect permission surface.
 */
class PermissionsRationaleActivity : Activity() {
    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun rounded(color: Int, radiusDp: Int, strokeColor: Int? = null): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = dp(radiusDp).toFloat()
            if (strokeColor != null) setStroke(dp(1), strokeColor)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val dark =
            (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        val background = if (dark) Color.rgb(3, 4, 5) else Color.rgb(247, 249, 252)
        val surface = if (dark) Color.rgb(14, 16, 19) else Color.WHITE
        val textPrimary = if (dark) Color.rgb(244, 247, 250) else Color.rgb(20, 26, 33)
        val textSecondary = if (dark) Color.rgb(184, 195, 207) else Color.rgb(76, 88, 101)
        val outline = if (dark) Color.rgb(47, 58, 70) else Color.rgb(220, 226, 233)
        val accent = Color.rgb(30, 118, 210)
        val accentSoft = if (dark) Color.rgb(17, 43, 70) else Color.rgb(231, 242, 255)

        window.statusBarColor = background
        window.navigationBarColor = background

        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(20), dp(24), dp(20), dp(28))
            setBackgroundColor(background)
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            setPadding(dp(22), dp(22), dp(22), dp(20))
            background = rounded(surface, 28, outline)
            elevation = dp(4).toFloat()
        }

        card.addView(TextView(this).apply {
            text = "BIL"
            textSize = 13f
            setTextColor(accent)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            background = rounded(accentSoft, 14)
            setPadding(dp(12), dp(8), dp(12), dp(8))
        })

        card.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_rationale_title)
            textSize = 26f
            setTextColor(textPrimary)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, dp(18), 0, 0)
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        card.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_rationale_body)
            textSize = 16f
            setTextColor(textSecondary)
            setLineSpacing(0f, 1.18f)
            setPadding(0, dp(12), 0, 0)
            movementMethod = LinkMovementMethod.getInstance()
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        card.addView(Button(this).apply {
            text = getString(R.string.health_permissions_privacy_policy_action)
            isAllCaps = false
            textSize = 15f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            minHeight = dp(52)
            background = rounded(accent, 16)
            setPadding(dp(18), dp(12), dp(18), dp(12))
            setOnClickListener {
                val privacyPolicy = Uri.parse(
                    getString(R.string.health_privacy_policy_url),
                )
                runCatching {
                    startActivity(Intent(Intent.ACTION_VIEW, privacyPolicy))
                }
            }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = dp(22)
        })

        page.addView(card, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            addView(page)
        }
        ViewCompat.setOnApplyWindowInsetsListener(scrollView) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }
        setContentView(scrollView)
        ViewCompat.requestApplyInsets(scrollView)
    }
}
