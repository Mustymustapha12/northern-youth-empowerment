# Northern Star Youth Empowerment Portal

A mobile-friendly portal for applicants and programme teams working across the Northern Nigeria Youth Empowerment Initiative pilot. The project covers the public application journey and the proposed internal programme operations platform.

## Current state

The interface includes an applicant landing page, application and status tracking flows, staff overview, participant records, applications review, programs/cohorts, field operations, baseline and follow-up surveys, referrals and partner directory, community outreach, impact stories, finance records, participant messaging, and M&E reports. The four support pathways are Level 0 Recovery & Rehabilitation, Level 1 Hope & Prevention, Level 2 Skills & Direction, and Level 3 Growth & Scale.

When no Supabase project is configured, the portal runs in **Preview mode** with fictional sample records stored in the current browser. Preview mode is for review only; it is not a multi-user database, does not send messages, and must not be used to collect real participant information.

The live-data adapter and database schema are included. A production deployment still requires an NGO-owned Supabase project, configured email authentication, staff-role assignments, retention and backup policies, and the deployment variables below. The six pilot state names are shown as assumptions from the prototype and require confirmation by the NGO.

## Run locally

Requirements: Node.js 20 or newer and npm.

```sh
npm install
cp .env.example .env.local
npm run dev
```

Without Supabase values, the site opens in Preview mode. To connect a non-production Supabase project, set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `.env.local`.

## Configure Supabase

1. Create a Supabase project in an organization controlled by the NGO.
2. Apply `supabase/migrations/202610280001_initial_schema.sql` using the Supabase SQL editor or Supabase CLI.
3. Configure Supabase Auth email sign-in and allowed redirect URLs for local development and the GitHub Pages URL.
4. Add the Supabase project URL and **publishable/anon key** as GitHub Actions repository variables named `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
5. Never put a service-role key in this frontend or in GitHub Pages variables. The publishable key is safe to expose only because database access is governed by the included row-level security policies.
6. Create the initial staff account, verify the profile, and grant its role through a reviewed administrator-only database operation. New accounts default to the `participant` role. Do not grant staff roles by editing user-submitted profile metadata.
7. Verify every role against realistic test accounts and confirm participant isolation before importing any real data.

Roles in the schema: participant, field officer, case worker, supervisor, M&E officer, finance officer, and administrator. Finance rows and restricted case notes have separate access boundaries. Adjust policies only with an access review.

## Deploy to GitHub Pages

The workflow in `.github/workflows/deploy.yml` builds on pushes to `main` and deploys the `dist` directory to GitHub Pages. In the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. The Vite base path is configured for `Mustymustapha12/northern-youth-empowerment`.

The site can be published without Supabase configuration, but that deploy will remain Preview mode. Configure the two repository variables before a live-data deployment. GitHub Pages hosts only the static frontend; Supabase provides authentication and data storage. Do not upload actual participant records to GitHub.

## Scope and rollout

The supplied requirements propose a phased rollout:

- **Phase 1 — Core platform:** registration, assessment, participant case management, programs, field operations, supervisor approvals, dashboard and KPI/M&E reporting.
- **Phase 2 — Expansion:** finance/Open Finance, participant messaging, partner and referral management, advanced analytics and impact stories.
- **Phase 3 — Advanced ecosystem:** PWA/mobile app, WhatsApp, AI-supported assessment/analytics, advanced mapping, donor portal and public transparency dashboard.

The current schema supports core records and the planned expansion entities. Payment/Open Finance integrations, SMS/email delivery, WhatsApp, AI features, recurring report delivery, full offline synchronization, document upload/evidence storage, a donor portal and published public impact APIs require separately configured services and reviewed workflows. The screen designs indicate those future workflows but do not claim those integrations are active.

Before production use, the NGO must approve consent language, Hausa translations, safeguarding and referral procedures, sensitive-data retention, backup/recovery, incident response, field-device protections, application eligibility, pilot locations, and operational responsibility for weekly reporting. Use a qualified Hausa reviewer for the translated interface before launch.
