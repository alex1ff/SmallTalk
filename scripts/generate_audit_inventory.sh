#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="$ROOT_DIR/docs/project-audit-inventory.tsv"
TMP_FILE="$(mktemp)"

cd "$ROOT_DIR"
mkdir -p docs

printf 'path\ttype\tbytes\tsha256\n' > "$TMP_FILE"

{
  find docs audit firebase/custom_cloud_functions -type f \
    ! -path '*/node_modules/*' \
    ! -path '*/.npm-cache/*' \
    ! -path 'docs/project-audit-inventory.tsv' 2>/dev/null || true
  printf '%s\n' \
    scripts/generate_audit_inventory.sh \
    AGENTS.md \
    lib/authorization/registration/registration_widget.dart \
    lib/authorization/shared/social_auth_entry_logic.dart \
    lib/backend/backend.dart \
    lib/backend/schema/index.dart \
    lib/backend/schema/user_public_profiles_record.dart \
    lib/components/review_card/review_card_widget.dart \
    lib/flutter_flow/permissions_util.dart \
    lib/main.dart \
    lib/custom_code/widgets/minimal_daily_widget.dart \
    lib/services/voip_service.dart \
    lib/shared_pages/black_list/black_list_widget.dart \
    lib/shared_pages/call_details/call_details_widget.dart \
    lib/shared_pages/call_summary/call_summary_model.dart \
    lib/shared_pages/call_summary/call_summary_widget.dart \
    lib/shared_pages/chat_thread/chat_thread_widget.dart \
    lib/shared_pages/profile/profile_widget.dart \
    lib/shared_pages/video_call_page/video_call_page_widget.dart \
    lib/shared_pages/video_call_page/video_call_page_model.dart \
    lib/students_pages/components/fav/fav_widget.dart \
    lib/students_pages/favorite/favorite_widget.dart \
    lib/students_pages/native_speaker_page/native_speaker_page_widget.dart \
    lib/students_pages/students_dashboard/students_dashboard_widget.dart \
    lib/students_pages/waiting_for_teacher_page/waiting_for_teacher_page_widget.dart \
    lib/teachers_pages/dashboard_n_s/dashboard_n_s_widget.dart \
    lib/teachers_pages/pay_copy/pay_copy_widget.dart \
    test/regression/qa1_release_surface_contracts_test.dart \
    test/regression/voip_call_surface_contracts_test.dart \
    firebase/firebase.json \
    firebase/firestore.indexes.json \
    firebase/firestore.rules \
    analysis_options.yaml \
    pubspec.yaml
} | awk 'NF && !seen[$0]++' | sort | while IFS= read -r file; do
  if [[ ! -f "$file" ]]; then
    continue
  fi

  case "$file" in
    docs/*) type="doc" ;;
    audit/*) type="audit" ;;
    firebase/*) type="backend" ;;
    lib/*) type="flutter" ;;
    test/*) type="test" ;;
    *) type="project" ;;
  esac

  bytes="$(wc -c < "$file" | tr -d '[:space:]')"
  sha="$(shasum -a 256 "$file" | awk '{print $1}')"
  printf '%s\t%s\t%s\t%s\n' "$file" "$type" "$bytes" "$sha"
done >> "$TMP_FILE"

mv "$TMP_FILE" "$OUT_FILE"
printf 'Wrote %s\n' "$OUT_FILE"
