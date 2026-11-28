# HustleLink Admin Dashboard

The Phase 1 administration tools are part of the existing Flutter app. They use Firebase Authentication and Cloud Firestore for identity/data, with the existing Supabase push-notification Edge Function as the trusted server boundary for privileged actions.

## Included modules

- **Overview:** live totals for registered users, gigs, open gigs, reports and open reports.
- **User Management:** search the latest 200 user records, inspect profiles, suspend accounts and restore them.
- **Gig Management:** inspect the latest 200 gigs, close open listings, or mark a gig as removed.
- **Reports & Moderation:** review the latest 200 submitted reports and record a status and resolution note.
- **Announcements:** send to all active accounts, users currently in Worker mode, users currently in Poster mode, or one user ID. The function writes in-app notifications and attempts FCM delivery.
- **Audit Logs:** inspect the latest 200 recorded administrative actions.

## Administrator roles

| Role | Permissions |
| --- | --- |
| Super Admin | All Phase 1 modules |
| Admin | All Phase 1 modules except administrator-role provisioning |
| Moderator | Overview, users (read-only), gigs, reports |
| Support | Overview, reports |
| Analyst | Overview, audit logs |

Admin records are provisioned manually in the adminUsers/{firebaseAuthUid} collection from the Firebase Console. Client applications cannot create or modify administrator records.

## Required deployment steps

### 1. Publish Firestore rules

Publish the repository's current firestore.rules in Firebase Console → Firestore Database → Rules.

The rules allow the appropriate admin roles to read reports, users and audit logs. adminAnnouncements history is readable only by Super Admin and Admin. Admin announcement and audit writes remain server-only.

### 2. Redeploy the push-notification Edge Function

Deploy the updated source at:

supabase/functions/push-notification/index.ts

The existing function is also used by normal application push notifications and device-token registration. Keep its Firebase ID-token verification enabled in the source; supabase/config.toml intentionally sets verify_jwt = false because the function validates Firebase tokens itself.

The Supabase Edge Function secrets must include:

- FIREBASE_PROJECT_ID: hustlelink-483a9
- FIREBASE_SERVICE_ACCOUNT_JSON: the complete Firebase service-account JSON, stored only as a Supabase secret.

Do not place the service-account JSON, private key or any Supabase secret key in Flutter, GitHub source, or app build variables.

### 3. Grant the service account permission to suspend/restore Firebase Auth users

The same service account used by the Edge Function needs permission to update Firebase Authentication accounts.

1. In the FIREBASE_SERVICE_ACCOUNT_JSON secret, identify its client_email value. Do not share the JSON or private key.
2. Open Google Cloud Console → IAM & Admin → IAM for project hustlelink-483a9.
3. Grant that service-account principal the **Identity Toolkit Admin** role (roles/identitytoolkit.admin).

This permission is used only by the server function to disable or re-enable a Firebase Authentication account. User suspension also closes that user's currently open gigs. Restoring the account does not automatically reopen old gigs.

If this role is not granted, dashboard reads, report moderation, gig moderation and announcements can still work, but suspend/restore will fail with an Identity Toolkit permission error.

### 4. Confirm the Super Admin account

The initial Super Admin document was created at:

adminUsers/{your Firebase Authentication UID}

It should contain role = super_admin and active = true. Do not create a second record if this one is already present.

## Moderation behavior and safeguards

- Suspending a user disables the Firebase Authentication account and closes their open gigs. It does not delete their profile, reviews, applications or completed-gig history.
- Restoring a user re-enables sign-in. Previously closed gigs stay closed and must be reviewed separately.
- Closing a gig changes its marketplace status to closed. Removing a gig sets moderationStatus = removed; completed/filled lifecycle history is preserved.
- Report status can be under_review, resolved or dismissed. The original report is retained.
- Announcement notifications use type = announcement and appear in the user's notification history. Push delivery is best-effort; the in-app notification record is the durable record.
- Administrative actions are written to adminAuditLogs by the trusted function. Client writes to this collection remain denied.
- User and gig search currently covers the most recent 200 records returned by the dashboard; report and audit views also load a bounded recent window.

## Out of scope

Payment processing/escrow, advanced analytics, dispute case management, suspicious-activity detection and in-app administrator-role provisioning remain deferred. Do not infer or implement an escrow workflow until the client clarifies its requirements.
