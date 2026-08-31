begin;

create index if not exists bil_admin_notification_audit_actor_idx
  on private.bil_admin_notification_audit(actor_id);

create index if not exists bil_admin_notification_audit_target_idx
  on private.bil_admin_notification_audit(target_id);

commit;
