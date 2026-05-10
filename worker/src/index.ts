// install-linux-container universal installer dispatcher.
// User-Agent routing:
//   curl / wget / libcurl  -> install.sh   (text/plain)
//   PowerShell             -> install.ps1  (text/plain)
//   browsers / others      -> HTML fallback with usage instructions

import shScript from '../../scripts/install.sh';
import ps1Script from '../../scripts/install.ps1';

const NO_CACHE: Record<string, string> = {
  'cache-control': 'no-cache, no-store, must-revalidate',
  'pragma': 'no-cache',
  'expires': '0',
};

const isCurlLike = (ua: string): boolean =>
  /^curl\//i.test(ua) || /^Wget\//i.test(ua) || /libcurl/i.test(ua);

const isPowerShell = (ua: string): boolean =>
  /PowerShell/i.test(ua) || /WindowsPowerShell/i.test(ua);

function htmlPage(installUrl: string): string {
  return `<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>install-linux-container installer</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif;
         max-width: 720px; margin: 3rem auto; padding: 0 1rem; }
  h1 { font-size: 1.6rem; margin-bottom: 0.2rem; }
  h2 { margin-top: 2rem; font-size: 1.1rem; }
  pre { background: #111; color: #eee; padding: 1rem 1.1rem; border-radius: 0.5rem;
        overflow-x: auto; font: 0.92rem/1.5 ui-monospace, "SFMono-Regular", Menlo, monospace; }
  code { font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; }
  .hint { color: #888; font-size: 0.9rem; }
</style>
</head>
<body>
<h1>install-linux-container installer</h1>
<p class="hint">在含有 <code>xxx.ovpn</code> 的目錄下，依作業系統選一個指令貼到終端機。</p>

<h2>macOS / Linux</h2>
<pre>/bin/bash -c "$(curl -fsSL ${installUrl})"</pre>

<h2>Windows (PowerShell)</h2>
<pre>iex "&amp; { $(iwr -useb ${installUrl}) }"</pre>

<p class="hint">需求：Docker Desktop（含 <code>docker compose</code>）+ Chromium 系 browser（Chrome / Edge / Brave）。</p>
</body>
</html>`;
}

export default {
  async fetch(req: Request): Promise<Response> {
    const ua = req.headers.get('user-agent') ?? '';

    if (isCurlLike(ua)) {
      return new Response(shScript, {
        headers: { 'content-type': 'text/plain; charset=utf-8', ...NO_CACHE },
      });
    }
    if (isPowerShell(ua)) {
      return new Response(ps1Script, {
        headers: { 'content-type': 'text/plain; charset=utf-8', ...NO_CACHE },
      });
    }

    const url = new URL(req.url);
    const installUrl = `${url.origin}${url.pathname}`;
    return new Response(htmlPage(installUrl), {
      headers: { 'content-type': 'text/html; charset=utf-8', ...NO_CACHE },
    });
  },
} satisfies ExportedHandler;
