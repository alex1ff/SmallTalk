# Project Audit PRD

Last updated: 2026-05-28

## Source Status

The audit files requested by the tranche prompt were missing from this checkout, so this run bootstrapped the audit log from the current repository state and subagent findings.

## Project Direction

- As of 2026-05-26, the app is no longer intended to be maintained through FlutterFlow.
- Former FlutterFlow-generated files may be edited directly when needed for a safe, scoped fix.
- Future tranches do not need to preserve FlutterFlow regeneration compatibility.

## Goal

Review, optimize, and safely remediate the Flutter/Dart video call surface and directly related backend/session code in narrow, reviewable tranches.

## Current Tranche

- tranche_id: VC-TR-022
- review_round: 24
- focus: Finish production secret/deployment readiness for the video-call backend surface.
- priority: release-safety/deploy-safety
- scope: Validate required Firebase Secret Manager entries, make the secret readiness gate tolerant of transient Firebase CLI metadata failures without exposing values, deploy only the readiness-gate `custom_cloud_functions`, clear stale plaintext Daily env metadata from `acceptCall`, and smoke-test the Daily/RevenueCat webhook endpoints.

## Counters

- bugs_found_total: 36
- bugs_fixed_total: 36
- bugs_open_total: 0
- privacy_findings_open: 0
- lifecycle_findings_open: 0
- test_gaps_open: 2
- docs_updated_count: 7

## Acceptance Criteria

- No Flutter UI or call overlay behavior changes are introduced.
- Required Firebase secrets are present with enabled versions and the secret readiness gate passes.
- The scoped readiness deploy completes without broad Firebase project deploy.
- Deployment readiness passes for required function exports, trigger types, secret bindings, and plaintext secret-env checks.
- Daily webhook verification POST returns 200 OK after redeploy.
- RevenueCat webhook rejects unauthenticated requests and accepts authenticated ignored events after redeploy.
- Customer-declined secret rotation is documented without storing secret values.
- Audit docs and inventory are updated after the tranche.
- Reviewer gate completed with no P0-P2 blockers or accepted fixes documented.
