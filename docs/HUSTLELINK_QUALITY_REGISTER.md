# HustleLink — Quality, Fixes & Issue Register

**Project:** HustleLink Flutter gig marketplace  
**Coverage:** Reconstructed from available project conversation context and Git commit history, primarily 18–27 November 2026.  
**Purpose:** Categorize the engineering work already undertaken, preserve lessons, and identify what remains to be verified or implemented.

> **Status note:** “Implemented” means code/configuration was committed. It does not automatically mean the latest change has passed an APK build or on-device verification. Recent performance changes listed in Section 10 are committed but have not yet been built and tested as a grouped release.

---

## 1. Product and requirements management

### Issues and decisions addressed

- Defined the two operating modes: Worker and Poster.
- Clarified that role switching changes the user's experience without creating separate accounts.
- Defined the core areas: Discover/My Gigs, Matches/Applications, Chat and Profile.
- Clarified that Worker swiping is navigation, not an implicit application action; applications require explicit confirmation.
- Separated pending, accepted, rejected, closed and completed states.
- Established that chat becomes available only after a Poster accepts a Worker.
- Defined a separate conversation per gig, even if the same two users work together more than once.
- Defined one reusable 30-second Worker introduction/proof video on the profile, rather than requiring a separate video for every gig.
- Defined manual two-party payment acknowledgement: Poster marks payment as made; Worker confirms receipt. This is not an integrated payment processor.
- Deferred payment processor/escrow implementation until the client explains the required escrow flow.
- Chose to build the Admin Dashboard inside the existing Flutter application, not as a separate web application.
- Defined admin roles: Super Admin, Admin, Moderator, Support and Analyst.

**Reusable lesson:** Write down role-specific workflows and lifecycle states before implementation. Many later bugs come from ambiguous status definitions, implicit actions or unclear ownership.

## 2. Architecture and integration

### Issues and decisions addressed

- Integrated Firebase Core and Firebase Authentication.
- Adopted Cloud Firestore for application data and real-time streams.
- Initially explored Firebase Storage, then moved media storage to Supabase after discovering Firebase Storage required a Blaze billing plan.
- Added Supabase configuration and Firebase-authenticated Supabase Edge Function flows for media/push operations.
- Added profile photo and proof-video storage services using Supabase.
- Added Firebase Cloud Messaging (FCM) and local notification handling, with a Supabase Edge Function handling authenticated push delivery.
- Kept the architecture hybrid: Firebase Auth + Firestore; Supabase Storage + Edge Functions.
- Removed the unused root-level Firebase storage.rules file because Firebase Storage was not used. This did not remove or change Supabase Storage.
- Added app provider wiring for services and repositories.
- Added routing for public profiles, chat conversations, notifications and the admin dashboard.

**Reusable lesson:** Choose services based on cost, operational ownership and actual requirements. Keep a clear map of which backend owns each responsibility. Remove abandoned configuration so future developers do not deploy or maintain the wrong service.

## 3. Functional and business-logic issues

### Gig lifecycle and management

- Added gig creation, editing, closing and deletion.
- Restricted editing to open gigs.
- Prevented closing or deleting gigs in invalid states, especially when an accepted Worker is assigned.
- Kept closed gigs out of active Poster discovery while retaining them in history.
- Added filled/in-progress and completed states.
- Added safe deletion conditions for eligible unassigned or completed-and-paid gigs.
- Archived gig history before deletion so credibility statistics do not disappear.
- Added logic to avoid double-counting a gig while archival and deletion are in progress.
- Preserved compatibility with legacy gig records missing newer fields.

### Applications and matching

- Added Worker application creation and Poster accept/reject actions.
- Prevented duplicate applications with deterministic application IDs and Firestore rules.
- Validated application data against the source gig.
- Made acceptance and related conversation creation atomic.
- Kept rejected application history and allowed the Worker to remove rejected applications.
- Added role-specific application filters.
- Ensured Poster application lists group applications by gig and do not misrepresent gig totals as application totals.
- Ensured the Worker must explicitly apply rather than applying by swiping.
- Added a required profile-video check for gigs that request it.
- Added matching based on canonical Worker skills and gig categories.

### Completion, payment acknowledgement and credibility

- Added mutual completion confirmation by Poster and accepted Worker.
- Added ordered payment acknowledgement: Poster marks paid, then Worker confirms receipt.
- Added role-specific credibility metrics and review averages.
- Added review category scores and validation.
- Prevented duplicate reviews using deterministic review IDs and rules.
- Added repeat-engagement counts.
- Preserved completed/deleted gig history so historical credibility can still be calculated.
- Distinguished Worker and Poster credibility rather than presenting one ambiguous score.

**Reusable lesson:** Model workflows as explicit state machines. Validate every state transition at the backend. Use transactions/batches for related records and define how historical data behaves when a record is deleted.

## 4. UI/UX and visual-design issues

### Issues addressed

- Made Poster gig-management controls visible and usable.
- Corrected action-button colours in light and dark themes.
- Fixed the black “add skill” plus icon that disappeared against the light-theme background.
- Corrected contrast for selected role controls, profile-video controls, chat send buttons and profile-photo actions.
- Standardized headers, typography and spacing across Discover, Matches and Chat.
- Refined gig cards to balance category, location, schedule, description and pay information.
- Added clearer navigation labels for Worker and Poster modes.
- Added explanatory hints for gig details and application actions.
- Improved empty states for notification and application screens.
- Clarified application counts and labels.
- Improved profile statistics layout, including responsive two-column stats.
- Standardized sheet text styles and theme surfaces.
- Added confirmation before destructive actions such as clearing notifications and removing records where appropriate.
- Improved applicant details, avatars and public-profile navigation.

**Reusable lesson:** A design system is not just a colour palette. It includes component behaviour, contrast, typography, spacing, states, confirmation patterns and consistency across themes.

## 5. Content, formatting and data presentation

### Issues addressed

- Added a shared Naira currency formatter to avoid inconsistent currency display.
- Corrected pay formatting in Worker gig details and cards.
- Standardized currency and contrast in Matches.
- Corrected name-initial parsing for avatars.
- Used canonical gig titles in conversations.
- Improved wrapping for long gig titles, locations, category tags and descriptions.
- Prevented long application headings from overflowing.
- Rebalanced gig-card metadata and description space.
- Added posting age to gig cards.
- Clarified lifecycle terminology, including “application”, “confirmed”, “completed” and “closed”.
- Added structured location selection rather than relying only on free-text location values.
- Expanded international location options and improved legacy location matching to avoid false country matches.
- Improved profile location and Worker introduction presentation.

**Reusable lesson:** Formatting is a product-quality concern. Centralize formatters and canonical labels; test realistic long strings, different locales, currency values and missing data.

## 6. Data integrity, schema evolution and legacy compatibility

### Issues addressed

- Synchronized private and public profile fields where required.
- Kept Worker skills and public profile skills aligned.
- Normalized categories before saving and matching.
- Used deterministic document IDs to prevent duplicate applications/reviews/notification records.
- Used batches and transactions for coupled application, notification, chat, completion and payment writes.
- Restricted immutable or sensitive fields through Firestore rules.
- Preserved legacy accepted applications and reviews when newer fields were absent.
- Added legacy fallbacks for old gig and conversation records.
- Archived completed gig evidence before deletion.
- Prevented historical and live gig records from being counted twice.
- Preserved role-specific review context.
- Ensured one participant hiding a conversation does not hide it for the other participant.
- Kept notification records and their related data consistent.

**Reusable lesson:** Schema changes require a migration/compatibility plan. New fields must have defaults or legacy fallbacks. Deletion should be designed together with retention, history and derived statistics.

## 7. Security, privacy and authorization

### Issues addressed

- Developed and repeatedly tightened Firestore security rules.
- Restricted user profile writes to allowed fields and authenticated owners.
- Separated private user records from safe public profile data.
- Enforced application ownership and participant rules.
- Restricted conversations and messages to accepted gig participants.
- Restricted read receipts and conversation hiding to the relevant participant.
- Enforced block rules for applications and conversations.
- Avoided client reads of another user's private blocked-user list.
- Validated notification actors, recipients and event types.
- Restricted review creation and role-specific rating fields.
- Enforced completion/payment conditions and valid status transitions.
- Added report creation and moderation read/update rules.
- Added admin role records and role-based Firestore access.
- Restricted admin audit-log writes from clients.
- Provisioned the initial Super Admin record manually through Firestore Console.
- Corrected AdminAccessService to require active == true, matching the Firestore rules.

**Reusable lesson:** Security rules are part of the application architecture. Test allowed and denied operations directly. Do not rely on hidden buttons, client-side role checks or client-written audit logs.

## 8. Notifications, navigation and messaging

### Issues addressed

- Added in-app notifications.
- Added FCM push notifications and Android notification-channel/permission configuration.
- Added device token registration and removal.
- Added foreground notification display and notification-tap handling.
- Added recovery of notifications received while signed out.
- Added unread badges and mark-read/mark-all-read/clear-all behaviour.
- Made notification taps open the correct gig, application, conversation or Matches destination.
- Made notification navigation switch to the appropriate Worker/Poster role.
- Removed stale notifications or disabled actions when the related record no longer exists.
- Added new-gig notifications for every matching saved Worker skill, regardless of current role/availability.
- Normalized categories so skill-to-gig notification matching is consistent.
- Used deterministic per-recipient/per-gig notification IDs to avoid duplicate matching-gig records.
- Kept chat conversations role-specific and separate by gig.
- Added message timestamps, unread indicators and per-user read receipts.
- Added per-user conversation hiding and restoration when a new message arrives.

**Reusable lesson:** A notification is a navigation contract, not merely a message. Validate the destination, recipient, current role and existence of the related record before routing.

## 9. Media, storage and profile handling

### Issues addressed

- Added profile photo upload, replacement, deletion and public display.
- Added reusable Worker proof-video recording, upload, preview, replacement and removal.
- Added a 30-second proof-video requirement where a gig requests it.
- Added video upload progress/busy state.
- Added file-size and duration validation.
- Used Supabase signed upload flows and Edge Functions rather than Firebase Storage.
- Kept private and public profile media references synchronized.
- Removed public media references before deleting stored media.
- Corrected upload and profile-state rules.
- Added media to gig, application, chat and public-profile presentations.
- Recently added immediate local profile-photo preview and URL cache-busting to prevent old photos remaining visible after replacement.

**Reusable lesson:** Treat media upload as a lifecycle: select/record, validate, upload, persist reference, display, replace, remove and clean up. A successful upload and a successful profile update are separate operations that must be coordinated.

## 10. Performance, asynchronous state and resilience

### User-observed symptoms

- A newly changed profile photo did not display until the app was restarted.
- Profile statistics did not always refresh immediately after switching Worker/Poster mode.
- Discover briefly displayed gigs using the previous role's layout after a role switch.
- Some user actions waited for push-delivery network calls after their database writes had succeeded.
- Notification recovery could read the entire notification history.
- Some profile and blocked-user lookups involved unnecessary sequential work.

### Fixes committed in the current performance pass

| Area | Change | Current status |
|---|---|---|
| Profile photo | Show selected local photo immediately during upload | Committed; needs device verification |
| Profile photo | Add a version query to uploaded URL to invalidate stale image cache | Committed; needs device verification |
| Profile state | Clear preview on upload failure and guard disposed view model updates | Committed; needs device verification |
| Role switching | Add generation checks so older profile-stat refreshes cannot overwrite a newer role | Committed; needs device verification |
| Discover | Clear old role's gig state while loading the new role | Committed; needs device verification |
| Discover | Cancel old role streams and guard old stream data/errors | Committed; needs device verification |
| Matches | Add generation checks to prevent stale stream snapshots after role changes | Committed; needs device verification |
| Matches | Harden timer and subscription lifecycle during disposal | Committed; needs device verification |
| App shell | Keep the profile stream stable across widget rebuilds | Committed; needs device verification |
| Gig discovery | Fetch open gigs and blocked users concurrently | Committed; needs device verification |
| Blocked users | Fetch public profiles concurrently instead of one-by-one | Committed; needs device verification |
| Push delivery | Do not wait for push network delivery after core writes succeed | Committed; needs device verification |
| Gig posting | Start matching-worker notification fan-out without blocking the posting result | Committed; best-effort client-side delivery |
| Missed notifications | Bound sign-in recovery to a recent set of 50 records | Committed; needs device verification |

### Performance work intentionally not over-optimized

- Profile credibility statistics still require multiple reads. They are already parallelized in important places. A denormalized aggregate/counter model should be introduced only with trusted server-side updates, backfill and reconciliation.
- Firestore persistence is unlimited to support offline use. Do not reduce it without testing cache eviction and offline behaviour.
- Flutter image-cache settings should be tuned using device profiling, not guesswork.
- The client-side gig notification fan-out is now detached from the posting flow. It is best-effort and may not finish if the app is terminated. If guaranteed delivery becomes a requirement, move fan-out to a trusted server-side trigger/queue.
- A bounded 50-record notification catch-up is a performance compromise; it does not promise exhaustive delivery of every old unread notification.

**Reusable lesson:** Optimize measured bottlenecks while preserving correctness. A fast UI that silently loses important background work is not a correct solution.

## 11. Offline behaviour and error handling

### Issues addressed

- Enabled Firestore local persistence.
- Kept Matches data visible while waiting for server-backed snapshots.
- Added explicit offline messaging based on Firestore cache metadata.
- Avoided displaying a false offline warning immediately when Firestore first emits cached data.
- Preserved cached data when profile refresh or network access fails.
- Added friendly error messages for common permission, network and application errors.
- Added resilience when legacy or related records are missing.
- Added guards for asynchronous context use and disposed view models.

**Reusable lesson:** Offline-first behaviour needs explicit rules: what is cached, what can be changed offline, when stale data is labelled, and how the app reconciles after reconnecting.

## 12. Build, dependency and release engineering

### Issues addressed

- Aligned Flutter/Dart SDK constraints with dependency versions.
- Updated dependency lockfiles.
- Resolved Firebase Messaging and local-notification plugin API compatibility.
- Updated Android Gradle/NDK configuration.
- Enabled required Android desugaring for notification dependencies.
- Corrected Firebase/Google Services plugin configuration.
- Added release network permission/configuration for Firebase and hosted media.
- Fixed analyzer/linter findings discovered during integration.
- Disabled automatic builds and superseded-build execution to conserve GitHub Actions minutes; builds are grouped manually.
- Fixed earlier invalid/misconfigured APK build attempts and later obtained successful builds.

**Reusable lesson:** Keep build configuration reproducible. Pin compatible toolchain/dependency versions, group builds intentionally, and always install-test the final release artifact.

## 13. Admin dashboard and operations

### Implemented foundation

- Added a protected in-app Admin Dashboard route and profile entry.
- Added role-aware access service.
- Added role-based module visibility for Overview, Users, Gigs, Reports, Announcements and Audit Logs.
- Added Firestore rules for admin roles, reports and audit-log reads.
- Established manual console provisioning for admin roles.
- Added active-status validation in both rules and the client access service.

### Not yet complete

- Dashboard module cards are still foundation/placeholder UI; their workflows are not all implemented.
- Audit-log writes need a trusted server-side mechanism.
- User suspension/ban must disable or restrict the Firebase Auth account through trusted backend code; changing a Firestore profile flag alone is not equivalent.
- Announcements need a dedicated secure server-side workflow rather than arbitrary client-created notification records.
- Admin role provisioning remains a manual console operation for now.

**Reusable lesson:** Admin features need stronger security than ordinary user features. Separate permission checks, trusted actions, audit trails and account-level enforcement.

## 14. Outstanding decisions and verification

| Item | Category | Status / next action |
|---|---|---|
| Grouped build of the latest performance changes | Release/testing | Not yet built; run analyzer/build once the batch is ready |
| On-device verification of photo preview/cache refresh | Performance/media | Test upload success, cancellation, failure and app restart |
| On-device verification of Worker/Poster switching | State/performance | Rapidly switch roles and confirm no stale cards, counts or streams |
| Push delivery after detached dispatch | Notifications/resilience | Verify normal delivery; understand that client fan-out is best-effort |
| Profile statistics at larger data volumes | Performance/data | Measure first; consider trusted aggregate counters only when justified |
| Admin dashboard modules | Admin/product | Implement one module at a time after foundation review |
| Admin audit-log writer | Security/operations | Requires trusted backend |
| Admin account suspension | Security/operations | Requires trusted Firebase Auth administrative action |
| Announcements workflow | Notifications/admin | Define secure server-side write and delivery model |
| Payment processor / escrow | Product/client decision | Do not implement until client clarifies the escrow requirements |
| Automated test suite | Quality | Add tests for critical business rules and regression cases; current repository tree has no dedicated test/ directory |
| Firestore rules deployment | Backend/release | Publish and verify rules in Firebase Console whenever rules change |

## 15. Reusable categories for future project registers

Use these categories consistently on every project:

1. **REQ — Requirements and scope**
2. **ARCH — Architecture and integrations**
3. **FUNC — Functional behaviour and business logic**
4. **UI — UI/UX and visual design**
5. **FMT — Formatting, copy and data presentation**
6. **DATA — Data modelling, integrity and migrations**
7. **SEC — Security, privacy and authorization**
8. **PERF — Performance and resource usage**
9. **ASYNC — State synchronization, streams and concurrency**
10. **NET — Network, offline behaviour and resilience**
11. **NOTIF — Notifications, messaging and navigation**
12. **MEDIA — Images, files, video and storage**
13. **COMP — Compatibility, accessibility and device support**
14. **BUILD — Build system, dependencies and CI/CD**
15. **QA — Testing, regression and release verification**
16. **OPS — Administration, monitoring, support and handover**

Suggested issue IDs: HL-PERF-001, HL-SEC-002, APP2-UI-001. Use one primary category per issue and add secondary tags where necessary.

## 16. Final project lesson

HustleLink demonstrates why a feature is not complete when its screen appears to work. A complete feature includes its data model, permissions, state transitions, error handling, notifications, offline behaviour, role-specific presentation, regression tests and release verification.

Use the companion [ENGINEERING_SOP.md](ENGINEERING_SOP.md) as the repeatable process. Keep this register as the project-specific record of what happened, what changed, what remains and what future projects should learn from it.
