package com.bilhealth.bodyintelligencelog

import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterView

class Api26FlutterFragment : FlutterFragment() {
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View? {
        val args = requireArguments()
        if (Build.VERSION.SDK_INT != Build.VERSION_CODES.O ||
            !args.getBoolean(ARG_SHOULD_DELAY_FIRST_ANDROID_VIEW_DRAW)
        ) {
            return super.onCreateView(inflater, container, savedInstanceState)
        }

        // Flutter 3.44 reads this protected argument while constructing the view.
        // Restore it before returning so saved fragments retain the stock policy.
        args.putBoolean(ARG_SHOULD_DELAY_FIRST_ANDROID_VIEW_DRAW, false)
        val view = try {
            super.onCreateView(inflater, container, savedInstanceState)
        } finally {
            args.putBoolean(ARG_SHOULD_DELAY_FIRST_ANDROID_VIEW_DRAW, true)
        }
        if (view is FlutterView) FirstDraw(view).install()
        return view
    }

    private class FirstDraw(private val view: FlutterView) : View.OnAttachStateChangeListener {
        private var owner: ViewTreeObserver? = null
        private var activeGate: ViewTreeObserver.OnPreDrawListener? = null

        fun install() {
            view.addOnAttachStateChangeListener(this)
            if (view.isAttachedToWindow) onViewAttachedToWindow(view)
        }

        override fun onViewAttachedToWindow(v: View) {
            val tree = v.viewTreeObserver
            val gate = object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    // A retained window can finish dispatching an old snapshot after detach.
                    if (activeGate !== this) return true
                    if (!view.hasRenderedFirstFrame()) return false
                    releaseObserver()
                    view.removeOnAttachStateChangeListener(this@FirstDraw)
                    return true
                }
            }
            owner = tree
            activeGate = gate
            tree.addOnPreDrawListener(gate)
        }

        override fun onViewDetachedFromWindow(v: View) = releaseObserver()

        private fun releaseObserver() {
            val tree = owner
            val gate = activeGate
            activeGate = null
            owner = null
            if (tree != null && tree.isAlive && gate != null) tree.removeOnPreDrawListener(gate)
        }
    }
}
