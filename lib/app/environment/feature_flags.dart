import 'app_environment.dart';

enum AppFeature { cloud, artificialIntelligence, commerce }

class FeatureFlags {
  const FeatureFlags._();

  static bool enabled(AppFeature feature) => switch (feature) {
    AppFeature.cloud => AppEnvironment.cloudConfigured,
    AppFeature.artificialIntelligence => AppEnvironment.aiConfigured,
    AppFeature.commerce => AppEnvironment.commerceConfigured,
  };

  /// Remote overrides remain unavailable until a signed configuration service exists.
  static bool get remoteOverridesAvailable => false;
}
