'use strict';

// Service worker Naatal Agro : met en cache l'interface (fichiers statiques de l'app).
// Il ne met JAMAIS en cache l'API, les médias, ni aucune requête autre que GET.
const VERSION = 'naatal-shell-v2';
const APP_CODE = /^\/(main\.dart\.js|flutter_bootstrap\.js|flutter\.js|version\.json|manifest\.json)$/;
const OFFLINE_URL = '/offline.html';
const PRECACHE = [
  '/', '/index.html', OFFLINE_URL, '/manifest.json', '/flutter_bootstrap.js', '/flutter.js',
  '/main.dart.js', '/favicon.png', '/icons/Icon-192.png', '/icons/Icon-512.png', '/icons/apple-touch-icon.png',
];
const NEVER_CACHE = [/^\/api(\/|$)/, /^\/media(\/|$)/, /^\/admin(\/|$)/];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(VERSION);
      // Un fichier absent ne doit pas faire échouer toute l'installation.
      await Promise.all(PRECACHE.map((url) => cache.add(url).catch(() => {})));
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)));
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (NEVER_CACHE.some((re) => re.test(url.pathname))) return;

  // Pages : réseau d'abord (toujours la dernière version), sinon cache, sinon page « Pas de connexion ».
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(request);
          const cache = await caches.open(VERSION);
          cache.put('/index.html', fresh.clone());
          return fresh;
        } catch (_) {
          const cache = await caches.open(VERSION);
          return (await cache.match('/index.html')) || (await cache.match(OFFLINE_URL)) || Response.error();
        }
      })()
    );
    return;
  }

  // Code de l'application : réseau d'abord. Servir une ancienne copie du code après une mise à jour ferait tourner
  // l'ancienne version (et ses bogues) jusqu'au rechargement suivant.
  if (APP_CODE.test(url.pathname)) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(VERSION);
        try {
          const fresh = await fetch(request);
          if (fresh && fresh.ok) cache.put(request, fresh.clone());
          return fresh;
        } catch (_) {
          return (await cache.match(request)) || Response.error();
        }
      })()
    );
    return;
  }

  // Autres fichiers statiques (images, polices, moteur) : cache d'abord, mis à jour en arrière-plan.
  event.respondWith(
    (async () => {
      const cache = await caches.open(VERSION);
      const cached = await cache.match(request);
      const refresh = fetch(request)
        .then((response) => {
          if (response && response.ok) cache.put(request, response.clone());
          return response;
        })
        .catch(() => null);
      return cached || (await refresh) || Response.error();
    })()
  );
});
