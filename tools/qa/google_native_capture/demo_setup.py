"""Normal native onboarding of the dedicated review account, with labelled test data.

No DB injection, deep-link shortcut, subscription grant, or cloud-sync reset.
Fixture facts are derived from the repository's onboarding widget tests.
"""
import os
import re
import time

def complete_demo_setup(d, require, labels, select, package):
    require(os.environ.get('BIL_EXPECTED_REVIEWER_EMAIL_SHA256') ==
            '0953e0ce72671ea8330c96c41d0aa70e9b8578990532383c51edec2fb4002217',
            'demo_fixture_wrong_review_account')
    require(any('1 /' in s and 'Setup progress' in s for n in d.nodes() for s in labels(n)),
            'demo_setup_not_fresh_initial_screen')
    def tap(pattern, scroll=False):
        if scroll:d.scroll_to(pattern)
        d.tap(pattern)
    def hide_keyboard():
        state=d.adb('shell','dumpsys','input_method')
        if re.search(r'(?:mInputShown|mIsInputViewShown|isInputViewShown)=true',state):
            d.adb('shell','input','keyevent','KEYCODE_BACK')
    def fill(value):
        fields=[n for n in d.nodes() if n.get('package')==package and n.get('class')=='android.widget.EditText' and n.get('enabled')=='true']
        require(len(fields)==1,'demo_expected_one_visible_input')
        d.adb('shell','input','tap',*fields[0]['center'])
        d.adb('shell','input','keyevent','KEYCODE_MOVE_END')
        d.adb('shell','input','keyevent',*(['KEYCODE_DEL']*24))
        # Only hardcoded synthetic values, never credentials or user text.
        require(re.fullmatch(r'[0-9/A-Za-z]+',value),'unsupported_demo_value')
        d.adb('shell','input','text',value)
        hide_keyboard()
    def next_step(title):
        tap(r'Continue');d.see(title,seconds=30)
    d.start('dedicated-demo-onboarding')
    tap(r'Maintain weight(?:\s.*)?',True)
    next_step(r'What is your baseline activity\?')
    tap(r'Moderately active(?:\s.*)?',True)
    next_step(r'A few facts for your estimate')
    tap(r'Female',True)
    tap(r'Choose date of birth',True)
    tap(r'Switch to input')
    fill('05/17/1990')
    tap(r'OK|Save')
    # The read-only country field is the sole EditText on the facts screen.
    fields=[n for n in d.nodes() if n.get('package')==package and n.get('class')=='android.widget.EditText']
    require(len(fields)==1,'demo_country_field_not_unique')
    d.adb('shell','input','tap',*fields[0]['center']);time.sleep(1)
    fill('Egypt')
    rows=[n for n in d.nodes() if n.get('package')==package and n.get('class')!='android.widget.EditText'
          and any(re.search(r'\bEgypt\b',s) for s in labels(n))]
    centers={n['center'] for n in rows};require(centers and max(y for x,y in centers)-min(y for x,y in centers)<100,'demo_country_result_not_unique')
    d.adb('shell','input','tap',*sorted(centers,key=lambda pair:pair[0])[0]);time.sleep(1)
    next_step(r'Choose your units')
    # Metric is the untouched initial default; verify the real visible control.
    d.see(r'Metric');next_step(r'What is your height\?')
    fill('170');next_step(r'What is your current weight\?')
    fill('80');next_step(r'Keep your current weight')
    next_step(r'Add your waist measurement\?')
    tap(r'Skip');d.see(r'Add your neck measurement\?')
    tap(r'Skip');d.see(r'Add your hip measurement\?')
    tap(r'Skip');d.see(r'Your starting plan|Your personal starting plan|Daily energy estimate')
    tap(r'Continue');d.see(r'Optional connections')
    tap(r'Skip');d.see(r'Choose whether to use cloud AI')
    # Preserve an already-enabled choice. Otherwise choose the normal local-only
    # option, with no health data sent to Gemini to manufacture a video result.
    text='\n'.join(s for n in d.nodes() for s in labels(n))
    if 'Enabled with your explicit consent.' in text:tap(r'Continue')
    else:tap(r'Skip')
    d.see(r'Ready to start',seconds=45)
    tap(r'I understand these are educational estimates, not medical advice or guaranteed results\.',True)
    d.nodes('dedicated-demo-setup-reviewed')
    tap(r'Finish setup')
    d.see(r'Fitness snapshot|Calories|Home',seconds=60)
    d.stop()
    return {'source_fixture':'test/features/onboarding/onboarding_flow_widget_test.dart',
            'purpose':'Explicitly labelled synthetic demonstration; not personal health measurements',
            'birth_date':'1990-05-17','sex':'female','country':'Egypt','height_cm':170,
            'weight_kg':80,'target_weight_kg':80,'goal':'maintenance','activity':'moderate',
            'optional_circumferences':'skipped','health_permissions':'not granted during setup',
            'stored_through':'ordinary visible Finish setup transaction on disposable device',
            'cloud_sync_enabled_by_capture':False,'entitlements_changed':False}
