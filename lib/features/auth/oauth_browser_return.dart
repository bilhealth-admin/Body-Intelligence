import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dismisses BIL's SFSafariViewController after an allow-listed auth callback.
///
/// Supabase launches the browser but BIL owns the app-link observer. Navigation
/// alone does not dismiss the native controller presented over Flutter. This
/// must run only from BilAuthCallbackController's validated resolve callback,
/// including provider error returns. External browsers and Android Custom Tabs
/// are deliberately untouched. Browser cleanup cannot veto a PKCE exchange.
Future<void> dismissIosOAuthBrowserAfterCallback({
  TargetPlatform? platform,
  bool? isWeb,
  Future<void> Function()? closeBrowser,
}) async {
  if ((isWeb ?? kIsWeb) ||
      (platform ?? defaultTargetPlatform) != TargetPlatform.iOS) {
    return;
  }
  try {
    await (closeBrowser ?? closeInAppWebView)().timeout(
      const Duration(seconds: 1),
    );
  } catch (_) {
    // A dismissed/missing native browser is not an authentication failure.
    // Continue to the real exchange, whose result still decides sign-in.
  }
}
