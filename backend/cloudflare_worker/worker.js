// Cloudflare Worker: worker.js
// Handles R2 presigned URL generation and JWT verification with Firebase Auth.

let cachedJWKs = null;
let jwkCacheExpiry = 0;

// Fetch and cache Google public keys (JWKs) for Firebase ID tokens
async function getGoogleJWKs() {
  const now = Date.now();
  if (cachedJWKs && now < jwkCacheExpiry) {
    return cachedJWKs;
  }
  const res = await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
  if (!res.ok) {
    throw new Error('Failed to fetch Google JWKs for Firebase Auth');
  }
  const data = await res.json();
  cachedJWKs = data.keys;
  // Cache keys for 1 hour
  jwkCacheExpiry = now + 3600 * 1000;
  return cachedJWKs;
}

// Base64URL decoder
function base64UrlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) {
    str += '=';
  }
  return atob(str);
}

// Helper to verify Firebase ID Token (JWT)
async function verifyFirebaseToken(authHeader, firebaseProjectId, bypassAuth = false) {
  if (bypassAuth) {
    return { uid: 'dev-bypass-user' };
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error('Missing or invalid Authorization header');
  }

  const token = authHeader.substring(7);
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format');
  }

  // Parse header and payload
  const header = JSON.parse(base64UrlDecode(parts[0]));
  const payload = JSON.parse(base64UrlDecode(parts[1]));

  // 1. Verify algorithm (RS256)
  if (header.alg !== 'RS256') {
    throw new Error('Invalid signature algorithm, must be RS256');
  }

  // 2. Verify expiration
  const nowInSeconds = Math.floor(Date.now() / 1000);
  if (payload.exp < nowInSeconds) {
    throw new Error('Token has expired');
  }

  // 3. Verify issuer
  const expectedIssuer = `https://securetoken.google.com/${firebaseProjectId}`;
  if (payload.iss !== expectedIssuer) {
    throw new Error(`Invalid issuer: ${payload.iss}`);
  }

  // 4. Verify audience
  if (payload.aud !== firebaseProjectId) {
    throw new Error(`Invalid audience: ${payload.aud}`);
  }

  // 5. Verify signature using public key matching `kid`
  const kid = header.kid;
  if (!kid) {
    throw new Error('Missing kid in token header');
  }

  const keys = await getGoogleJWKs();
  const jwk = keys.find(k => k.kid === kid);
  if (!jwk) {
    throw new Error(`Matching public key (kid: ${kid}) not found`);
  }

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  );

  const encoder = new TextEncoder();
  const dataBytes = encoder.encode(parts[0] + '.' + parts[1]);
  
  const rawSig = base64UrlDecode(parts[2]);
  const sigBytes = new Uint8Array(rawSig.length);
  for (let i = 0; i < rawSig.length; i++) {
    sigBytes[i] = rawSig.charCodeAt(i);
  }

  const isValid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    sigBytes,
    dataBytes
  );

  if (!isValid) {
    throw new Error('Invalid JWT signature');
  }

  return payload;
}

// HMAC-SHA256 Utility
async function hmacSha256(key, data) {
  let cryptoKey;
  if (typeof key === 'string') {
    const encoder = new TextEncoder();
    cryptoKey = await crypto.subtle.importKey(
      'raw',
      encoder.encode(key),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
  } else {
    cryptoKey = await crypto.subtle.importKey(
      'raw',
      key,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
  }
  
  const encoder = new TextEncoder();
  const dataBytes = typeof data === 'string' ? encoder.encode(data) : data;
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, dataBytes);
  return new Uint8Array(signature);
}

// SHA256 Hash Utility
async function sha256(data) {
  const encoder = new TextEncoder();
  const dataBytes = typeof data === 'string' ? encoder.encode(data) : data;
  const hash = await crypto.subtle.digest('SHA-256', dataBytes);
  return new Uint8Array(hash);
}

// Convert byte buffer to hex string
function bufToHex(buf) {
  return Array.from(buf)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

// Generate S3 Signature v4 Presigned URL
async function getPresignedUrl({
  method,
  r2Endpoint,
  bucket,
  objectKey,
  accessKeyId,
  secretAccessKey,
  region = 'auto',
  expiresIn = 900
}) {
  const parsedEndpoint = new URL(r2Endpoint);
  const host = parsedEndpoint.host;
  
  // Note: Standard S3 path-style URL structure: endpoint + /bucket/objectKey
  const canonicalUri = `/${bucket}/${encodeURIComponent(objectKey)}`;
  
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]/g, '').split('.')[0] + 'Z';
  const dateStamp = amzDate.substring(0, 8);
  
  const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
  
  const queryParams = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': `${accessKeyId}/${credentialScope}`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': expiresIn.toString(),
    'X-Amz-SignedHeaders': 'host',
  };
  
  // Sort query parameters alphabetically
  const sortedKeys = Object.keys(queryParams).sort();
  const canonicalQueryString = sortedKeys
    .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(queryParams[key])}`)
    .join('&');
    
  const canonicalHeaders = `host:${host}\n`;
  const signedHeaders = 'host';
  const payloadHash = 'UNSIGNED-PAYLOAD';
  
  const canonicalRequest = [
    method.toUpperCase(),
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join('\n');
  
  const canonicalRequestHash = bufToHex(await sha256(canonicalRequest));
  
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    canonicalRequestHash
  ].join('\n');
  
  // Signature calculation keys
  const kDate = await hmacSha256(`AWS4${secretAccessKey}`, dateStamp);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, 's3');
  const kSigning = await hmacSha256(kService, 'aws4_request');
  const signature = bufToHex(await hmacSha256(kSigning, stringToSign));
  
  // Final Presigned URL
  return `${r2Endpoint}/${bucket}/${encodeURIComponent(objectKey)}?${canonicalQueryString}&X-Amz-Signature=${signature}`;
}

// Perform S3 Signature v4 direct DELETE operation
async function deleteObject({
  r2Endpoint,
  bucket,
  objectKey,
  accessKeyId,
  secretAccessKey,
  region = 'auto'
}) {
  const parsedEndpoint = new URL(r2Endpoint);
  const host = parsedEndpoint.host;
  const canonicalUri = `/${bucket}/${encodeURIComponent(objectKey)}`;
  
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]/g, '').split('.')[0] + 'Z';
  const dateStamp = amzDate.substring(0, 8);
  
  const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
  
  const canonicalHeaders = `host:${host}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = 'host;x-amz-date';
  const payloadHash = bufToHex(await sha256('')); // Empty payload
  
  const canonicalRequest = [
    'DELETE',
    canonicalUri,
    '', // Empty query string
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join('\n');
  
  const canonicalRequestHash = bufToHex(await sha256(canonicalRequest));
  
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    canonicalRequestHash
  ].join('\n');
  
  const kDate = await hmacSha256(`AWS4${secretAccessKey}`, dateStamp);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, 's3');
  const kSigning = await hmacSha256(kService, 'aws4_request');
  const signature = bufToHex(await hmacSha256(kSigning, stringToSign));
  
  const url = `${r2Endpoint}/${bucket}/${encodeURIComponent(objectKey)}`;
  const response = await fetch(url, {
    method: 'DELETE',
    headers: {
      'Host': host,
      'X-Amz-Date': amzDate,
      'X-Amz-Content-Sha256': payloadHash,
      'Authorization': `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`
    }
  });
  
  if (!response.ok && response.status !== 204) {
    const errorText = await response.text();
    throw new Error(`Failed to delete object from R2: ${response.status} ${errorText}`);
  }
}

// Core Worker Fetch Handler
export default {
  async fetch(request, env, ctx) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      const url = new URL(request.url);
      const authHeader = request.headers.get('Authorization');
      
      // Load environment variables (secrets/configs)
      const firebaseProjectId = env.FIREBASE_PROJECT_ID;
      const r2AccessKeyId = env.R2_ACCESS_KEY_ID;
      const r2SecretAccessKey = env.R2_SECRET_ACCESS_KEY;
      const r2Endpoint = env.R2_ENDPOINT;
      const r2BucketName = env.R2_BUCKET_NAME;
      const bypassAuth = env.BYPASS_AUTH === 'true';

      // Basic Config Check
      if (!r2AccessKeyId || !r2SecretAccessKey || !r2Endpoint || !r2BucketName) {
        return new Response(
          JSON.stringify({ error: 'Worker configuration error: Missing R2 credentials or parameters' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (!firebaseProjectId && !bypassAuth) {
        return new Response(
          JSON.stringify({ error: 'Worker configuration error: Missing Firebase Project ID' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Verify Firebase Auth JWT token
      let userPayload;
      try {
        userPayload = await verifyFirebaseToken(authHeader, firebaseProjectId, bypassAuth);
      } catch (authErr) {
        console.error('JWT authentication failed:', authErr.message);
        return new Response(
          JSON.stringify({ error: `Unauthorized: ${authErr.message}` }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const uid = userPayload.sub || userPayload.uid;
      console.log(`Authenticated user: ${uid} for path: ${url.pathname}`);

      // Route: GET /presigned-put?key={key}
      if (url.pathname === '/presigned-put' && request.method === 'GET') {
        const objectKey = url.searchParams.get('key');
        if (!objectKey) {
          return new Response(
            JSON.stringify({ error: "Missing required query parameter: 'key'" }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const presignedUrl = await getPresignedUrl({
          method: 'PUT',
          r2Endpoint,
          bucket: r2BucketName,
          objectKey,
          accessKeyId: r2AccessKeyId,
          secretAccessKey: r2SecretAccessKey
        });

        return new Response(
          JSON.stringify({ url: presignedUrl }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Route: GET /presigned-get?key={key}
      if (url.pathname === '/presigned-get' && request.method === 'GET') {
        const objectKey = url.searchParams.get('key');
        if (!objectKey) {
          return new Response(
            JSON.stringify({ error: "Missing required query parameter: 'key'" }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const presignedUrl = await getPresignedUrl({
          method: 'GET',
          r2Endpoint,
          bucket: r2BucketName,
          objectKey,
          accessKeyId: r2AccessKeyId,
          secretAccessKey: r2SecretAccessKey
        });

        return new Response(
          JSON.stringify({ url: presignedUrl }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Route: POST /delete (with JSON body {"key": "..."})
      if (url.pathname === '/delete' && request.method === 'POST') {
        let body;
        try {
          body = await request.json();
        } catch (_) {
          return new Response(
            JSON.stringify({ error: 'Invalid JSON request body' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const objectKey = body.key;
        if (!objectKey) {
          return new Response(
            JSON.stringify({ error: "Missing required parameter 'key' in JSON body" }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Perform audit logging for deletion
        console.warn(`Audit Log: User ${uid} requested deletion of object: ${objectKey}`);

        if (env.BUCKET) {
          // If native R2 bucket binding is configured
          await env.BUCKET.delete(objectKey);
        } else {
          // Fall back to direct AWS SigV4 signed HTTP request
          await deleteObject({
            r2Endpoint,
            bucket: r2BucketName,
            objectKey,
            accessKeyId: r2AccessKeyId,
            secretAccessKey: r2SecretAccessKey
          });
        }

        return new Response(
          JSON.stringify({ success: true, message: `Object '${objectKey}' successfully deleted` }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Route Not Found
      return new Response(
        JSON.stringify({ error: 'Not Found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );

    } catch (err) {
      console.error('Worker internal crash:', err.stack);
      return new Response(
        JSON.stringify({ error: 'Internal Server Error', details: err.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  }
};
