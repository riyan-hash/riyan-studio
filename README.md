# Riyan Studio — Video Editing Portfolio

A premium, cinematic portfolio site that you can manage **without editing code**.
Free stack: **Supabase Free** (login, database, video storage) + **free static hosting**.

## Files

| File | What it is |
|---|---|
| `index.html` | The whole website (public site + admin page). One file. |
| `supabase-setup.sql` | One-time database + storage + security setup. |
| `README.md` | This guide. |

Public site: `https://YOUR-SITE/`  ·  Admin page: `https://YOUR-SITE/#/admin`
(The `#` is needed because the site is one static file. Bookmark the admin link.)

**Demo vs. live:** until you fill in Supabase details, the site shows a yellow **DEMO PREVIEW** bar and labelled "Sample" cards. Once configured, the bar and samples disappear and only your real projects show.

---

## 1. Configure (one block, top of the `<script>` in `index.html`)

Open `index.html` in any text editor (Notepad is fine) and find `const CONFIG = {`.

| Setting | What to enter | Safe in public code? |
|---|---|---|
| `SUPABASE_URL` | Project URL, e.g. `https://abcd1234.supabase.co` | Yes |
| `SUPABASE_ANON_KEY` | The **anon / publishable** key | Yes (protected by the security rules in the SQL) |
| `PHONE` | Country code + number, digits only: `919876543210` | Yes (it's shown to visitors) |
| `EMAIL` | Your real email | Yes |
| `TELEGRAM` | Username without `@` | Yes |
| `MAX_PROJECTS` | Project slots (default 20) | Yes |
| `MAX_VIDEO_MB` | Upload limit (default 45) | Yes |
| `SERVICES`, `ABOUT_TEXT`, `ABOUT_POINTS`, `ABOUT_IMAGE`, `CATEGORIES` | Your own wording | Yes |

**Never put these in the file:** the Supabase **service_role** (secret) key, your Supabase account password, or your admin password.

Contact buttons only appear for values you have replaced. A placeholder like `91XXXXXXXXXX` or `YOUR_EMAIL@example.com` is never shown as a working button.

**Raise the 20-project limit later:** change `MAX_PROJECTS` in `CONFIG`. It is an interface limit only. Your real limit is your Supabase storage (below).

---

## 2. Create the free backend (Supabase)

1. Go to <https://supabase.com> → **Start your project** → sign up (free).
2. **New project** → name it `riyan-studio`, set a database password (save it somewhere), pick the region closest to you (e.g. Mumbai), plan **Free**.
3. Wait ~2 minutes until it finishes setting up.
4. **Project Settings → API** (or **Connect**): copy the **Project URL** and the **anon / publishable key** into `CONFIG`.
5. **SQL Editor → New query** → paste the whole of `supabase-setup.sql` → **Run**. It should finish with "Success". It creates the tables, security rules and the two storage buckets (`portfolio-videos`, `portfolio-thumbnails`) for you. Safe to run again.

## 3. Create and authorise your admin account

Security rule: logging in is not enough. Only people listed in the `admins` table can change anything.

1. Supabase → **Authentication → Users → Add user → Create new user**. Enter your email + a strong password, tick **Auto Confirm User**.
2. *(Recommended)* **Authentication → Sign In / Providers** → turn **off** "Allow new users to sign up". (Even if left on, strangers still can't change anything, but this keeps things tidy.)
3. **SQL Editor** → run this with **your** email:

```sql
insert into public.admins (user_id, email)
select id, email from auth.users where email = 'YOUR_EMAIL@example.com';
```

4. Open `your-site/#/admin` and log in. If you see "Signed in, but not authorised", the page shows the exact SQL to run for your account.

---

## 4. Deploy for free (no domain needed)

**Easiest: Netlify Drop**
1. Put `index.html` alone in a folder (add `og-image.jpg` too if you made one).
2. Go to <https://app.netlify.com/drop> → drag the **folder** onto the page. Create a free account if asked so the site stays online.
3. You get an address like `https://something.netlify.app`. Open it.

**Alternatives (also free):** Cloudflare Pages (Direct Upload) or GitHub Pages. Free-plan terms can change; check the provider's page.

After deploying:
1. Open the site on your phone **and** another browser (not logged in) to see what visitors see.
2. Log in at `/#/admin`, add a project, then refresh the public page in the other browser. It should appear.

### Link preview (WhatsApp / Instagram / X)
Before publishing, edit these in the `<head>` of `index.html`:
- Replace every `YOUR-SITE-URL` with your real address, e.g. `something.netlify.app` (canonical, `og:url`, `og:image`, `twitter:image`).
- Make a **1200×630** image named `og-image.jpg` and upload it next to `index.html`.
- Optionally change the page title and description.
Social apps cache previews; if you change them later, re-scrape using the platform's debugger.

---

## 5. Managing videos (simple language)

Open `your-site/#/admin`, log in.

**Upload your first video**
1. **+ Add project** → type a **Title**, pick a **Category**.
2. Video: choose **Upload a file** → select an **MP4 or WebM** (max **45 MB**).
3. **Thumbnail:** choose *Upload an image* (JPG/PNG/WebP). No thumbnail = a tidy placeholder.
4. Tick **Featured** if you want it in the big hero card.
5. **Save & publish**. Wait for the green message. It only appears after the upload and database save both succeed.

**Add a YouTube / Shorts / Vimeo / direct .mp4 link** — choose *Use a video link* and paste it. It is validated first. For YouTube, tap **Use YouTube thumbnail**. Links from Google Drive, Instagram etc. cannot be embedded, so use upload or YouTube instead.

**Replace a video** — **Edit** → *Upload a file* (or a link) → **Save changes**. The old video keeps working until the new one is saved; the old file is deleted only afterwards. If the replacement fails, nothing changes.

**Delete** — **Delete** → read the warning → confirm. It removes the card, its database record and that project's own uploaded files. YouTube/Vimeo originals are never touched.

**Reorder** — use the **↑ ↓** buttons. Order is saved in one step.

**Draft** — untick **Published** to hide a project from visitors while you prepare it.

### Storage and quota (be realistic)
- Supabase Free currently gives roughly **1 GB storage**, **5 GB monthly bandwidth**, and **50 MB max per file**. Check <https://supabase.com/pricing> for current numbers.
- 20 videos × 45 MB ≈ 900 MB, so you will be close to the storage limit. Every time someone plays a full video it uses bandwidth.
- **Best practice:** upload short Reels/Shorts directly; put long videos on YouTube/Vimeo and add them as links. That saves your quota.
- Compress videos (1080p, H.264 MP4) before uploading.
- Free Supabase projects can be **paused after a period of inactivity**. Log in occasionally, and un-pause from the Supabase dashboard if needed. If the backend is down or over quota, visitors see a clear "couldn't load" message with a retry button.
- The 45 MB limit can only go up if your Supabase plan allows it: change `MAX_VIDEO_MB` in `CONFIG` **and** `47185920` for the video bucket in the SQL.

### Not losing work
- Keep your **original video files** on your phone/PC. The website is a showcase, not a backup.
- Use **Draft** instead of deleting if you are unsure.
- Saving shows success only after the server confirms.

---

## 6. Security summary

- Row Level Security is **on** for both tables. Visitors can read only **published** projects.
- Only users in `admins` can insert / update / delete projects or upload / replace / delete files. No one can add themselves to `admins` from the website.
- The page only ever uses the public anon/publishable key.
- The admin area is not linked from the public site, but security does **not** rely on that. The rules above do.

---

## 7. Testing checklist — what was and wasn't tested

Tested by me in an automated headless Chromium (mobile 390 px and desktop 1366 px), using the file opened locally and, for the "live" cases, a **mocked** Supabase response (not your real project):

- [x] JavaScript syntax and no console/page errors on load
- [x] No horizontal scroll on mobile and desktop (demo mode, and mocked live mode on mobile)
- [x] Demo mode shows banner + labelled samples; admin shows "Backend not configured"
- [x] Category filtering; empty-state and error-state (mocked) render
- [x] Mobile menu opens/closes and navigates; viewer opens, Escape closes, background scroll locks/unlocks
- [x] Contact links built correctly (WhatsApp encoded text, Telegram, mailto, tel); placeholders hidden
- [x] YouTube/Vimeo links become correct embeds; a failing video shows an error box with "Open source video"

**Not tested (needs your real Supabase project, please check yourself):**

- [ ] Admin login, "not authorised" screen, session expiry
- [ ] Real upload with progress, size/type validation messages, retry after network loss
- [ ] Create / edit / replace / delete / reorder against the real database
- [ ] Storage cleanup after replace/delete (check the buckets in Supabase)
- [ ] Unauthorised write attempts (log in as a normal non-admin user: every change should be refused)
- [ ] Public visibility from a different device
- [ ] Real playback on iPhone/Android, and the video bucket's 45 MB limit
- [ ] Running `supabase-setup.sql` (written carefully, but not run by me)

Suggested first test: add a draft project, confirm visitors can't see it, publish it, confirm they can, delete it, confirm its files are gone from **Storage → portfolio-videos**.

---

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| Yellow DEMO bar still shows | `SUPABASE_URL` / `SUPABASE_ANON_KEY` still empty or have a typo. |
| "Couldn't load the portfolio" | Did you run the SQL? Is the project paused? Check the browser console (F12). |
| Can log in but "not authorised" | Run the `insert into public.admins …` statement from step 3. |
| Upload says not allowed | Admin row missing, or the SQL was not fully run (storage policies). |
| YouTube link rejected | Use a single-video link (not a playlist). |
| A contact button is missing | Its value in `CONFIG` is still a placeholder. |
| Video won't play on some phones | Re-export as H.264 MP4 (AAC audio). |
