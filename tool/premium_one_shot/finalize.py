from pathlib import Path
import subprocess

BASE = '1cd90816577ebb9fb3fb058db3f36c73a816c5fe'

p = Path('test/features/nutrition/food_presentation_localizer_test.dart')
s = p.read_text()
replacements = [
    ("const canonical = 'Turkey breast, roasted';", "const canonical = 'Acerola puree, unsweetened';"),
    ("localizedName: 'صدر ديك رومي مشوي',", "localizedName: 'هريس أسيرولا غير محلى',"),
    ("        'صدر ديك رومي مشوي',", "        'هريس أسيرولا غير محلى',"),
]
for old, new in replacements:
    assert s.count(old) == 1, old
    s = s.replace(old, new, 1)
p.write_text(s)

p = Path('test/launch_readiness/trusted_food_search_backend_contract_test.dart')
s = p.read_text()
replacements = [
    ("        'name': 'Turkey breast, roasted',", "        'name': 'Acerola puree, unsweetened',"),
    ("        'localized_name': 'صدر ديك رومي مشوي',", "        'localized_name': 'هريس أسيرولا غير محلى',"),
    ("      expect(food!.name, 'Turkey breast, roasted');", "      expect(food!.name, 'Acerola puree, unsweetened');\n      expect(food.keywords, isNot(contains('هريس أسيرولا غير محلى')));"),
    ("        'صدر ديك رومي مشوي',", "        'هريس أسيرولا غير محلى',"),
]
for old, new in replacements:
    assert s.count(old) == 1, old
    s = s.replace(old, new, 1)
p.write_text(s)

qa = subprocess.check_output(
    ['git', 'show', BASE + ':.github/workflows/bil_sapphire_history_qa.yml']
).decode()

old = """      - name: Commit exact prepared source before reference verification
        id: source
        run: |
          set -euo pipefail
          git config user.name 'BIL source maintenance'
          git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
          git add lib test pubspec.yaml docs/release tool/sapphire
          if ! git diff --cached --quiet; then
            git commit -m 'fix(prebuild): apply final guarded navigation and presentation fixes'
            git push origin HEAD:fix/community-sapphire-health-3033
          fi
          echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
          # The final prebuild polish intentionally changes presentation outside
          # the previously reviewed Community source hash. Run the strict full
          # suite against committed masters and collect any visual diffs; never
          # regenerate a reference here.
          echo 'references_ready=true' >> "$GITHUB_OUTPUT"
"""
new = """      - name: Verify source is already prepared and immutable
        id: source
        run: |
          set -euo pipefail
          if ! git diff --quiet || ! git diff --cached --quiet; then
            echo 'Committed release source is not formatter/prepare clean.' >&2
            git status --short
            git diff --check
            exit 1
          fi
          echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
          echo 'references_ready=true' >> "$GITHUB_OUTPUT"
"""
assert old in qa
qa = qa.replace(old, new, 1)

old_guard = "          git diff --exit-code 59839c7deb4d1cc860275b9e69578e299cc24d0a HEAD -- ios/Runner android/app/src lib/features/dashboard lib/features/global_platform/health_data lib/features/global_platform/intelligence/global_health_evidence_graph.dart\n"
new_guard = r"""          git diff --exit-code 59839c7deb4d1cc860275b9e69578e299cc24d0a HEAD -- ios/Runner lib/features/dashboard lib/features/global_platform/health_data lib/features/global_platform/intelligence/global_health_evidence_graph.dart
          python3 - <<'PY'
          import pathlib,re,subprocess
          base='59839c7deb4d1cc860275b9e69578e299cc24d0a'
          android_changed=subprocess.check_output([
              'git','diff','--name-only',base,'HEAD','--','android/app/src'
          ]).decode().splitlines()
          allowed_exact={
              'android/app/src/main/AndroidManifest.xml',
              'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/PermissionsRationaleActivity.kt',
          }
          allowed_patterns=(
              re.compile(r'^android/app/src/main/res/values(?:-[^/]+)?/strings[.]xml$'),
              re.compile(r'^android/app/src/main/res/values(?:-[^/]+)?/styles[.]xml$'),
          )
          unexpected=[
              p for p in android_changed
              if p not in allowed_exact and not any(rx.match(p) for rx in allowed_patterns)
          ]
          assert not unexpected, f'Unexpected native Android/Watch change: {unexpected}'
          path='lib/features/connected_health/connected_health_signal_detail_page.dart'
          old=subprocess.check_output(['git','show',base+':'+path]).decode()
          new=pathlib.Path(path).read_text()
          def live(s): return s[s.index('class _MeasuredSignalCard'):s.index('class _SignalHistoryCard')]
          assert live(old)==live(new),'Live Watch/current-value card changed'
          PY
"""
assert old_guard in qa
qa = qa.replace(old_guard, new_guard, 1)

duplicate = """          python3 - <<'PY'
          import pathlib,subprocess
          path='lib/features/connected_health/connected_health_signal_detail_page.dart'
          old=subprocess.check_output(['git','show','59839c7deb4d1cc860275b9e69578e299cc24d0a:'+path]).decode()
          new=pathlib.Path(path).read_text()
          def live(s): return s[s.index('class _MeasuredSignalCard'):s.index('class _SignalHistoryCard')]
          assert live(old)==live(new),'Live Watch/current-value card changed'
          PY
"""
assert duplicate in qa
qa = qa.replace(duplicate, '', 1)

needle = ' test/responsive_shell_test.dart 2>&1 | tee /tmp/sapphire-focused/focused.log'
add = ' test/responsive_shell_test.dart test/app/localization/food_log_runtime_copy_test.dart test/app/router/quick_add_premium_capture_actions_contract_test.dart test/app/theme/premium_black_dark_theme_contract_test.dart test/features/intelligence_center/ai_coach_premium_welcome_contract_test.dart test/features/nutrition/food_presentation_localizer_test.dart test/features/onboarding/premium_consent_surface_contract_test.dart test/launch_readiness/trusted_food_search_backend_contract_test.dart test/platform_readiness/android_health_permission_premium_contract_test.dart test/platform_readiness/mobile_release_configuration_contract_test.dart test/platform_readiness/premium_global_native_parity_contract_test.dart test/shared/widgets/premium_trust_and_clinical_surface_test.dart 2>&1 | tee /tmp/sapphire-focused/focused.log'
assert needle in qa
qa = qa.replace(needle, add, 1)

needle = 'supabase/functions/push-provider-gateway supabase/functions/community-push-dispatch 2>&1 | tee /tmp/sapphire-visual/push.log'
repl = 'supabase/functions/push-provider-gateway supabase/functions/community-push-dispatch supabase/functions/food-search 2>&1 | tee /tmp/sapphire-visual/push.log'
assert needle in qa
qa = qa.replace(needle, repl, 1)

Path('.github/workflows/bil_sapphire_history_qa.yml').write_text(qa)
