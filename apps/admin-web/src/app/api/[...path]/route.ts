import { NextRequest, NextResponse } from 'next/server';

const serviceByPath: Array<[prefix: string, envName: string, fallback: string]> = [
  ['/api/v1/auth', 'IDENTITY_URL', 'http://localhost:8081'],
  ['/api/v1/campuses', 'CAMPUS_URL', 'http://localhost:8083'],
  ['/api/v1/platform/vendors', 'CATALOG_URL', 'http://localhost:8084'],
  ['/api/v1/platform/delivery-partners', 'DELIVERY_URL', 'http://localhost:8087'],
  ['/api/v1/platform/verifications', 'CUSTOMER_URL', 'http://localhost:8082'],
  ['/api/v1/platform/audit-log', 'OPERATIONS_URL', 'http://localhost:8089'],
  ['/api/v1/platform/support', 'OPERATIONS_URL', 'http://localhost:8089'],
  ['/api/v1/platform/financial', 'FINANCIAL_URL', 'http://localhost:8090'],
];

function targetFor(path: string): string | null {
  const match = serviceByPath.find(([prefix]) => path === prefix || path.startsWith(`${prefix}/`));
  if (!match) return null;
  const [, envName, fallback] = match;
  return process.env[`NEXT_PUBLIC_${envName}`] ?? fallback;
}

async function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const baseUrl = targetFor(path);
  if (!baseUrl) return NextResponse.json({ error: 'No service route configured' }, { status: 404 });

  const target = new URL(path, `${baseUrl.replace(/\/$/, '')}/`);
  target.search = request.nextUrl.search;

  const headers = new Headers(request.headers);
  headers.delete('host');
  headers.delete('content-length');

  const body = ['GET', 'HEAD'].includes(request.method) ? undefined : await request.arrayBuffer();
  const response = await fetch(target, {
    method: request.method,
    headers,
    body,
    redirect: 'manual',
  });

  const responseHeaders = new Headers(response.headers);
  responseHeaders.delete('content-encoding');
  responseHeaders.delete('content-length');
  return new NextResponse(response.body, {
    status: response.status,
    headers: responseHeaders,
  });
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
export const HEAD = proxy;
