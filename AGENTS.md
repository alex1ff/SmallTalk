# Agent Guide

## Project
- Flutter app that is no longer maintained through FlutterFlow.
- Former FlutterFlow-generated code can be edited when it is the right fix; preserving FlutterFlow regeneration compatibility is not a project constraint.

## Docs and context
- Use the installed Context7 plugin for third-party package and API documentation.
- Prefer official Flutter and Dart documentation for framework APIs.

## Editing rules
- Keep diffs focused and avoid broad refactors unless requested.
- Do not avoid former FlutterFlow files solely because they were generated; still keep edits scoped and reviewable.
- Follow lints and conventions from `analysis_options.yaml`.

## Validation
- Run `flutter analyze` after code changes.
- Run `flutter test` when relevant tests exist.
- If a check is skipped, explain why.
