import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  if (path === '/admin' || path.startsWith('/admin/')) {
    const destination = request.nextUrl.clone();
    destination.pathname = path === '/admin' ? '/dashboard' : path.slice('/admin'.length);
    return NextResponse.redirect(destination);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/admin', '/admin/:path*'],
};