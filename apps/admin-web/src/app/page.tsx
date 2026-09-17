'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

import { session } from '@/lib/session';

export default function IndexPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace(session.accessToken() ? '/dashboard' : '/login');
  }, [router]);
  return null;
}
