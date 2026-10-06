import 'package:flutter/material.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';

/// One five-destination component shared by the approved Coach and Community
/// presentation. Routing and Quick Add actions remain owned by the caller.
class BilReferenceBottomBar extends StatelessWidget {
  const BilReferenceBottomBar({
    required this.selected,
    required this.onSelected,
    this.dark = false,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final bool dark;
  static const routes = <String>[
    '/dashboard',
    '/intelligence-center',
    '/daily-log',
    '/community',
    '/settings',
  ];

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final labels = [
      for (final source in const [
        'Home',
        'AI Coach',
        'Quick Add',
        'Community',
        'More',
      ])
        copy?.text(source) ??
            RuntimeCopy.resolve(source, BilLocalePolicy.canonicalTag(locale)) ??
            source,
    ];
    final icons = <IconData>[
      selected == 0 ? Icons.home_rounded : Icons.home_outlined,
      selected == 1
          ? Icons.chat_bubble_rounded
          : Icons.chat_bubble_outline_rounded,
      Icons.add_rounded,
      selected == 3 ? Icons.groups_rounded : Icons.groups_outlined,
      Icons.more_horiz_rounded,
    ];
    final muted = dark ? const Color(0xFFB4C2D5) : const Color(0xFF697993);
    const blue = Color(0xFF2693FF);
    return DecoratedBox(
      key: const Key('bil-reference-navigation'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF172530), Color(0xFF0D1721)]
              : const [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: dark ? const Color(0xFF344858) : const Color(0xFFE0EAF6),
          width: .8,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x50000000) : const Color(0x15318BFF),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Semantics(
                    label: labels[i],
                    button: true,
                    selected: selected == i,
                    child: InkWell(
                      key: Key('bil-reference-nav-$i'),
                      onTap: () => onSelected(i),
                      borderRadius: BorderRadius.circular(18),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 1,
                            vertical: 5,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (i == 2)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: dark
                                          ? const [
                                              Color(0xFF4A657B),
                                              Color(0xFF17283B),
                                            ]
                                          : const [
                                              Color(0xFF31B7FF),
                                              Color(0xFF1652FF),
                                            ],
                                    ),
                                    border: Border.all(
                                      width: 1.2,
                                      color: dark
                                          ? const Color(0xFF859EBD)
                                          : Colors.white,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: blue.withValues(
                                          alpha: dark ? .1 : .26,
                                        ),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    icons[i],
                                    color: dark ? muted : Colors.white,
                                    size: 29,
                                  ),
                                )
                              else
                                Container(
                                  height: 31,
                                  alignment: Alignment.center,
                                  decoration: selected == i
                                      ? BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: blue.withValues(
                                                alpha: .12,
                                              ),
                                              blurRadius: 18,
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: Icon(
                                    icons[i],
                                    color: selected == i ? blue : muted,
                                    size: 25,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                labels[i],
                                maxLines: 3,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.2,
                                  color: selected == i ? blue : muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
