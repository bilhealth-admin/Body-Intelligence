-- Prepared patch only. Not applied to Production.
-- CREATE OR REPLACE preserves the existing owner and EXECUTE ACL.
-- Preserve both sender/recipient soft-delete predicates and void signature.
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
