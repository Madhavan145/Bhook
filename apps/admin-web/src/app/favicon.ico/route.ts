const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#A60F2D"/><path d="M18 14h18.5c7.5 0 12.5 4.1 12.5 10.2 0 3.5-1.9 6.5-5 8.1 4.2 1.4 6.8 4.7 6.8 9.1C50.8 48.1 45.6 52 37.3 52H18V14Zm10 8v7.2h7.5c2.8 0 4.3-1.3 4.3-3.6S38.3 22 35.5 22H28Zm0 15.2V44h8.6c3 0 4.7-1.4 4.7-4.4 0-2.9-1.7-4.4-4.7-4.4H28Z" fill="#FFF9EC"/></svg>`;

export function GET() {
  return new Response(favicon, {
    headers: { 'Content-Type': 'image/svg+xml', 'Cache-Control': 'public, max-age=86400' },
  });
}