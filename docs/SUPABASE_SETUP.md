# Supabase configuration

See [Vercel deployment](../DEPLOYMENT.md) for environment variables, schema installation and auth email settings.

## Trusted Roles & Private Documents (Round 3 Storage Update)

- Public signup creates confirmed **Creator** accounts. Never use client-editable `user_metadata` for roles.
- Assign Reviewer/Admin only via trusted `app_metadata` (`{"brandguard_role": "reviewer"}`) or `python manage.py create-user`.
- **`brandguard-files` Storage bucket (5 MB limit):**
  - Initial `v2` setup allowed `text/plain`, `text/markdown`, and `application/pdf`.
  - **Round 3 adds image banner uploads (`PNG`, `JPG`, `JPEG`, `WEBP`).** Before testing image uploads against Supabase Storage, run this in the Supabase SQL Editor so the bucket accepts images:
    ```sql
    UPDATE storage.buckets
    SET allowed_mime_types = ARRAY[
      'text/plain', 'text/markdown', 'application/pdf',
      'image/png', 'image/jpeg', 'image/webp'
    ]
    WHERE id = 'brandguard-files';
    ```
- **Evaluation expiry note:** Earlier temporary evaluation users had `brandguard_access_until` expiring **2026-11-16T20:00:31Z** (**17 November 2026, 01:30:31 IST**). That window has now passed; create fresh user/reviewer accounts for new evaluations. Ordinary accounts without `brandguard_access_until` never expire.

## Operations & AI

- Retain PostgreSQL (`pg_dump`) + Storage object backups alongside `manage.py backup`.
- AI setup is documented in [AI_SETUP.md](AI_SETUP.md).
