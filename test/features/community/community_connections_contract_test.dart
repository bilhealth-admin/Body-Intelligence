import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connections surface is Supabase-backed and fail-safe', () {
    final source = File(
      'lib/features/community/presentation/community_connections_page.dart',
    ).readAsStringSync();
    expect(source, contains('loadFriendshipsWithProfiles'));
    expect(source, contains("context.push('/community/people')"));
    expect(source, contains("context.push('/login')"));
    expect(source, contains('_ConnectionsLoadError'));
    expect(source, contains('_busyConnections'));
    expect(source, isNot(contains('3x')));
  });

  test('connections copy has direct entries in all extended locales', () {
    const keys = {
      'Friends and requests',
      'Find people',
      'Could not load connections safely.',
      'No requests or friends yet.',
      'Incoming friend request',
      'Request awaiting response',
      'Accept',
      'Decline',
      'Message',
      'Remove friend',
      'Block member',
      'Sign in to view friends and requests.',
      'You control your connections',
      'Your health data stays private. Only accept people you know.',
    };
    expect(RuntimeCopy.supported, hasLength(25));
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        expect(
          ExtendedRuntimeCopy.values[key]?.containsKey(locale),
          isTrue,
          reason: 'missing direct $locale/$key',
        );
        expect(ExtendedRuntimeCopy.values[key]![locale]!.trim(), isNotEmpty);
      }
    }
  });

  test('community profile copy has direct entries in all extended locales', () {
    const keys = {
      'Community profile',
      'Display name',
      'Bio',
      'Let people find me',
      'Members can find you and send a friend request.',
      'Save profile',
      'Community profile saved.',
      'Enter at least two characters.',
      'Could not load your community profile safely.',
      'Could not save your profile now. Try again.',
      'Your measurements and health logs stay private.',
      'Could not request account deletion. Try again.',
    };
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = ExtendedRuntimeCopy.values[key]?[locale]?.trim();
        expect(value, isNotNull, reason: 'missing direct $locale/$key');
        expect(value, isNotEmpty, reason: 'empty direct $locale/$key');
        if (key != 'Bio') {
          expect(value, isNot(key), reason: 'English fallback $locale/$key');
        }
      }
    }
  });

  test('community updates copy has direct entries in all extended locales', () {
    const keys = {
      'Community updates',
      'Community updates are unavailable',
      'BIL could not check your updates safely. Try again.',
      'Sign in required',
      'Sign in to check private community updates.',
      'No community updates',
      'Friend requests and unread messages will appear here.',
      'Find people',
      'Friend requests',
      'Unread messages',
    };
    for (final key in keys) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = ExtendedRuntimeCopy.values[key]?[locale]?.trim();
        expect(value, isNotNull, reason: 'missing direct $locale/$key');
        expect(value, isNotEmpty, reason: 'empty direct $locale/$key');
        expect(value, isNot(key), reason: 'English fallback $locale/$key');
      }
    }
  });
}
