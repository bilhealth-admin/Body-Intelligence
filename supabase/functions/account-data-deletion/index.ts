import { handleAccountDeletion } from "../_shared/account_deletion_worker.ts";

Deno.serve(handleAccountDeletion);
