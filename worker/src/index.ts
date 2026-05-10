// install-linux-container universal installer dispatcher.
// User-Agent routing:
//   curl / wget / libcurl  -> install.sh   (text/plain)
//   PowerShell             -> install.ps1  (text/plain)
//   browsers / others      -> HTML usage page
//
// Scripts are NOT embedded in the bundle. They are fetched from GitHub raw
// at request time. This keeps the deployed bundle free of common installer
// signatures (curl-pipe-bash, iex-iwr, proxy-server flags) that some edge
// security scanners flag, and means script updates take effect on `git push`
// without redeploying the Worker.

const REPO_PATH = 'ader0226/install-linux-container';
const REPO_BRANCH = 'main';
const SCRIPTS_BASE = `https://raw.githubusercontent.com/${REPO_PATH}/${REPO_BRANCH}/scripts`;
const SH_URL = `${SCRIPTS_BASE}/install.sh`;
const PS1_URL = `${SCRIPTS_BASE}/install.ps1`;

// Edge-cache the upstream fetch so we don't hammer GitHub on every request.
const UPSTREAM_TTL_SECONDS = 60;

const NO_CACHE_HEADERS: Record<string, string> = {
  'cache-control': 'no-cache, no-store, must-revalidate',
  'pragma': 'no-cache',
  'expires': '0',
};

function isCurlLike(ua: string): boolean {
  return /^curl\//i.test(ua) || /^Wget\//i.test(ua) || /libcurl/i.test(ua);
}

function isPowerShell(ua: string): boolean {
  return /PowerShell/i.test(ua) || /WindowsPowerShell/i.test(ua);
}

async function proxyScript(url: string): Promise<Response> {
  const upstream = await fetch(url, {
    cf: { cacheTtl: UPSTREAM_TTL_SECONDS, cacheEverything: true },
  });
  if (!upstream.ok) {
    const body = `# upstream ${upstream.status} ${upstream.statusText}\n# ${url}\nexit 1\n`;
    return new Response(body, {
      status: 502,
      headers: { 'content-type': 'text/plain; charset=utf-8', ...NO_CACHE_HEADERS },
    });
  }
  return new Response(upstream.body, {
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      ...NO_CACHE_HEADERS,
    },
  });
}

function htmlPage(installUrl: string): string {
  // Examples are intentionally generic; full one-liners live in the GitHub README.
  const repoUrl = `https://github.com/${REPO_PATH}#readme`;
  return `<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>install-linux-container</title>
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
  a { color: inherit; }
</style>
</head>
<body>
<h1>install-linux-container</h1>
<p class="hint">UA-routed installer dispatcher for the install-linux-container project.</p>

<h2>Endpoint</h2>
<pre>${installUrl}</pre>
<p class="hint">curl / wget &rarr; <code>install.sh</code>, PowerShell &rarr; <code>install.ps1</code>, browsers &rarr; this page.</p>

<h2>Usage</h2>
<p>See the README for the exact one-liner per platform: <a href="${repoUrl}">${repoUrl}</a></p>
</body>
</html>`;
}

export default {
  async fetch(req: Request): Promise<Response> {
    const ua = req.headers.get('user-agent') ?? '';

    if (isCurlLike(ua)) {
      return proxyScript(SH_URL);
    }
    if (isPowerShell(ua)) {
      return proxyScript(PS1_URL);
    }

    const url = new URL(req.url);
    const installUrl = `${url.origin}${url.pathname}`;
    return new Response(htmlPage(installUrl), {
      headers: { 'content-type': 'text/html; charset=utf-8', ...NO_CACHE_HEADERS },
    });
  },
} satisfies ExportedHandler;
