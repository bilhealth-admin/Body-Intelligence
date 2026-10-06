"""Verify tracked reference presentation; never transform source during tests."""
from pathlib import Path
required = {
    'lib/features/intelligence_center/presentation/intelligence_center_page.dart': '_buildReferenceChat',
    'lib/features/community/presentation/community_hub_page.dart': 'BilReferenceBottomBar',
    'lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart': 'CoachReferenceWorkspace',
}
for name, marker in required.items():
    if marker not in Path(name).read_text():
        raise RuntimeError('Reference presentation missing: ' + name)
print('Reference presentation is tracked source. No transformations performed.')
