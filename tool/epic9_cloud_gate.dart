import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

Never fail(String message) {
  stderr.writeln('EPIC9_CLOUD_GATE=FAIL');
  stderr.writeln(message);
  exit(1);
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    fail('Expected the path to a temporary QA configuration file.');
  }
  final configFile = File(args.single);
  if (!configFile.existsSync()) {
    fail('The temporary QA configuration file does not exist.');
  }
  final decoded = jsonDecode(await configFile.readAsString());
  if (decoded is! Map<String, dynamic>) {
    fail('The temporary QA configuration is invalid.');
  }
  String required(String key) {
    final value = decoded[key];
    if (value is! String || value.trim().isEmpty) {
      fail('The temporary QA configuration is missing $key.');
    }
    return value.trim();
  }

  final clientA = SupabaseClient(
    required('SUPABASE_URL'),
    required('SUPABASE_ANON_KEY'),
  );
  final clientB = SupabaseClient(
    required('SUPABASE_URL'),
    required('SUPABASE_ANON_KEY'),
  );
  try {
    stdout.writeln('STEP=authenticate_two_accounts');
    final authA = await clientA.auth
        .signInWithPassword(
          email: required('BIL_EPIC9_ACCOUNT_A_EMAIL'),
          password: required('BIL_EPIC9_ACCOUNT_A_PASSWORD'),
        )
        .timeout(const Duration(seconds: 20));
    final authB = await clientB.auth
        .signInWithPassword(
          email: required('BIL_EPIC9_ACCOUNT_B_EMAIL'),
          password: required('BIL_EPIC9_ACCOUNT_B_PASSWORD'),
        )
        .timeout(const Duration(seconds: 20));
    final userA = authA.user;
    final userB = authB.user;
    if (userA == null || userB == null || userA.id == userB.id) {
      fail('Two independent authenticated users were not returned.');
    }

    stdout.writeln('STEP=prepare_public_profiles');
    await clientA.from('bil_blocks').delete().eq('blocked_id', userB.id);
    await clientB.from('bil_blocks').delete().eq('blocked_id', userA.id);
    await clientA.from('bil_public_profiles').upsert({
      'user_id': userA.id,
      'display_name': 'BIL QA Account A',
      'locale_code': 'en',
      'discoverable': true,
      'profile_visibility': 'public',
      'allow_friend_requests': true,
      'allow_follows': true,
      'allow_messages_from': 'friends',
    });
    await clientB.from('bil_public_profiles').upsert({
      'user_id': userB.id,
      'display_name': 'BIL QA Account B',
      'locale_code': 'en',
      'discoverable': true,
      'profile_visibility': 'friends',
      'allow_friend_requests': true,
      'allow_follows': true,
      'allow_messages_from': 'friends',
    });

    stdout.writeln('STEP=friendship_request_and_accept');
    final existing = await clientA
        .from('bil_friendships')
        .select('id,status,requester_id,addressee_id')
        .or(
          'and(requester_id.eq.${userA.id},addressee_id.eq.${userB.id}),'
          'and(requester_id.eq.${userB.id},addressee_id.eq.${userA.id})',
        );
    if (existing.isEmpty) {
      await clientA.rpc(
        'bil_request_friendship',
        params: {'p_addressee_id': userB.id},
      );
    }
    final friendship = await clientB
        .from('bil_friendships')
        .select('id,status,requester_id,addressee_id')
        .or(
          'and(requester_id.eq.${userA.id},addressee_id.eq.${userB.id}),'
          'and(requester_id.eq.${userB.id},addressee_id.eq.${userA.id})',
        )
        .single();
    if (friendship['status'] != 'accepted') {
      await clientB
          .from('bil_friendships')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', friendship['id']);
    }

    stdout.writeln('STEP=message_send_and_receive');
    final message = await clientA
        .from('bil_messages')
        .insert({
          'sender_id': userA.id,
          'recipient_id': userB.id,
          'body': 'Epic 9 two-account verification',
        })
        .select('id')
        .single();
    final received = await clientB
        .from('bil_messages')
        .select('id,sender_id,recipient_id')
        .eq('id', message['id'])
        .single();
    if (received['sender_id'] != userA.id ||
        received['recipient_id'] != userB.id) {
      fail('The recipient could not read the authoritative message.');
    }

    stdout.writeln('STEP=community_post_publish_and_read');
    final post = await clientA
        .from('bil_community_posts')
        .insert({
          'author_id': userA.id,
          'body': 'Epic 9 non-personal community post verification',
        })
        .select('id,author_id,body')
        .single();
    final visiblePost = await clientB
        .from('bil_community_posts')
        .select('id,author_id,body')
        .eq('id', post['id'])
        .single();
    if (visiblePost['author_id'] != userA.id ||
        visiblePost['body'] != post['body']) {
      fail('The second account could not read the authoritative post.');
    }

    stdout.writeln('STEP=report_and_block');
    await clientB.from('bil_community_reports').insert({
      'reporter_id': userB.id,
      'target_kind': 'message',
      'target_id': message['id'],
      'reason': 'Automated Epic 9 safety-path verification',
    });
    await clientB.rpc(
      'bil_block_community_member',
      params: {'p_blocked_id': userA.id},
    );
    final block = await clientB
        .from('bil_blocks')
        .select('blocked_id')
        .eq('blocked_id', userA.id)
        .single();
    if (block['blocked_id'] != userA.id) {
      fail('The authoritative block record was not returned.');
    }

    stdout.writeln('STEP=community_post_owner_delete');
    await clientA
        .from('bil_community_posts')
        .delete()
        .eq('id', post['id'])
        .eq('author_id', userA.id);
    final deletedPost = await clientA
        .from('bil_community_posts')
        .select('id')
        .eq('id', post['id']);
    if (deletedPost.isNotEmpty) {
      fail('The post remained visible after its owner deleted it.');
    }

    stdout.writeln('EPIC9_CLOUD_GATE=PASS');
  } on Object catch (error, stackTrace) {
    stderr.writeln('EPIC9_CLOUD_GATE=FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await clientA.dispose();
    await clientB.dispose();
  }
}
