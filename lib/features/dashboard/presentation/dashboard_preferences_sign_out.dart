part of 'dashboard_preferences_page.dart';

extension _DashboardPreferencesSignOut on _DashboardPreferencesPageState {
  Widget _signOutTile(
    BuildContext context,
    String ownerId,
    bool sessionReady,
  ) => BilPearlMaterialCard(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      key: const Key('dashboard-preferences-sign-out'),
      minTileHeight: 58,
      leading: _signingOut || !sessionReady
          ? const SizedBox.square(
              dimension: 22,
              child: BilFeatureWelcomeStatus(),
            )
          : const BilNavigationFeedback(
              child: Icon(Icons.logout_rounded, color: Color(0xFFD92D3A)),
            ),
      title: Text(
        _copy(
          context,
          en: 'Log out',
          ar: 'تسجيل الخروج',
          fr: 'Se déconnecter',
          es: 'Cerrar sesión',
          tr: 'Çıkış yap',
        ),
        style: const TextStyle(
          color: Color(0xFFD92D3A),
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: _savingLayout || _signingOut || !sessionReady
          ? null
          : () => _logout(ownerId),
    ),
  );
}
