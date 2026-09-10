import 'package:flutter/material.dart';

/// A local reading scale, not a global text-scale override. Dynamic Type,
/// BIL's font family, RTL, contrast and the user's dark theme are preserved.
class CommunitySurface extends StatefulWidget {
  const CommunitySurface({required this.child, super.key});
  final Widget child;

  @override
  State<CommunitySurface> createState() => _CommunitySurfaceState();
}

class _CommunitySurfaceState extends State<CommunitySurface> {
  @override
  void initState() {
    super.initState();
    // Clear the previous route's field history before this page takes focus.
    // Do not do this in build: a rebuild must never interrupt a member typing.
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final text = base.textTheme;
    final scheme = base.colorScheme;
    final reading = text.copyWith(
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: text.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, height: 1.4),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: text.labelMedium?.copyWith(fontSize: 12),
      labelSmall: text.labelSmall?.copyWith(fontSize: 11),
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: scheme.surface,
        textTheme: reading,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 8,
          titleTextStyle: reading.titleLarge?.copyWith(color: scheme.onSurface),
        ),
        iconTheme: base.iconTheme.copyWith(size: 22),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            iconSize: 22,
            visualDensity: VisualDensity.standard,
          ),
        ),
        tabBarTheme: base.tabBarTheme.copyWith(
          labelStyle: reading.labelLarge,
          labelColor: scheme.onSurface,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          unselectedLabelStyle: reading.labelLarge?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          dividerColor: scheme.outlineVariant,
          indicatorSize: TabBarIndicatorSize.label,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        listTileTheme: base.listTileTheme.copyWith(
          horizontalTitleGap: 12,
          minLeadingWidth: 24,
          minVerticalPadding: 10,
          titleTextStyle: reading.bodyLarge?.copyWith(color: scheme.onSurface),
          subtitleTextStyle: reading.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          labelStyle: reading.labelMedium,
          secondaryLabelStyle: reading.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: reading.labelLarge,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: reading.labelLarge,
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
      child: ScrollConfiguration(
        behavior: const _CommunityScrollBehavior(),
        child: widget.child,
      ),
    );
  }
}

class _CommunityScrollBehavior extends MaterialScrollBehavior {
  const _CommunityScrollBehavior();

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ScrollViewKeyboardDismissBehavior.onDrag;
}

Future<T?> pushCommunityPage<T>(BuildContext context, Widget page) {
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => CommunitySurface(child: page)),
  );
}
