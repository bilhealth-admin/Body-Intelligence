/// Browser provenance is separate from authenticated MP4 playback. Catalog
/// URLs and media pins remain untouched. Never forward authentication material.
Uri? workoutOriginalSourcePage(Uri source) {
  if (source.scheme != 'https' ||
      source.host.isEmpty ||
      source.userInfo.isNotEmpty ||
      source.port != 443 ||
      source.host == 'localhost' ||
      source.host.endsWith('.localhost') ||
      source.host.endsWith('.local') ||
      source.host.contains(':') ||
      RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$').hasMatch(source.host)) {
    return null;
  }
  const secrets = {
    'access_token',
    'token',
    'authorization',
    'apikey',
    'api_key',
    'signature',
    'x-amz-signature',
  };
  try {
    if (source.queryParameters.keys.any(
      (key) => secrets.contains(key.toLowerCase()),
    )) {
      return null;
    }
  } on FormatException {
    return null;
  }
  if (source.host != 'workouts.bilhealth.com') return source;
  if (source.hasQuery ||
      source.hasFragment ||
      !RegExp(
        r'^/v2/(?:objects|source)/workouts/v1/(?:home|gym-six-month)/movements/[a-z0-9]+(?:-[a-z0-9]+)*\.mp4$',
      ).hasMatch(source.path)) {
    return null;
  }
  return Uri(
    scheme: 'https',
    host: 'workouts.bilhealth.com',
    path: source.path.replaceFirst('/v2/objects/', '/v2/source/'),
  );
}
