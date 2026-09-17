import './globals.css';
import { Manrope } from 'next/font/google';

import { Providers } from './providers';

const manrope = Manrope({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700', '800'],
  display: 'swap',
  variable: '--font-manrope',
});

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={manrope.variable}>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

export const metadata = {
  title: 'Bhook Admin',
  description: 'Bhook platform operations console',
  icons: { icon: '/favicon.svg' },
};
