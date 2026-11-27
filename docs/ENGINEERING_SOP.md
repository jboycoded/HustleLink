# Software Engineering SOP & Quality Framework

**Project:** HustleLink  
**Purpose:** A reusable standard for planning, building, reviewing, testing, releasing and maintaining software products.  
**Version:** 1.0 — living document

---

## 1. Operating principles

1. **Define behaviour before writing code.** Every feature needs a user, purpose, expected behaviour, edge cases and acceptance criteria.
2. **Fix root causes, not symptoms.** A visual workaround is not a substitute for correcting the underlying layout, state, data or permission problem.
3. **Protect existing behaviour.** A change is incomplete until related workflows and roles have been regression-tested.
4. **Treat the backend as the source of truth.** UI controls improve usability; database rules and trusted server code enforce permissions and business constraints.
5. **Make important state changes atomic.** Related writes should use a transaction or batch where appropriate.
6. **Design for failure.** Network loss, stale records, duplicate taps, retries, app restarts and legacy data are normal conditions to handle.
7. **Measure before tuning.** Avoid arbitrary cache, concurrency or architecture changes without a known bottleneck or clear risk.
8. **Keep a decision trail.** Record why a technology, data model, workflow or trade-off was selected.
9. **Separate implementation from verification.** A committed change is not automatically tested or production-ready.
10. **Prefer maintainable simplicity.** Do not add infrastructure or abstractions without a concrete need.

## 2. Standard development lifecycle

### Stage 0 — Project discovery and scope

Before implementation:

- Identify the client, users, business problem and measurable outcome.
- List user roles and what each role is allowed to do.
- Map the main user journeys from start to finish.
- Identify external services, costs, quotas, hosting, data residency and account ownership.
- Separate launch requirements from later enhancements.
- Record exclusions and unresolved client decisions.

**Required outputs:** project brief; user/role matrix; feature list and priority; initial architecture diagram; open questions and assumptions register.

**Gate:** Do not design a payment, escrow, identity or moderation system around an assumption the client has not confirmed.

### Stage 1 — Requirements and acceptance criteria

For each feature, write:

- User story: who needs it and why.
- Preconditions: what must already be true.
- Main flow: normal successful path.
- Alternate flows: cancellation, rejection, retry, empty data and offline behaviour.
- Permissions: who can read, create, update and delete.
- Data changes: records and fields affected.
- Notifications/navigation: who is informed and where a tap should lead.
- Acceptance criteria: observable conditions that prove the feature works.

Use explicit lifecycle states. Define valid transitions and disallowed transitions before coding.

**Gate:** Every high-priority feature has testable acceptance criteria.

### Stage 2 — Architecture and data design

- Choose the client framework, backend, authentication, database, file storage and notification services.
- Assign one authoritative owner to each type of data.
- Define private versus public profile data.
- Define document identifiers, relationships, status fields, timestamps and deletion/archive behaviour.
- Design security rules alongside the data model, not after the UI is complete.
- Decide how server-only operations will be performed.
- Identify indexes, query limits, pagination and expected data growth.
- Define offline/cache expectations and what data must remain available.

**Required outputs:** architecture/data-flow diagram; schema; role-permission matrix; security-rules plan; integration/configuration checklist; migration and legacy-data plan.

**Gate:** Every sensitive write has a trusted enforcement point. Client-side validation alone is not security.

### Stage 3 — UI/UX and design system

- Establish colours, typography, spacing, radii, elevation/shadows, icons and component conventions.
- Define light and dark theme behaviour.
- Build reusable buttons, cards, inputs, dialogs, bottom sheets, avatars, empty states and loading states.
- Check long text, small screens, keyboard overlap, scrolling, contrast and touch targets.
- Use consistent labels and terminology across screens.
- Define feedback for loading, success, failure, disabled and destructive actions.

**Gate:** Review the feature in both themes and at realistic content lengths before calling the UI complete.

### Stage 4 — Implementation

Recommended separation:

- **UI/screens:** rendering and user interaction.
- **View models/state controllers:** screen state, loading, validation and orchestration.
- **Repositories:** application-facing data access.
- **Services:** backend, storage, messaging and external integrations.
- **Models:** typed data and serialization.
- **Core:** routing, theme, shared utilities and reusable widgets.

Implementation rules:

- Keep business rules out of presentation widgets where practical.
- Avoid duplicate formatters, category lists, validation rules and theme constants.
- Use typed models and predictable error handling.
- Prevent duplicate submissions and repeated destructive actions.
- Guard asynchronous operations against stale results after navigation, role changes or disposal.
- Cancel stream subscriptions and timers when their owner is disposed.
- Do not block a successful primary action on best-effort secondary work such as push delivery.
- Do not silently swallow failures that affect data integrity or user trust.

### Stage 5 — Security and data integrity

For every collection/table and server endpoint, verify:

- Authentication is required where appropriate.
- Ownership and participant checks are enforced.
- Roles and active status are validated server-side.
- Users cannot modify fields they do not own.
- Status transitions are constrained.
- Duplicate applications, reviews, payments or other one-time actions are prevented.
- Private data is not exposed through public profile documents.
- Notifications are created only for valid events and recipients.
- Audit records cannot be forged or edited by ordinary clients.
- Deletion preserves required history and does not erase another participant's records.
- File uploads enforce owner, type, size and duration constraints.

Test both allowed and denied operations. A screen hiding a button does not prove the underlying write is secure.

### Stage 6 — Performance and resilience

Review the complete user journey, not just individual functions.

**Measure/check:**

- Number of network reads and writes per action.
- Sequential requests that could safely run concurrently.
- Unbounded collection reads.
- N+1 document lookups.
- Repeated streams created during widget rebuilds.
- Unnecessary profile/stat recomputation.
- Image/video sizes, caching and disposal.
- Large lists without pagination or limits.
- Long work performed before a primary action returns.
- Stale async responses after role changes or navigation.
- Offline cache behaviour and recovery after reconnecting.

**Rules:**

- Parallelize independent reads with Future.wait when safe.
- Add query limits and pagination where data can grow.
- Keep streams stable and cancel them when no longer needed.
- Keep primary writes atomic; detach only best-effort secondary tasks.
- Use backend queues/triggers for work that must complete even if the app closes.
- Do not replace a working offline strategy without testing cache eviction and reconnect behaviour.
- Profile on representative devices before setting aggressive cache limits.

### Stage 7 — Testing and quality assurance

Testing must cover more than the happy path.

1. **Static checks:** formatting, analyzer/linter, dependency and build checks.
2. **Unit tests:** validation, formatters, models, state transitions and calculations.
3. **Integration tests:** authentication, database rules, storage and external services.
4. **Workflow tests:** complete user journeys across roles.
5. **Regression tests:** previously fixed issues and adjacent features.
6. **Negative tests:** unauthorized writes, duplicate actions, missing data and invalid states.
7. **Resilience tests:** slow network, offline launch, reconnect, app restart and expired sessions.
8. **Visual tests:** light/dark themes, small screens, long text, empty/loading/error states.
9. **Release tests:** install, upgrade, sign in, core actions, notification delivery and app restart.

For every bug, test the original reproduction steps after the fix.

### Stage 8 — Build and release

- Confirm the target branch and exact commit.
- Run static analysis and automated tests before a release build.
- Build only after a coherent batch of changes is ready.
- Verify build configuration, SDK/NDK, plugins, secrets and environment variables.
- Never commit private service-role keys or signing secrets.
- Install the produced artifact on a real device.
- Test critical workflows on the installed release build, not only a debug session.
- Record build number, commit, artifact location, test result and known limitations.
- Keep a rollback path.

**Gate:** A successful build proves compilation, not product correctness.

### Stage 9 — Operations, support and maintenance

- Monitor crashes, failed requests, permission errors, notification failures and storage usage.
- Maintain an issue register and release notes.
- Review access roles and deactivate accounts when needed.
- Keep backups and document restore procedures.
- Track external-service billing, quotas and ownership.
- Revisit performance when real usage reveals bottlenecks.
- Document client handover, environment setup and operational responsibilities.

## 3. Issue and change management SOP

### 3.1 Record every issue

| Field | Required information |
|---|---|
| ID | Unique identifier, e.g. HL-PERF-001 |
| Title | Short, specific description |
| Category | One primary category; add secondary tags if needed |
| Severity | Critical / High / Medium / Low |
| Status | New / Investigating / Planned / In progress / Fixed / Verified / Deferred |
| Environment | Device, OS, app version, build/commit and network |
| Reproduction | Exact steps to reproduce |
| Expected result | What should happen |
| Actual result | What happened |
| Root cause | Why it happened; not just the symptom |
| Affected areas | Screens, services, collections and files |
| Resolution | What changed and why |
| Regression checks | Related workflows tested |
| Evidence | Logs, screenshots, test output or recording |
| Commit/release | Commit SHA and build containing the change |
| Follow-up | Remaining risks or future work |

### 3.2 Severity definitions

- **Critical:** data exposure/loss, account compromise, payments or core workflows unusable for most users.
- **High:** major workflow broken, serious integrity issue or broad failure with no practical workaround.
- **Medium:** feature works inconsistently, significant UX/performance issue or limited group affected.
- **Low:** cosmetic defect, minor copy/formatting issue or non-blocking improvement.

Severity measures impact, not how easy the fix is.

### 3.3 Root-cause workflow

1. Reproduce the issue.
2. Capture actual and expected behaviour.
3. Identify the owning layer: UI, state, repository, service, backend, rules, storage or build.
4. Trace the data and event flow.
5. Check related role, offline, legacy-data and race-condition cases.
6. Form a root-cause hypothesis.
7. Make the smallest safe change that addresses the cause.
8. Run the original reproduction and regression checks.
9. Record the commit and verification status.
10. Update the register if the issue reveals a reusable lesson.

### 3.4 Change review checklist

- [ ] Does it satisfy the stated requirement?
- [ ] Is the change in the correct architectural layer?
- [ ] Are both roles and relevant permissions covered?
- [ ] Are loading, empty, error and offline states handled?
- [ ] Are duplicate taps and concurrent operations safe?
- [ ] Are database writes atomic where needed?
- [ ] Are rules and indexes updated where needed?
- [ ] Are old records still handled safely?
- [ ] Are light and dark themes correct?
- [ ] Are long strings and small screens handled?
- [ ] Are subscriptions, timers and controllers disposed?
- [ ] Does the analyzer pass?
- [ ] Have regression tests been run?
- [ ] Is the documentation/register updated?

## 4. Reusable feature specification template

### Feature: [Name]

**Problem / business goal:**  
**Primary user(s):**  
**User story:**  
**Preconditions:**  
**Main flow:**  
**Alternate/error flows:**  
**Permissions:**  
**Data read:**  
**Data written:**  
**Status transitions:**  
**Notifications and navigation:**  
**Offline behaviour:**  
**Validation rules:**  
**Security constraints:**  

**Acceptance criteria:**
- [ ] 
- [ ] 
- [ ] 

**Test cases:**
- Happy path:
- Invalid input:
- Unauthorized user:
- Duplicate action:
- Network failure:
- App restart:
- Legacy data:
- Regression:

**Implementation files/services:**  
**Release notes:**  

## 5. Reusable release checklist

- [ ] Scope and open decisions reviewed
- [ ] No known Critical or High defects unresolved
- [ ] Analyzer and automated tests pass
- [ ] Security rules reviewed and deployed
- [ ] Required indexes exist
- [ ] Storage and notification services configured
- [ ] Release build succeeds
- [ ] Installed build passes core workflow tests
- [ ] Offline/reconnect behaviour checked
- [ ] No secrets committed
- [ ] Known limitations documented
- [ ] Commit/build/artifact recorded
- [ ] Client handover notes prepared

## 6. Project-specific implementation notes

HustleLink uses Firebase Authentication and Cloud Firestore for identity and application data, with Supabase Storage and Supabase Edge Functions for media/push-related server operations. This is a deliberate hybrid architecture, not a full migration to Supabase.

For HustleLink-specific historical issues and outstanding work, see [HUSTLELINK_QUALITY_REGISTER.md](HUSTLELINK_QUALITY_REGISTER.md).

This SOP is a starting standard, not rigid bureaucracy. Keep controls that reduce defects and remove steps that do not add measurable value.
