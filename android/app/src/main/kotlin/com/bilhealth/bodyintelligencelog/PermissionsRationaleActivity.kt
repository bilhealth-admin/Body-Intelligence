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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * In-app Health Connect permissions rationale required by Android.
 *
 * This screen is intentionally local and contains no tracking, network call,
 * or health-data access. It explains the exact read-only release scope and
 * remains available from Android's Health Connect permission surface.
 */
class PermissionsRationaleActivity : Activity() {
    private val density by lazy { resources.displayMetrics.density }
    private fun dp(value: Int): Int = (value * density).toInt()

    private fun rounded(
        color: Int,
        radiusDp: Int,
        strokeColor: Int? = null,
        strokeDp: Int = 1,
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
        if (strokeColor != null) setStroke(dp(strokeDp), strokeColor)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val isDark =
            resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
                Configuration.UI_MODE_NIGHT_YES
        val background = Color.parseColor(if (isDark) "#030405" else "#F6F8FC")
        val surface = Color.parseColor(if (isDark) "#0B0D10" else "#FFFFFF")
        val primaryText = Color.parseColor(if (isDark) "#F7F9FC" else "#101828")
        val secondaryText = Color.parseColor(if (isDark) "#AEB7C4" else "#536170")
        val outline = Color.parseColor(if (isDark) "#2A3038" else "#DDE5EF")
        val accent = Color.parseColor("#0A84FF")
        val accentEnd = Color.parseColor("#6D4AE8")
        val padding = dp(24)

        window.statusBarColor = background
        window.navigationBarColor = background

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            setPadding(padding, dp(30), padding, dp(30))
        }

        val identity = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val icon = ImageView(this).apply {
            setImageResource(R.drawable.bil_symbol_health)
            imageTintList = ContextCompat.getColorStateList(
                this@PermissionsRationaleActivity,
                android.R.color.white,
            )
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(accent, accentEnd),
            ).apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
            }
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        identity.addView(
            icon,
            LinearLayout.LayoutParams(dp(52), dp(52)),
        )
        identity.addView(TextView(this).apply {
            text = getString(R.string.app_name)
            textSize = 13f
            setTextColor(secondaryText)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginStart = dp(14)
        })
        content.addView(identity, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        content.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_rationale_title)
            textSize = 28f
            setTextColor(primaryText)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, dp(28), 0, dp(10))
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        content.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_rationale_body)
            textSize = 16f
            setTextColor(secondaryText)
            setLineSpacing(0f, 1.18f)
            setPadding(dp(18), dp(18), dp(18), dp(18))
            movementMethod = LinkMovementMethod.getInstance()
            background = rounded(surface, 22, outline)
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        content.addView(Button(this).apply {
            text = getString(R.string.health_permissions_privacy_policy_action)
            textSize = 15f
            isAllCaps = false
            setTextColor(Color.WHITE)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            background = rounded(accent, 18)
            setPadding(dp(18), dp(13), dp(18), dp(13))
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
            topMargin = dp(18)
        })

        content.addView(TextView(this).apply {
            text = getString(R.string.health_permissions_release_scope_note)
            textSize = 12f
            setTextColor(secondaryText)
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(18), dp(8), 0)
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

        val scrollView = ScrollView(this).apply {
            setBackgroundColor(background)
            isFillViewport = true
            addView(content)
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
