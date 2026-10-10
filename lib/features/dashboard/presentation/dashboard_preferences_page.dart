import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/presentation/premium_label_badge.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../profile/providers/profile_auth_identity_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../settings/reference_settings_home_page.dart';
import '../providers/dashboard_preferences_provider.dart';
part 'dashboard_preferences_actions.dart';
part 'dashboard_preferences_catalog.dart';
part 'dashboard_preferences_polish.dart';
part 'dashboard_preferences_body.dart';

@visibleForTesting
String dashboardPremiumFeatureDestination(bool paid, String featureRoute) =>
    paid ? featureRoute : '/plans';

class DashboardPreferencesPage extends ConsumerStatefulWidget {
  const DashboardPreferencesPage({super.key});

  @override
  ConsumerState<DashboardPreferencesPage> createState() =>
      _DashboardPreferencesPageState();
}

class _DashboardPreferencesPageState
    extends ConsumerState<DashboardPreferencesPage> {
  bool _saving = false;
  bool _signingOut = false;
  String? _savingSection;
  // A single switch save must not dim every control or flash a page-wide
  // progress bar. Batch changes still use the existing blocking presentation.
  bool get _savingLayout => _saving && _savingSection == null;
  final _presetScrollController = ScrollController();
  final _stableSectionValues = <String, bool>{};
  // A stream can still contain the previously committed value while the
  // database transaction is running. Render the requested choice until its
  // authoritative stream echoes it (or roll back after a failed write).
  final _pendingSectionValues = <String, bool>{};
  String? _pendingPresetId;
  bool _finishAfterSave = false;

  @override
  void dispose() {
    _presetScrollController.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback update) => setState(update);

  void _finishEditing() {
    // The Done control stays visually unchanged. A tap made during a save
    // finishes only after the database confirms success.
    if (_saving) {
      _finishAfterSave = true;
      return;
    }
    context.canPop() ? context.pop() : context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) => _buildPreferencesPage(context);

  Future<void> _logout(String ownerId) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await ref.read(settingsSignOutProvider)(ownerId);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                en: 'Could not sign out. Check your connection and retry.',
                ar: 'تعذر تسجيل الخروج. تحقق من الاتصال وحاول مرة أخرى.',
                fr: 'Impossible de se déconnecter. Vérifiez la connexion et réessayez.',
                es: 'No se pudo cerrar sesión. Comprueba la conexión e inténtalo de nuevo.',
                tr: 'Çıkış yapılamadı. Bağlantınızı kontrol edip yeniden deneyin.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}
