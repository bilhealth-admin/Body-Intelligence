function hostIsAllowed(hostname, allowedHosts) {
  const host = hostname.toLowerCase();
  return allowedHosts.some((allowedHost) => {
    const suffix = allowedHost.toLowerCase();
    return host === suffix || host.endsWith(`.${suffix}`);
  });
}

export function resolveSameOriginHttpsUrl(resource, baseUrl, pathPrefixes = []) {
  if (typeof resource !== 'string' || resource.length === 0) {
    throw new Error('TRUSTED_URL_RESOURCE_REQUIRED');
  }
  const base = new URL(baseUrl);
  if (base.protocol !== 'https:' || base.username || base.password) {
    throw new Error('TRUSTED_URL_BASE_INVALID');
  }

  let target;
  try {
    if (/^https?:\/\//i.test(resource) || resource.startsWith('//')) {
      target = new URL(resource, base.origin);
    } else {
      const basePath = base.pathname.replace(/\/+$/, '');
      const relativePath = resource.replace(/^\/+/, '');
      target = new URL(`${basePath}/${relativePath}`, base.origin);
    }
  } catch {
    throw new Error('TRUSTED_URL_RESOURCE_INVALID');
  }

  if (
    target.protocol !== 'https:' ||
    target.origin !== base.origin ||
    target.username ||
    target.password ||
    target.hash ||
    (pathPrefixes.length > 0 &&
      !pathPrefixes.some((prefix) => target.pathname.startsWith(prefix)))
  ) {
    throw new Error('TRUSTED_URL_ORIGIN_OR_PATH_REJECTED');
  }
  return target.href;
}

export function validateTrustedHttpsUrl(
  value,
  allowedHosts,
  { allowSubdomains = true } = {},
) {
  let target;
  try {
    target = new URL(value);
  } catch {
    throw new Error('TRUSTED_ASSET_URL_INVALID');
  }
  if (
    target.protocol !== 'https:' ||
    target.username ||
    target.password ||
    target.hash ||
    !(allowSubdomains
      ? hostIsAllowed(target.hostname, allowedHosts)
      : allowedHosts.some((hostname) =>
        target.hostname.toLowerCase() === hostname.toLowerCase()
      ))
  ) {
    throw new Error('TRUSTED_ASSET_URL_REJECTED');
  }
  return target.href;
}

export function validateAppleUploadOperation(operation) {
  if (operation?.method !== undefined && operation.method !== 'PUT') {
    throw new Error('APPLE_ASSET_UPLOAD_METHOD_REJECTED');
  }
  return validateTrustedHttpsUrl(operation?.url, ['blobstore.apple.com']);
}
