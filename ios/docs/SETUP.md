# Prismet — backend setup (one time)

The app **builds and runs without this**, but shows an "Almost there" screen until you
add your Supabase keys. Do these steps to make phone sign-in work on the phone.

## 1. Create a Supabase project
1. Go to https://supabase.com → **New project** (free tier is fine). Pick a name + region.
2. When it's ready: **Project Settings → API**. Copy:
   - **Project URL** (e.g. `https://abcd1234.supabase.co`)
   - **anon public** key (the long `eyJ…` string — NOT the `service_role` key)

## 2. Create the database table
1. Supabase → **SQL Editor → New query**.
2. Paste the contents of [`supabase-setup.sql`](./supabase-setup.sql) and **Run**.
   This makes the `profiles` table and its Row-Level-Security policies.

## 3. Turn on Phone auth (Twilio Verify)
Phone sign-in needs an SMS provider. Twilio Verify is the simplest.
1. Make a Twilio account → **Verify → Services → Create** a Verify service. Note the
   **Service SID**, plus your Twilio **Account SID** and **Auth Token**.
2. Supabase → **Authentication → Providers → Phone** → enable it, choose **Twilio Verify**,
   and paste the Account SID, Auth Token, and Verify Service SID. Save.
   - SMS costs a few ¢ per message — fine for you + friends.

## 4. Add your keys to the app
1. Open `Sources/Backend/Secrets.swift`.
2. Replace the two placeholders with your **Project URL** and **anon public** key.
   (This file is gitignored, so your keys never get committed.)

## 5. Run it
```bash
cd mobile-development/Prismet
./scripts/deploy.sh            # builds + installs + launches on "Poopoohead"
```
Enter your phone number in **E.164** form (e.g. `+15551234567`), get the SMS code, verify,
set a profile — you're in.

## Notes
- **Apple PLA:** if device builds fail with "PLA Update available," the account holder
  (Ben) must re-agree at https://developer.apple.com/account.
- Simulator builds need no signing: `xcodebuild … -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- What's next (sub-project #2): add friends by phone number, then play head-to-head.
