-- Preserve existing function ownership, EXECUTE ACL and sender/recipient predicates.
CREATE OR REPLACE FUNCTION public.bil_delete_message(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.bil_messages
  SET deleted_by_sender_at = pg_catalog.now()
  WHERE id = p_message_id AND sender_id = auth.uid();

  UPDATE public.bil_messages
  SET deleted_by_recipient_at = pg_catalog.now()
  WHERE id = p_message_id AND recipient_id = auth.uid();
END
$function$;
