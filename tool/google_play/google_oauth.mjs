export const GOOGLE_OAUTH_TOKEN_URI = 'https://oauth2.googleapis.com/token';

export function googleOAuthTokenUri(credentials) {
  const configured = credentials?.token_uri;
  if (configured !== undefined && configured !== GOOGLE_OAUTH_TOKEN_URI) {
    throw new Error('GOOGLE_OAUTH_TOKEN_URI_NOT_ALLOWED');
  }
  return GOOGLE_OAUTH_TOKEN_URI;
}
