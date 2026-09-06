import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens only the reviewed Android Facebook authorization URL through BIL's
/// native Custom Tabs bridge.
///
/// The native bridge deliberately has no WebView fallback. If a Custom Tabs
/// provider cannot be resolved or launched, it returns `false` and the caller
/// keeps the user on BIL's sign-in surface.
final class BilFacebookOAuthLauncher {
  const BilFacebookOAuthLauncher({
    this.methodChannel = const MethodChannel(_channelName),
  });

  static const _channelName = 'bil/facebook_oauth';
  static const _supabaseAuthHost = 'tgmanzhqulksykhslrzb.supabase.co';
  static const _supabaseAuthorizePath = '/auth/v1/authorize';
  static const _redirectUri = 'https://www.bilhealth.com/auth/callback';

  final MethodChannel methodChannel;

  Future<bool> open(Uri authorizationUri) async {
    if (!isTrustedAuthorizationUri(authorizationUri)) {
      throw const AuthException(
        'Facebook returned an invalid authorization address.',
      );
    }
    return await methodChannel.invokeMethod<bool>(
          'openCustomTab',
          <String, String>{'url': authorizationUri.toString()},
        ) ??
        false;
  }

  static bool isTrustedAuthorizationUri(Uri uri) {
    final providers = uri.queryParametersAll['provider'];
    final redirects = uri.queryParametersAll['redirect_to'];
    return uri.scheme == 'https' &&
        uri.host.toLowerCase() == _supabaseAuthHost &&
        (!uri.hasPort || uri.port == 443) &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        uri.path == _supabaseAuthorizePath &&
        providers?.length == 1 &&
        providers!.single == 'facebook' &&
        redirects?.length == 1 &&
        redirects!.single == _redirectUri;
  }
}
