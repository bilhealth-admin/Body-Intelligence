import assert from 'node:assert/strict';

export function storageFixture(suffix) {
  assert.match(suffix, /^[0-9a-f]{32}$/);
  const table = `bil_ci_storage_rt_${suffix}`;
  const bucket = `bil-ci-${suffix}`;
  const selectPolicy = `bil_ci_${suffix}_select`;
  const insertPolicy = `bil_ci_${suffix}_insert`;
  return { table, bucket,
    setup: `BEGIN;
      CREATE TABLE public.${table} (id uuid PRIMARY KEY,
        owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, payload text NOT NULL);
      ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;
      CREATE POLICY ${table}_select ON public.${table} FOR SELECT TO authenticated
        USING (owner_id = auth.uid());
      CREATE POLICY ${table}_insert ON public.${table} FOR INSERT TO authenticated
        WITH CHECK (owner_id = auth.uid());
      GRANT SELECT, INSERT ON public.${table} TO authenticated;
      ALTER PUBLICATION supabase_realtime ADD TABLE public.${table};
      INSERT INTO storage.buckets(id,name,public) VALUES ('${bucket}','${bucket}',false);
      CREATE POLICY ${selectPolicy} ON storage.objects FOR SELECT TO authenticated
        USING (bucket_id='${bucket}' AND (storage.foldername(name))[1]=auth.uid()::text);
      CREATE POLICY ${insertPolicy} ON storage.objects FOR INSERT TO authenticated
        WITH CHECK (bucket_id='${bucket}' AND (storage.foldername(name))[1]=auth.uid()::text);
      COMMIT;`,
    cleanup: `BEGIN;
      DROP POLICY IF EXISTS ${selectPolicy} ON storage.objects;
      DROP POLICY IF EXISTS ${insertPolicy} ON storage.objects;
      DROP TABLE IF EXISTS public.${table} CASCADE;
      COMMIT;`,
  };
}

export async function removeStorageFixture(baseUrl, serviceKey, bucket, fetchImpl = fetch) {
  const url = new URL(baseUrl);
  assert.equal(url.protocol, 'http:');
  assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname));
  assert.match(bucket, /^bil-ci-[0-9a-f]{32}$/);
  assert.ok(serviceKey, 'Cleanup requires the disposable local service role, never a user key');
  // Storage owns object/file lifecycle. Direct SQL DELETE can orphan files and
  // is rejected by current Storage schemas. Only this synthetic bucket is used.
  for (const [route, method] of [
    [`/storage/v1/bucket/${bucket}/empty`, 'POST'],
    [`/storage/v1/bucket/${bucket}`, 'DELETE'],
  ]) {
    const response = await fetchImpl(new URL(route, url), {
      method, redirect: 'error', signal: AbortSignal.timeout(30000),
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`,
        'content-type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert.equal(response.status, 200, `Synthetic Storage cleanup returned HTTP ${response.status}`);
  }
}
