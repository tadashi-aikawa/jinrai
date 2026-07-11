// @ts-check
import { defineConfig } from "astro/config";

// docs を GitHub Pages のルートから /jinrai/docs/ へ移動したため、
// 旧 docs URL へのアクセスを新 URL へリダイレクトする
const docsPages = [
  "setup",
  "configuration",
  "window-hints",
  "application-hints",
  "area-hints",
  "window-mover",
  "window-mover-areas",
  "window-layouts",
  "jinrai-mode",
  "focus-border",
  "focus-back",
  "display-aliases",
  "profiles",
  "macos-native-tabs",
];

export default defineConfig({
  site: "https://tadashi-aikawa.github.io",
  base: "/jinrai",
  redirects: Object.fromEntries(
    docsPages.map((page) => [`/${page}`, `/jinrai/docs/${page}/`]),
  ),
  vite: {
    server: {
      // dev サーバーで /jinrai/docs/ を zensical serve (localhost:8000) へ転送する。
      // 本番は GitHub Pages のワークフローが docs を /docs/ にマージするため不要
      // dev サーバーは base (/jinrai) を剥がしたパスでルーティングするためキーは /docs。
      // zensical serve は site_url に従い /jinrai/docs/ 配下で配信するので prefix を付け直す
      proxy: {
        "/docs": {
          target: "http://localhost:8000",
          changeOrigin: true,
          rewrite: (path) => `/jinrai${path}`,
        },
      },
    },
  },
});
