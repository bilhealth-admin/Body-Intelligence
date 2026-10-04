from pathlib import Path
import hashlib,json,re
expected={
'lib/features/community/domain/community_models.dart':'6161cd805e70a5831a29ee12acbc6d851566e5047a2a4a6ec3b883b46b24397c',
'lib/features/notifications/presentation/notification_settings_page.dart':'8039849d8b0a3bd9d6f9574bc2bd4a09023e3bf27eac6bf0c2d01380110ac528',
'lib/app/router/app_router.dart':'996c608311b11d71752920e3dcc0a457599548a42cb782a52c0e8695f66cceb9',
 'test/features/community/community_polish_visual_test.dart':'3ed9f9bc06dbc8bc8ce90399a0845a33d70471dc891a82952553443ab3c4e9f9',
}
for name,digest in expected.items():
 assert hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest, name
model=Path('lib/features/community/domain/community_models.dart')
s=model.read_text(); marker='class CommunityComment {'; a,b=s.split(marker,1); body=marker+b; model_body=body
modelpart=model.with_name('community_content_models.dart');assert not modelpart.exists()
modelpart.write_text("part of 'community_models.dart';\n\n"+body)
model.write_text(a.replace("part 'community_post_author_social.dart';", "part 'community_post_author_social.dart';\npart 'community_content_models.dart';"))
assert (model.read_text().replace("part 'community_content_models.dart';\n",'')+modelpart.read_text().split('\n\n',1)[1])==s
notification=Path('lib/features/notifications/presentation/notification_settings_page.dart');s=notification.read_text()
marker='  String _referenceLabel(String english) {'; a,b=s.split(marker,1); body=marker+b;assert body.endswith('}\n')
notifpart=notification.with_name('notification_settings_copy_helpers.dart');assert not notifpart.exists()
notifpart.write_text("part of 'notification_settings_page.dart';\n\nextension _NotificationSettingsCopyHelpers on _NotificationSettingsPageState {\n"+body)
notification.write_text(a+'}\n')
notification.write_text(notification.read_text().replace("part 'notification_settings_actions.dart';", "part 'notification_settings_actions.dart';\npart 'notification_settings_copy_helpers.dart';"))
router=Path('lib/app/router/app_router.dart');s=router.read_text()
start=s.index("      GoRoute(\n        path: '/community',")
end=s.index("      GoRoute(\n        path: '/food-libraries',",start)
routes=s[start:end];routepart=router.with_name('app_community_routes.dart');assert not routepart.exists()
routepart.write_text("part of 'app_router.dart';\n\nabstract final class _CommunityRoutes {\n  static List<RouteBase> build() {\n    return [\n"+routes+"    ];\n  }\n}\n")
router.write_text((s[:start]+'      ..._CommunityRoutes.build(),\n'+s[end:]).replace("part 'app_wellness_routes.dart';", "part 'app_wellness_routes.dart';\npart 'app_community_routes.dart';"))
assert routepart.read_text().split('    return [\n',1)[1].rsplit('    ];',1)[0]==routes
parts={str(model):str(modelpart),str(notification):str(notifpart),str(router):str(routepart)}
adapted=[]
for test in Path('test').rglob('*.dart'):
 original=test.read_text(); text=original
 for main,part in parts.items():
  pattern=r"File\(\s*'"+re.escape(main)+r"'\s*,?\s*\)\.readAsStringSync\(\)"
  replacement="[File('"+main+"').readAsStringSync(), File('"+part+"').readAsStringSync()].join('\\n')"
  text=re.sub(pattern,lambda _:replacement,text)
  text=text.replace("source('"+main+"')", "(source('"+main+"') + source('"+part+"'))")
 if text!=original:
  test.write_text(text);adapted.append(str(test))
visual=Path('test/features/community/community_polish_visual_test.dart');s=visual.read_text()
marker='  @override\n  Future<CommunityFeedBatch> loadMyPosts('
assert s.count(marker)==1
stub="""  @override
  Future<List<CommunityNotification>> loadCommunityNotifications({
    int limit = 30,
  }) async => [
    CommunityNotification(
      id: '99999999-9999-4999-8999-999999999999',
      kind: CommunityNotificationKind.friendAccepted,
      actorId: peer,
      actorDisplayName: name,
      createdAt: DateTime.utc(2026, 10, 3, 8),
      entityKind: 'friendship',
      entityId: '33333333-3333-4333-8333-333333333333',
      friendshipId: '33333333-3333-4333-8333-333333333333',
      copyKey: 'friend_accepted_v1',
      deepLinkPath: '/community/connections',
    ),
  ];
"""
s=s.replace(marker,stub+marker)
marker='              expect(tester.takeException(), isNull, reason: scene.key);'
assert s.count(marker)==1
s=s.replace(marker,marker+"""
              if (scene.key == 'updates') {
                expect(
                  find.byKey(const Key('community-activity-filter-all')),
                  findsOneWidget,
                  reason: 'Activity evidence must show loaded server-contract rows, not an error fallback',
                );
              }""")
visual.write_text(s)
for p in [model,modelpart,notification,notifpart,router,routepart]: assert len(p.read_text().splitlines())<=700,(str(p),len(p.read_text().splitlines()))
proof={'unchanged_route_block_sha256':hashlib.sha256(routes.encode()).hexdigest(),'unchanged_model_body_sha256':hashlib.sha256(model_body.encode()).hexdigest(),'adapted_source_readers':adapted,'line_counts':{str(p):len(p.read_text().splitlines()) for p in [model,modelpart,notification,notifpart,router,routepart]}}
Path('/tmp/bil-forward').mkdir(exist_ok=True)
Path('/tmp/bil-forward/refactor-proof.json').write_text(json.dumps(proof,indent=2))
english_mic_old='BIL uses the microphone only when you choose voice input for weight, a meal, or speak directly with BIL AI Coach.'
english_mic_new='BIL uses the microphone only when you choose voice input for weight, a meal, a Community post, or BIL AI Coach. You can review the text before saving, posting, or sending it.'
english_speech_old='BIL converts speech you initiate for weight or meal logging, or BIL AI Coach, into text so you can review or send it.'
english_speech_new='BIL converts speech you initiate for weight, meals, Community posts, or BIL AI Coach into text so you can review it before saving, posting, or sending it.'
for name in ['ios/Runner/Info.plist','ios/Runner/en.lproj/InfoPlist.strings']:
 p=Path(name);t=p.read_text();assert t.count(english_mic_old)==1 and t.count(english_speech_old)==1
 p.write_text(t.replace(english_mic_old,english_mic_new).replace(english_speech_old,english_speech_new))
p=Path('ios/Runner/ar.lproj/InfoPlist.strings');t=p.read_text()
old='يستخدم BIL الميكروفون فقط عندما تختار إدخال الوزن أو وجبة صوتيًا، أو التحدث مباشرة مع مدرب BIL الذكي.'
new='يستخدم BIL الميكروفون فقط عندما تختار إدخال الوزن أو وجبة أو منشور في المجتمع صوتيًا، أو التحدث مع مدرب BIL الذكي. يمكنك مراجعة النص قبل حفظه أو نشره أو إرساله.'
assert t.count(old)==1;t=t.replace(old,new)
old='يحوّل BIL الكلام الذي تبدأه لإدخال الوزن أو تسجيل وجبة أو التحدث مع مدرب BIL الذكي إلى نص لتراجعه أو ترسله.'
new='يحوّل BIL الكلام الذي تبدأه لإدخال الوزن أو الوجبات أو منشورات المجتمع أو مدرب BIL الذكي إلى نص لتراجعه قبل حفظه أو نشره أو إرساله.'
assert t.count(old)==1;p.write_text(t.replace(old,new))
