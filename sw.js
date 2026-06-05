const CACHE='blinders-v25-full';
const CORE=['/','/index.html','/member/login.html','/member/register.html','/assets/style.css','/assets/app.js','/manifest.webmanifest','/assets/pwa/icon-192.png','/assets/pwa/icon-512.png'];
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE).catch(()=>null)))});
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return; e.respondWith(fetch(e.request).catch(()=>caches.match(e.request).then(r=>r||caches.match('/index.html'))))});
