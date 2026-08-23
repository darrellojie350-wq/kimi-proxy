/** Kimi Proxy — Capacitor config (JS to avoid a TypeScript dependency in CI). */
const config = {
  appId: 'com.kimiproxy.app',
  appName: 'Kimi Proxy',
  webDir: 'webapp',
  server: { androidScheme: 'https' },
  android: { allowMixedContent: false },
};
module.exports = config;
