# 8EER: UnBEERable — Alliance Command Center

Static alliance dashboard (plain HTML/CSS/JS, no build step) hosted on **Vercel**:
https://unbeerable-alliance-command-center.vercel.app/

## Deployment
Vercel deploys automatically from `main`. Framework preset "Other", no build command, output directory = repo root.
`vercel.json` holds the security headers, Content-Security-Policy and the single-page rewrite to `index.html`.
When you change `app.js`/`styles.css`, bump `CACHE` in `sw.js` so installed copies refresh.

## Backend (Supabase)
- The browser only uses the publishable key. Never commit a secret/service-role key.
- Visitors get an anonymous session: they can see the Alliance Dashboard (read-only).
- Editors (R4/R5) log in with email + password and get all tabs and write access.
  Access rules live in the database (`supabase-editor-logins.sql`, row level security + `is_editor()`).
- Add an editor: Supabase → Authentication → Users → Add user (Auto Confirm), then
  `insert into public.site_editors (user_id, label) select id, email from auth.users where email = '…';`
- The game sync (lw_sync) writes with the database owner connection and is not affected by these rules.

## Libraries
SheetJS (Excel import) and tesseract.js (picture reading) are loaded only when an import/scan is started,
pinned to exact versions with integrity hashes (see `LIBS` at the top of `app.js`).
