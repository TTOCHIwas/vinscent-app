# Code SRP Review - 2026-07-22

## Review scope

This review covers the files changed while hardening character artifacts,
recoverable app recordings, router lifetime, push delivery persistence, and the
recording feature's application and data boundaries. The review traced each
path from caller to application coordinator, repository facade, concrete
gateway, database function, cleanup path, and contract test.

## Production files

| File | Owned responsibility | SRP assessment |
| --- | --- | --- |
| `apps/mobile/lib/app/application/app_router_refresh_notifier.dart` | Converts session state changes into router refresh signals | Pass. It owns one framework adapter concern. |
| `apps/mobile/lib/app/router.dart` | Application route composition and redirect wiring | Pass as a composition root. Redirect policy and refresh mechanics remain outside the route table. |
| `apps/mobile/lib/features/characters/data/couple_character.dart` | Character data and storage path conventions | Acceptable. Split the path helper only if artifact formats expand again. |
| `apps/mobile/lib/features/characters/data/couple_character_repository.dart` | Character read/write persistence transaction | Acceptable with monitoring. Upload, finalization reconciliation, and cleanup belong to one atomic save workflow, but the file should not absorb editor behavior. |
| `apps/mobile/lib/features/recordings/application/couple_recording_overview_controller.dart` | Overview state, realtime refresh, and mutation refresh | Existing hotspot. Realtime lifecycle and mutation commands can become separate collaborators when this controller changes again. |
| `apps/mobile/lib/features/recordings/application/pending_recording_draft_policy.dart` | Classifies whether a failed draft remains recoverable | Pass. Pure policy with no storage or UI dependency. |
| `apps/mobile/lib/features/recordings/application/pending_recording_draft_store.dart` | Persists pending recording metadata and its local audio file | Pass. Metadata adapter and file lifecycle are behind narrow interfaces and can be replaced in tests. |
| `apps/mobile/lib/features/recordings/application/pending_recording_upload_coordinator.dart` | Persisted draft lifecycle, bounded retry, retention, and cleanup | Pass. It has no recorder or UI-state dependency and exposes one recoverable-upload workflow. |
| `apps/mobile/lib/features/recordings/application/recording_capture_controller.dart` | Recorder gesture lifecycle, timer, and capture UI state | Pass. Device I/O and persisted-upload policy are injected collaborators; the public provider and gesture API are unchanged. |
| `apps/mobile/lib/features/recordings/application/recording_capture_device.dart` | Adapts the `record` plugin to the capture contract | Pass. It is the only application file that knows `AudioRecorder` and `RecordConfig`. |
| `apps/mobile/lib/features/recordings/data/couple_recording_data_gateways.dart` | Narrow recording persistence capability contracts | Pass. Read, current recording, slots, artwork, and placement can be replaced independently. |
| `apps/mobile/lib/features/recordings/data/supabase_couple_recording_gateway_support.dart` | Shared Supabase transport, response normalization, and error mapping | Pass. It contains no recording workflow and its pure conversion behavior has direct tests. |
| `apps/mobile/lib/features/recordings/data/supabase_couple_recording_overview_reader.dart` | Reads and maps the current recording overview | Pass. It owns the two read RPCs and signed-URL composition only. |
| `apps/mobile/lib/features/recordings/data/supabase_current_couple_recording_writer.dart` | Uploads and atomically finalizes the current recording | Pass with monitoring. Stable-ID reconciliation and conditional orphan cleanup are one persistence workflow. |
| `apps/mobile/lib/features/recordings/data/supabase_couple_recording_slot_writer.dart` | Opens, saves, and deletes recording slots | Pass. These commands share the slot revision and capacity contract. |
| `apps/mobile/lib/features/recordings/data/supabase_couple_recording_slot_artwork_store.dart` | Reads and atomically replaces slot artwork artifacts | Pass with monitoring. Two immutable object uploads, pointer finalization, and cleanup are one artwork save workflow. |
| `apps/mobile/lib/features/recordings/data/supabase_couple_recording_slot_placement_store.dart` | Creates, moves, and removes home placements | Pass. It owns only placement revision RPCs. |
| `apps/mobile/lib/features/recordings/data/supabase_couple_recording_repository.dart` | Composes the recording aggregate repository facade | Pass. The 138-line facade delegates to five narrow collaborators and has no Supabase SDK dependency. |
| `supabase/functions/_shared/push.ts` | Push-delivery orchestration from preference check through FCM result aggregation | Pass. Dispatch persistence was removed; individual transport failures are converted into delivery outcomes. |
| `supabase/functions/_shared/push_dispatch_repository.ts` | Claims and atomically completes push dispatch persistence | Pass. Database calls, response validation, and bounded persistence retry are isolated here. |
| `supabase/migrations/20260722000000_make_character_artifacts_atomic.sql` | Immutable character artifact revisions and cleanup contract | Pass for a migration boundary. Validation, pointer switch, and cleanup functions are separately named. |
| `supabase/migrations/20260722001000_harden_push_dispatch_completion.sql` | Push claim ownership and atomic delivery completion | Pass for a migration boundary. Row ownership, idempotency, and delivery logging are one transaction. |

## Contract and verification files

| File | Contract covered | Assessment |
| --- | --- | --- |
| `apps/mobile/test/app/app_router_lifecycle_test.dart` | Router identity across auth changes | Focused and sufficient for the regression. |
| `apps/mobile/test/features/characters/data/couple_character_storage_paths_test.dart` | Immutable and legacy character path formats | Focused path contract. |
| `apps/mobile/test/features/recordings/application/couple_recording_overview_realtime_test.dart` | Stable recording ID forwarding during resumed upload | Focused application-to-repository contract. |
| `apps/mobile/test/features/recordings/application/pending_recording_draft_policy_test.dart` | Recoverable versus terminal draft failures | Complete branch coverage for the policy enum. |
| `apps/mobile/test/features/recordings/application/pending_recording_draft_store_test.dart` | Metadata, local file restoration, removal, and invalid state cleanup | Covers the persistence adapter boundary. |
| `apps/mobile/test/features/recordings/application/pending_recording_upload_coordinator_test.dart` | Retry, retention, cleanup, and single-flight draft upload | Covers success, recoverable failure, terminal failure, and concurrent calls. |
| `apps/mobile/test/features/recordings/application/recording_capture_controller_test.dart` | Injected recorder lifecycle and pending-draft restoration | Covers normal capture, the prepare/release race, and restart recovery. |
| `apps/mobile/test/features/recordings/data/supabase_couple_recording_gateway_support_test.dart` | RPC response normalization and Supabase error conversion | Covers map/list/null inputs and both database and storage errors. |
| `apps/mobile/test/features/recordings/data/supabase_couple_recording_repository_facade_test.dart` | Facade delegation across all five recording capabilities | Verifies every public method and argument remains connected. |
| `supabase/tests/database/couple_character_write_contract.test.sql` | Atomic pointer switch, idempotency, authorization, and cleanup | Covers the database ownership boundary. |
| `supabase/tests/database/push_dispatch_contract.test.sql` | Claim ownership, atomic completion, idempotency, and stale-owner rejection | Covers the database transaction boundary. |
| `supabase/tests/functions/push_dispatch_repository.test.ts` | Retry, terminal error propagation, claim parsing, and RPC arguments | Covers the Edge persistence adapter. |
| `docs/code-architecture-and-verification.md` | Repeatable project verification commands | Updated to include the new Edge contract test. |

## Remaining risks

1. `couple_recording_overview_controller.dart` still owns realtime subscription
   lifecycle and post-mutation refresh scheduling. Its behavior is tested, but a
   separate realtime refresh collaborator is appropriate before adding another
   subscription source or refresh policy.
2. FCM and PostgreSQL cannot form one distributed transaction. The new bounded
   completion retry and claim ownership greatly reduce duplicate delivery risk,
   but a provider success followed by total database unavailability can still
   leave an uncertain `processing` dispatch. Exact-once delivery would require
   provider-side idempotency that FCM does not expose.
3. A character upload timeout can leave an immutable orphan revision because
   deleting it immediately could race a late successful finalize RPC. A periodic
   orphan-artifact sweeper is the safe follow-up if storage growth becomes visible.
4. Storage object upload and database pointer finalization cannot share one
   transaction. Current recording and slot artwork writers therefore retain
   stable IDs, reconciliation checks, and conservative cleanup behavior.
5. Database lint still reports pre-existing warnings in invite generation and
   `replace_current_couple_recording`; neither warning is in this change set.

## Verification result

- Flutter tests: 376 passed
- Flutter analyzer: no issues
- Android unit tests: passed
- Android debug APK: built successfully
- Supabase database contracts: 180 passed
- Edge unit tests: 12 passed
- Edge TypeScript syntax checks: passed
- Supabase Edge Runtime bundle: passed
- AI API tests: 39 passed
