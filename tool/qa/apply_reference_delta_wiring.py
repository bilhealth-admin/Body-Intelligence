#!/usr/bin/env python3
"""Apply only the reviewed wiring deltas on the isolated work branch.

This temporary helper is removed before the final candidate. It does not alter
assertion tolerances, skip tests, modify dependencies, or access credentials.
All anchors are validated before any file is written.
"""
from pathlib import Path
import os
import subprocess

BRANCH = 'work/community-reference-parity-20261003'
if os.environ.get('GITHUB_REF_NAME') != BRANCH:
    raise SystemExit('This helper is restricted to the reference work branch.')

updates: dict[Path, str] = {}


def replace(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = updates.get(target, target.read_text(encoding='utf-8'))
    if text.count(old) == 1:
        updates[target] = text.replace(old, new, 1)
    elif old not in text and text.count(new) == 1:
        updates[target] = text
    else:
        raise SystemExit(f'Unexpected source at {path}; refusing to rewrite it.')


replace(
    'lib/app/localization/runtime_copy.dart',
    "import 'runtime_copy_food_log.dart';\n",
    "import 'runtime_copy_food_log.dart';\nimport 'runtime_copy_reference_delta.dart';\n",
)
replace(
    'lib/app/localization/runtime_copy.dart',
    '  static String? resolve(String english, String localeTag) {\n'
    '    final foodLog = FoodLogRuntimeCopy.resolve(english, localeTag);\n',
    '  static String? resolve(String english, String localeTag) {\n'
    '    final referenceDelta = ReferenceDeltaRuntimeCopy.resolve(english, localeTag);\n'
    '    if (referenceDelta != null) return referenceDelta;\n'
    '    final foodLog = FoodLogRuntimeCopy.resolve(english, localeTag);\n',
)
replace(
    'tool/localization/locale_fallback_closure.dart',
    "import 'package:body_intelligence_log/app/localization/runtime_copy_community_reference.dart';\n",
    "import 'package:body_intelligence_log/app/localization/runtime_copy_community_reference.dart';\n"
    "import 'package:body_intelligence_log/app/localization/runtime_copy_reference_delta.dart';\n",
)
replace(
    'tool/localization/locale_fallback_closure.dart',
    '    ...CommunityReferenceRuntimeCopy.sources,\n',
    '    ...CommunityReferenceRuntimeCopy.sources,\n'
    '    ...ReferenceDeltaRuntimeCopy.sources,\n',
)
replace(
    'test/features/dashboard/dashboard_preferences_widget_test.dart',
    '        expect(find.text(translated!), findsOneWidget);\n',
    '        expect(\n'
    '          find.descendant(\n'
    '            of: find.byType(AppBar),\n'
    '            matching: find.text(translated!),\n'
    '          ),\n'
    '          findsOneWidget,\n'
    '        );\n',
)
replace(
    'test/dashboard_polish/icon_label_layout_review_test.dart',
    '              _expectBadgeGap(tester, preset, find.byWidget(tile.title!), 32);\n',
    '              _expectBadgeGap(\n'
    '                tester,\n'
    '                preset,\n'
    '                find.byWidget(tile.title!),\n'
    '                34,\n'
    '                iconSize: 21,\n'
    '              );\n',
)
replace(
    'test/dashboard_polish/icon_label_layout_review_test.dart',
    '              _expectBadgeGap(tester, section, title, 30);\n',
    '              _expectBadgeGap(tester, section, title, 28, iconSize: 19);\n',
)
replace(
    'test/dashboard_polish/icon_label_layout_review_test.dart',
    '  double size,\n) {\n',
    '  double size, {\n  double iconSize = 18,\n}) {\n',
)
replace(
    'test/dashboard_polish/icon_label_layout_review_test.dart',
    '  expect(tester.widget<BilSemanticIconBadge>(badge).iconSize, 18);\n',
    '  expect(tester.widget<BilSemanticIconBadge>(badge).iconSize, iconSize);\n',
)

for path, text in updates.items():
    path.write_text(text, encoding='utf-8')
    print(f'Wired: {path}')

subprocess.run(['git', 'diff', '--check'], check=True)
