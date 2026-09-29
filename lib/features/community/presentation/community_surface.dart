import 'package:flutter/material.dart';
import 'community_sapphire.dart';

/// Community-only presentation. Preserve user fonts, Dynamic Type, RTL and
/// native transitions. The dashboard/watch theme is deliberately untouched.
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
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final paper = CommunitySapphire.paper(context);
    final ink = CommunitySapphire.ink(context);
    final muted = highContrast ? ink : CommunitySapphire.muted(context);
    final line = dark ? const Color(0xFF334459) : const Color(0xFFE6ECF4);
    final scheme = base.colorScheme.copyWith(
      primary: dark ? const Color(0xFF8BB4FF) : CommunitySapphire.blue,
      onPrimary: dark ? CommunitySapphire.navy : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF203E68)
          : const Color(0xFFEAF1FF),
      onPrimaryContainer: dark
          ? const Color(0xFFEAF1FF)
          : const Color(0xFF1849A9),
      secondary: dark ? const Color(0xFFB6CAF0) : CommunitySapphire.navy,
      secondaryContainer: dark
          ? const Color(0xFF263449)
          : const Color(0xFFEEF3FA),
      onSecondaryContainer: ink,
      surface: CommunitySapphire.canvas(context),
      surfaceContainerLow: paper,
      surfaceContainer: CommunitySapphire.canvas(context),
      onSurface: ink,
      onSurfaceVariant: muted,
      outlineVariant: line,
    );
    final text = base.textTheme;
    final reading = text.copyWith(
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: text.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: text.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.55,
        color: ink,
      ),
      bodyMedium: text.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.5,
        color: ink,
      ),
      bodySmall: text.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: muted,
      ),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: text.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: text.labelSmall?.copyWith(fontSize: 12, color: muted),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        textTheme: reading,
        scaffoldBackgroundColor: CommunitySapphire.canvas(context),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: paper,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 8,
          titleTextStyle: reading.titleLarge,
        ),
        iconTheme: base.iconTheme.copyWith(size: 22, color: muted),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            iconSize: 22,
            visualDensity: VisualDensity.standard,
          ),
        ),
        tabBarTheme: base.tabBarTheme.copyWith(
          labelStyle: reading.labelLarge,
          unselectedLabelStyle: reading.labelLarge,
          labelColor: scheme.primary,
          unselectedLabelColor: muted,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          indicatorColor: Colors.transparent,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: paper,
          surfaceTintColor: Colors.transparent,
          elevation: highContrast || dark ? 0 : 1,
          shadowColor: const Color(0x0A14243A),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: line),
          ),
        ),
        listTileTheme: base.listTileTheme.copyWith(
          horizontalTitleGap: 14,
          minLeadingWidth: 28,
          minVerticalPadding: 12,
          titleTextStyle: reading.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          subtitleTextStyle: reading.bodySmall,
          iconColor: muted,
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: line,
          thickness: 1,
          space: 1,
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: CommunitySapphire.canvas(context),
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          dragHandleColor: muted.withValues(alpha: .45),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: paper,
          shape: shape,
          textStyle: reading.bodyMedium,
          surfaceTintColor: Colors.transparent,
        ),
        chipTheme: base.chipTheme.copyWith(
          labelStyle: reading.labelMedium,
          secondaryLabelStyle: reading.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: reading.labelLarge,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            textStyle: reading.labelLarge,
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            textStyle: reading.labelLarge,
            shape: shape,
            side: BorderSide(color: line),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: paper,
          hintStyle: reading.bodyMedium?.copyWith(color: muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: scheme.primary,
          selectionColor: scheme.primary.withValues(alpha: .24),
          selectionHandleColor: scheme.primary,
        ),
        snackBarTheme: base.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
