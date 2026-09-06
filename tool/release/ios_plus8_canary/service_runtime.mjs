import {
  mask,
  params,
  requiredEnv,
  supabaseConfig,
  uuid,
} from './runtime.mjs';

function serviceRole() {
  const value = requiredEnv('BIL_SUPABASE_SERVICE_ROLE_KEY');
  mask(value);
  return value;
}

export async function serviceRequest({
  method = 'GET',
  route,
  body,
  allowed = [200],
  prefer,
}) {
  const secret = serviceRole();
  const headers = {
    apikey: secret,
    Authorization: `Bearer ${secret}`,
    Accept: 'application/json',
  };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (prefer) headers.Prefer = prefer;
  const response = await fetch(`${supabaseConfig.url}${route}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'error',
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  if (!allowed.includes(response.status)) {
    const code = data && typeof data === 'object'
      ? String(data.code ?? data.error_code ?? data.error ?? 'unknown')
      : 'non_json_response';
    throw new Error(
      `service_request_failed:${method}:${route.split('?')[0]}:${response.status}:${code}`,
    );
  }
  return { status: response.status, data, headers: response.headers };
}

export async function serviceSelect(table, values) {
  const result = await serviceRequest({
    route: `/rest/v1/${table}?${params(values)}`,
  });
  if (!Array.isArray(result.data)) {
    throw new Error(`invalid_service_select_result:${table}`);
  }
  return result.data;
}

export async function serviceRpc(name, body = {}) {
  return (await serviceRequest({
    method: 'POST',
    route: `/rest/v1/rpc/${name}`,
    body,
  })).data;
}

export async function adminUsersByEmail(email) {
  const normalized = String(email).trim().toLowerCase();
  const matches = [];
  let reachedEnd = false;
  for (let page = 1; page <= 20; page += 1) {
    const result = await serviceRequest({
      route: `/auth/v1/admin/users?${params({
        page: String(page),
        per_page: '1000',
      })}`,
    });
    const users = Array.isArray(result.data?.users) ? result.data.users : [];
    matches.push(...users.filter(
      (user) =>
        String(user?.email ?? '').trim().toLowerCase() === normalized,
    ));
    if (users.length < 1000) {
      reachedEnd = true;
      break;
    }
  }
  if (!reachedEnd) throw new Error('admin_user_scan_page_cap_reached');
  return matches;
}

export async function deleteAdminUser(userId) {
  if (!uuid(userId)) throw new Error('invalid_disposable_user_id');
  await serviceRequest({
    method: 'DELETE',
    route: `/auth/v1/admin/users/${userId}`,
    allowed: [200, 204],
  });
}
