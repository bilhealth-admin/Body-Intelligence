"""Keep the native Watch/current-value boundary frozen while allowing reviewed guide UI.
The three guide/arrow files and one reviewed privacy declaration are pinned to
exact Git blobs; this is not a blanket exclusion or a new native/health baseline.
"""
from pathlib import Path
import subprocess
import sys

BASELINE = '8ec83ed81066c324cfd7119363ab31d73a8d4b97'
REVIEWED_GUIDANCE = {
    'lib/features/dashboard/widgets/dashboard_carousel.dart': 'd07e741ea5dd313ec0f759bf0e69ecb80f6c49ef',
    'lib/features/dashboard/widgets/first_food_days_guide.dart': '595aa236b78fcc8a0dafab5c7a0a344c8d394dcf',
    'lib/features/dashboard/widgets/first_use_context_coachmark.dart': '5e82f15a39b27b5ae746d8f563a24dd21cc77e7d',
}
# 1484cbee adds truthful Analytics purposes for UserID/ProductInteraction only.
# Preserve the original native boundary and reject any later declaration change.
REVIEWED_PRIVACY_DECLARATIONS = {
    'ios/Runner/PrivacyInfo.xcprivacy': 'efc6431400a6e8e3f36dcb4d587a36084928aae6',
}
SIGNAL_PAGE = 'lib/features/connected_health/connected_health_signal_detail_page.dart'
# Preserve every original path and original reviewed exclusion from the workflow.
PROTECTED_PATHS = (
    'ios/Runner', 'android/app/src',
    ':(exclude)android/app/src/main/AndroidManifest.xml',
    ':(exclude)android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/PermissionsRationaleActivity.kt',
    ':(exclude)android/app/src/main/res/values*/strings.xml',
    ':(exclude)android/app/src/main/res/values*/styles.xml',
    'lib/features/dashboard',
    ':(exclude)lib/features/dashboard/widgets/dashboard_shell.dart',
    ':(exclude)lib/features/dashboard/widgets/dashboard_reference_phone_components.dart',
    ':(exclude)lib/features/dashboard/widgets/dashboard_reference_phone_sections.dart',
    ':(exclude)lib/features/dashboard/widgets/dashboard_grid.dart',
    ':(exclude)lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    ':(exclude)lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ':(exclude)lib/features/dashboard/widgets/premium_dashboard_card_lock.dart',
    'lib/features/global_platform/health_data',
    'lib/features/global_platform/intelligence/global_health_evidence_graph.dart',
)


class WatchBoundaryChanged(RuntimeError):
    pass


def git(repo, *args):
    return subprocess.check_output(['git', *args], cwd=repo, stderr=subprocess.PIPE).decode('utf-8')


def measured_card(text):
    text = text.replace('\r\n', '\n')
    return text[text.index('class _MeasuredSignalCard'):text.index('class _SignalHistoryCard')]


def verify(repo, baseline=BASELINE, reviewed=None, reviewed_privacy=None):
    reviewed = REVIEWED_GUIDANCE if reviewed is None else reviewed
    reviewed_privacy = REVIEWED_PRIVACY_DECLARATIONS if reviewed_privacy is None else reviewed_privacy
    for path, expected in reviewed.items():
        actual = git(repo, 'hash-object', '--path=' + path, '--', path).strip()
        if actual != expected:
            raise WatchBoundaryChanged('Reviewed guidance changed: ' + path)
    for path, expected in reviewed_privacy.items():
        if not (repo / path).is_file():
            raise WatchBoundaryChanged('Reviewed privacy declaration missing: ' + path)
        actual = git(repo, 'hash-object', '--path=' + path, '--', path).strip()
        if actual != expected:
            raise WatchBoundaryChanged('Reviewed privacy declaration changed: ' + path)
    protected = (
        *PROTECTED_PATHS,
        *(':(exclude)' + path for path in reviewed),
        *(':(exclude)' + path for path in reviewed_privacy),
    )
    changed = git(repo, 'diff', '--name-only', baseline, '--', *protected).splitlines()
    untracked = git(repo, 'ls-files', '--others', '--exclude-standard', '--', *protected).splitlines()
    if changed or untracked:
        raise WatchBoundaryChanged('Protected native/health/dashboard paths changed: ' + ', '.join(changed + untracked))
    old = git(repo, 'show', baseline + ':' + SIGNAL_PAGE)
    new = (repo / SIGNAL_PAGE).read_text(encoding='utf-8')
    if measured_card(old) != measured_card(new):
        raise WatchBoundaryChanged('Live Watch/current-value card changed')


if __name__ == '__main__':
    try:
        verify(Path.cwd())
    except (WatchBoundaryChanged, subprocess.CalledProcessError, ValueError, OSError) as error:
        print('NATIVE_WATCH_GUARD=FAIL: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
    print('NATIVE_WATCH_GUARD=PASS; original native/health baseline retained; three guide blobs and reviewed privacy declaration pinned')
