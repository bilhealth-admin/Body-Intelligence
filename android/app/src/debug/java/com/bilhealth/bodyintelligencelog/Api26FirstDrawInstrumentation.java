package com.bilhealth.bodyintelligencelog;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Process;
import android.os.SystemClock;
import android.view.View;
import android.view.ViewParent;
import android.view.ViewTreeObserver;
import io.flutter.embedding.android.FlutterFragment;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener;
import java.io.File;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** Explicitly invoked by the API 26 debug APK regression case. */
public final class Api26FirstDrawInstrumentation extends Instrumentation {
    private final CountDownLatch replacementDrew = new CountDownLatch(1);
    private String nonce;
    private Activity original;
    private View decor;
    private ViewParent root;
    private ViewTreeObserver tree;
    private FlutterView originalFlutter;
    private boolean requested;
    private boolean originalFrame;
    private boolean originalDraw;
    private boolean retired;
    private int resumes;
    private final ViewTreeObserver.OnDrawListener recordOriginalDraw = () -> originalDraw = true;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        nonce = arguments.getString("nonce", "");
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            require(Build.VERSION.SDK_INT == 26 && nonce.matches("[a-f0-9]{32}"), "wrong case");
            File cache = getTargetContext().getCacheDir();
            File evidenceReady = new File(cache, "bil-drew-" + nonce);
            File evidenceCaptured = new File(cache, "bil-captured-" + nonce);
            getTargetContext().startActivity(new Intent(getTargetContext(), MainActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK));
            require(replacementDrew.await(60, TimeUnit.SECONDS), "no qualified replacement draw");
            require(evidenceReady.createNewFile(), "duplicate readiness marker");
            // Let the host capture this same live window with the ordinary startup verifier.
            long deadline = SystemClock.elapsedRealtime() + 200_000;
            while (!evidenceCaptured.exists() && SystemClock.elapsedRealtime() < deadline) {
                SystemClock.sleep(100);
            }
            require(evidenceCaptured.exists(), "host did not capture the replacement");
            result.putString("verified", nonce);
            result.putInt("pid", Process.myPid());
            finish(Activity.RESULT_OK, result);
        } catch (Exception | AssertionError failure) {
            result.putString("error", failure.toString());
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    @Override public void callActivityOnResume(Activity activity) {
        super.callActivityOnResume(activity);
        if (!(activity instanceof MainActivity)) return;
        FlutterView flutter = activity.findViewById(FlutterFragment.FLUTTER_VIEW_ID);
        require(flutter != null && flutter.isAttachedToFlutterEngine(), "unattached Flutter engine");
        if (++resumes == 1) {
            original = activity;
            originalFlutter = flutter;
            decor = activity.getWindow().getDecorView();
            require(!flutter.hasRenderedFirstFrame(), "initial UI already displayed");
            flutter.addOnFirstFrameRenderedListener(new FlutterUiDisplayListener() {
                @Override public void onFlutterUiDisplayed() { originalFrame = true; }
                @Override public void onFlutterUiNoLongerDisplayed() {}
            });
            decor.getViewTreeObserver().addOnDrawListener(recordOriginalDraw);
            decor.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
                @Override public boolean onPreDraw() {
                    decor.getViewTreeObserver().removeOnPreDrawListener(this);
                    require(!requested && !originalFrame && decor.isAttachedToWindow(), "late request");
                    root = decor.getParent();
                    require(root != null, "no original window root");
                    tree = decor.getViewTreeObserver();
                    requested = true;
                    activity.recreate();
                    return true;
                }
            });
            return;
        }
        require(resumes == 2 && retired && activity != original && flutter != originalFlutter,
                "unexpected activity or FlutterView generation");
        require(activity.getWindow().getDecorView() == decor && decor.isAttachedToWindow()
                && decor.getParent() == root && tree.isAlive() && decor.getViewTreeObserver() == tree,
                "window root or observer was replaced");
        decor.getViewTreeObserver().addOnDrawListener(() -> {
            if (flutter.hasRenderedFirstFrame() && flutter.isAttachedToWindow()
                    && flutter.getRootView() == decor && decor.getParent() == root) {
                replacementDrew.countDown();
            }
        });
    }

    @Override public void callActivityOnDestroy(Activity activity) {
        if (activity == original) {
            require(requested && activity.isChangingConfigurations() && !originalDraw && !originalFrame
                    && !originalFlutter.hasRenderedFirstFrame() && originalFlutter.isAttachedToFlutterEngine()
                    && decor.isAttachedToWindow() && decor.getParent() == root
                    && decor.getViewTreeObserver() == tree,
                    "original view did not retire before first Flutter UI and first Android draw");
            decor.getViewTreeObserver().removeOnDrawListener(recordOriginalDraw);
            retired = true;
        }
        super.callActivityOnDestroy(activity);
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
