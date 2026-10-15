"""Deployed receipt compatibility cases for the real isolated PostgreSQL runner.

No test runs at import; all users, tokens and claims are synthetic. Authenticated
RPC here means the real SQL function under authenticated role/owner claims,
not a GoTrue/PostgREST or signed-device claim.
"""
import concurrent.futures
import uuid


def run_deployed_receipt_cases(ctx):
    execute = ctx['execute']
    scalar = ctx['scalar']
    value = ctx['value']
    uid = ctx['uid']
    post = ctx['post']
    snapshot = ctx['snapshot']
    decide = ctx['decide']
    check = ctx['check']
    assert_single_receipt = ctx['assert_single_receipt']
    delivery_digest = ctx['delivery_digest']
    push_source = ctx['push_source']
    receipt_migration = ctx['receipt_migration']
    baseline_post = ctx['baseline_post']
    baseline_history = ctx['baseline_history']

    def both_trigger_orders():
        for prefix,offset in (('aaa',0),('zzz',2)):
            execute(f"""alter trigger bil_post_approval_receipt_v1 on public.bil_community_post_approval_grants rename to {prefix}_approval;
              alter trigger bil_post_rejection_receipt_v1 on public.bil_community_posts rename to {prefix}_rejection;""")
            try:
                for shift,decision in enumerate(('approved','rejected')):
                    owner=83+offset+shift
                    identity=post(300+owner,owner=owner)
                    result=decide(identity,snapshot(identity,actor=1)['revision'],actor=1,
                                  decision=decision,reason='Synthetic order case')
                    tokens=5 if decision=='approved' else 0
                    assert result['tokens_granted']==tokens
                    assert_single_receipt(identity,tokens,decision)
                    assert scalar(f"select deep_link from public.bil_push_outbox where source_key='{push_source(identity,owner,decision)}';")==f'bil://community/post/{identity}'
            finally:
                execute(f"""alter trigger {prefix}_approval on public.bil_community_post_approval_grants rename to bil_post_approval_receipt_v1;
                  alter trigger {prefix}_rejection on public.bil_community_posts rename to bil_post_rejection_receipt_v1;""")
    check('captured V1 hooks before or after V2 hooks preserve one canonical receipt',both_trigger_orders)

    def seen_and_requeue():
        for owner,decision,capped in ((87,'approved',False),(88,'approved',True),(89,'rejected',False)):
            if capped:
                execute(f"""insert into public.bil_community_post_reward_usage
                  (owner_id,reward_day,rewarded_posts,granted_tokens)
                  values('{uid(owner)}',timezone('UTC',now())::date,5,25);""")
            execute(f"""insert into public.bil_push_device_tokens
              (user_id,token_ciphertext,token_fingerprint,platform)
              values('{uid(owner)}','synthetic-ciphertext','qa-{owner}','fcm');""")
            for direction_index,direction in enumerate(('activity','notifications','event')):
                identity=post(400+owner*3+direction_index,owner=owner)
                decide(identity,snapshot(identity,actor=1)['revision'],actor=1,
                       decision=decision,reason='Synthetic seen case')
                event_id=scalar(f"select id from private.bil_community_post_events_v1 where entity_id='{identity}';")
                events=value('select public.bil_list_my_post_events_v1();',uid(owner))
                assert any(event['id']==event_id for event in events)
                source=push_source(identity,owner,decision)
                execute(f"""update public.bil_push_outbox set dispatched_at=now(),failure_code='no_eligible_tokens'
                  where source_key='{source}';""")
                assert scalar(f"select private.bil_requeue_post_notices_for_owner_v1('{uid(owner)}');")=='1'
                execute(f"""update public.bil_push_outbox set dispatched_at=now(),failure_code='no_eligible_tokens'
                  where source_key='{source}';""")
                if direction in ('activity','notifications'):
                    activity_id=scalar(f"select id from public.bil_community_notifications where entity_id='{identity}';")
                    api=('public.bil_mark_community_activity_seen_v2' if direction=='activity'
                         else 'public.bil_mark_community_notifications_seen')
                    assert scalar(f"select {api}(array['{activity_id}'::uuid]);",uid(90))=='0'
                    assert scalar(f"select {api}(array['{activity_id}'::uuid]);",uid(owner))=='1'
                else:
                    assert scalar(f"select public.bil_mark_my_post_events_seen_v1(array['{event_id}'::uuid]);",uid(90))=='0'
                    assert scalar(f"select public.bil_mark_my_post_events_seen_v1(array['{event_id}'::uuid]);",uid(owner))=='1'
                assert scalar(f"select seen_at is not null from private.bil_community_post_events_v1 where id='{event_id}';")=='t'
                assert scalar(f"select bool_and(seen_at is not null) from public.bil_community_notifications where entity_id='{identity}';")=='t'
                assert scalar(f"select private.bil_requeue_post_notices_for_owner_v1('{uid(owner)}');")=='0'
                assert_single_receipt(identity,0 if capped or decision=='rejected' else 5,decision)
    check('positive zero and rejected seen sync both directions preserves legacy requeue',seen_and_requeue)

    def legacy_drift_is_rejected():
        before=scalar("select md5(pg_get_functiondef('private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)'::regprocedure));")
        execute('alter trigger bil_post_approval_receipt_v1 on public.bil_community_post_approval_grants rename to qa_unexpected_approval;')
        try:
            execute(receipt_migration.read_text(encoding='utf-8'),expect_error='post_review_legacy_contract_changed')
            assert scalar("select md5(pg_get_functiondef('private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)'::regprocedure));")==before
        finally:
            execute('alter trigger qa_unexpected_approval on public.bil_community_post_approval_grants rename to bil_post_approval_receipt_v1;')
        execute(receipt_migration.read_text(encoding='utf-8'))
        assert delivery_digest(baseline_post)==baseline_history
    check('unexpected deployed trigger drift fails atomically and reapply preserves history',legacy_drift_is_rejected)



    def observe_wait(application, expected_wait):
        for _ in range(60):
            state=value(f"""select coalesce((select jsonb_build_object(
              'pid',pid,'wait',wait_event,'type',wait_event_type)
              from pg_stat_activity where application_name='{application}' limit 1),'{{}}'::jsonb);""")
            if state.get('wait')==expected_wait:
                return state
        raise AssertionError(f'{application} did not reach {expected_wait}')

    def concurrent_authenticated_seen():
        for index,(decision,capped,notification_kind,first_kind) in enumerate(
                (decision,capped,notification_kind,kind)
                for notification_kind in ('activity','notifications')
                for decision,capped in (('approved',False),('approved',True),('rejected',False))
                for kind in (notification_kind,'event')):
            owner=100+index
            identity=post(700+owner,owner=owner)
            if capped:
                execute(f"""insert into public.bil_community_post_reward_usage
                  (owner_id,reward_day,rewarded_posts,granted_tokens)
                  values('{uid(owner)}',timezone('UTC',now())::date,5,25);""")
            decide(identity,snapshot(identity,actor=1)['revision'],actor=1,
                   decision=decision,reason='Synthetic concurrent seen case')
            activity_id=scalar(f"select id from public.bil_community_notifications where entity_id='{identity}';")
            event_id=scalar(f"select id from private.bil_community_post_events_v1 where entity_id='{identity}';")
            calls={
              'activity':f"public.bil_mark_community_activity_seen_v2(array['{activity_id}'::uuid])",
              'notifications':f"public.bil_mark_community_notifications_seen(array['{activity_id}'::uuid])",
              'event':f"public.bil_mark_my_post_events_seen_v1(array['{event_id}'::uuid])"}
            second_kind='event' if first_kind==notification_kind else notification_kind
            tag=uuid.uuid4().hex[:10]
            first_name=f'bil_seen_first_{tag}'
            second_name=f'bil_seen_second_{tag}'
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                first=pool.submit(execute,
                    f"set local application_name='{first_name}'; select {calls[first_kind]}; select pg_sleep(4);",
                    actor=uid(owner))
                observe_wait(first_name,'PgSleep')
                second=pool.submit(value,
                    f"set local application_name='{second_name}'; select {calls[second_kind]};",uid(owner))
                waiting=observe_wait(second_name,'advisory')
                # The second real RPC must wait BEFORE any target row write,
                # not after it has acquired an opposing Activity/event row.
                write_locks=int(scalar(f"""select count(*) from pg_locks where pid={waiting['pid']}
                  and granted and (locktype='tuple' or (locktype='relation'
                    and mode='RowExclusiveLock' and relation in (
                      'public.bil_community_notifications'::regclass,
                      'private.bil_community_post_events_v1'::regclass)));"""))
                assert write_locks==0 and not second.done()
                assert first.result()[-1]=='1'
                assert second.result()==0
            assert scalar(f"select seen_at is not null from private.bil_community_post_events_v1 where id='{event_id}';")=='t'
            assert scalar(f"select seen_at is not null from public.bil_community_notifications where id='{activity_id}';")=='t'
            ctx.setdefault('seen_overlap_observations',[]).append({
                'owner_fixture':owner,'decision':decision,
                'tokens':0 if capped or decision=='rejected' else 5,
                'first_api':first_kind,'second_api':second_kind,
                'first_rpc':calls[first_kind].split('(')[0],
                'second_rpc':calls[second_kind].split('(')[0],
                'second_wait':waiting['wait'],'target_write_locks_before_admission':write_locks,
                'first_count':1,'second_count':0,'both_committed':True})
            assert_single_receipt(identity,0 if capped or decision=='rejected' else 5,decision)
    check('all three authenticated seen RPCs overlap in both orders before row updates',concurrent_authenticated_seen)

    def guarded_default_partial_acl_drift():
        before=scalar("select md5(pg_get_functiondef('private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)'::regprocedure));")
        mutations=(
          ("alter table private.bil_community_post_events_v1 alter column id drop default;",
           "alter table private.bil_community_post_events_v1 alter column id set default gen_random_uuid();"),
          ("alter table private.bil_community_post_events_v1 alter column created_at set default now();",
           "alter table private.bil_community_post_events_v1 alter column created_at set default clock_timestamp();"),
          ("alter function private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean) rename to qa_missing_legacy_emitter;",
           "alter function private.qa_missing_legacy_emitter(uuid,text,text,uuid,integer,text,boolean) rename to bil_emit_post_receipt_v1;"),
          ("grant execute on function private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean) to authenticated;",
           "revoke execute on function private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean) from authenticated;"))
        for mutate,restore in mutations:
            execute(mutate)
            try:
                execute(receipt_migration.read_text(encoding='utf-8'),expect_error='post_review_legacy_contract_changed')
                assert scalar("select md5(pg_get_functiondef('private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)'::regprocedure));")==before
            finally:
                execute(restore)
        execute(receipt_migration.read_text(encoding='utf-8'))
        assert delivery_digest(baseline_post)==baseline_history
    check('id timestamp defaults partial legacy and ACL drift fail before installation',guarded_default_partial_acl_drift)

    def legacy_notification_seen_guard_drift():
        signature='public.bil_mark_community_notifications_seen(uuid[])'
        definition=value(f"select to_jsonb(pg_get_functiondef('{signature}'::regprocedure));")
        helper_hash=scalar("select md5(pg_get_functiondef('private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)'::regprocedure));")
        mutations=(
          (f"grant execute on function {signature} to anon;",
           f"revoke execute on function {signature} from anon;"),
          (definition.replace("'invalid_notification_ids'","'qa_invalid_notification_ids'"),
           definition))
        for mutate,restore in mutations:
            execute(mutate)
            try:
                execute(receipt_migration.read_text(encoding='utf-8'),expect_error='post_review_seen_api_changed')
                assert scalar("select md5(pg_get_functiondef('private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)'::regprocedure));")==helper_hash
            finally:
                execute(restore)
        execute(receipt_migration.read_text(encoding='utf-8'))
        assert scalar(f"select has_function_privilege('authenticated','{signature}','execute');")=='t'
        assert scalar(f"select has_function_privilege('anon','{signature}','execute');")=='f'
        assert scalar(f"select has_function_privilege('service_role','{signature}','execute');")=='f'
        assert delivery_digest(baseline_post)==baseline_history
    check('legacy notification seen definition and ACL drift fail atomically',legacy_notification_seen_guard_drift)

    def requeue_delivery_exclusions():
        for index,state in enumerate(('delivered','active_lease','terminal','expired','eligible')):
            owner=120+index
            identity=post(800+owner,owner=owner)
            decide(identity,snapshot(identity,actor=1)['revision'],actor=1)
            token=scalar(f"""insert into public.bil_push_device_tokens
              (user_id,token_ciphertext,token_fingerprint,platform)
              values('{uid(owner)}','synthetic-ciphertext','qa-requeue-{owner}','fcm') returning id;""")
            source=push_source(identity,owner)
            outbox=scalar(f"select id from public.bil_push_outbox where source_key='{source}';")
            execute(f"""update public.bil_push_outbox set dispatched_at=now(),failure_code='no_eligible_tokens'
              where id='{outbox}';""")
            if state in ('delivered','active_lease','terminal'):
                fields={
                  'delivered':"delivered_at",
                  'active_lease':"leased_until",
                  'terminal':"terminal_at,permanent_token_failure,failure_code"}[state]
                values={
                  'delivered':"now()",
                  'active_lease':"now()+interval '1 hour'",
                  'terminal':"now(),true,'qa_terminal'"}[state]
                execute(f"""insert into public.bil_push_delivery_attempts
                  (outbox_id,device_token_id,{fields})
                  values('{outbox}','{token}',{values});""")
            if state=='expired':
                execute(f"update public.bil_push_outbox set created_at=now()-interval '25 hours' where id='{outbox}';")
            before=delivery_digest(identity)
            attempts=scalar(f"select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb)::text from public.bil_push_delivery_attempts a where outbox_id='{outbox}';")
            assert scalar(f"select private.bil_requeue_post_notices_for_owner_v1('{uid(owner)}');")==('1' if state=='eligible' else '0')
            assert scalar(f"select coalesce(jsonb_agg(to_jsonb(a)),'[]'::jsonb)::text from public.bil_push_delivery_attempts a where outbox_id='{outbox}';")==attempts
            if state!='eligible':
                assert delivery_digest(identity)==before
            assert_single_receipt(identity)
    check('requeue excludes delivered leased terminal and older than 24h receipts',requeue_delivery_exclusions)
