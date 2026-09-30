#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_MONGO_URI:?Set SOURCE_MONGO_URI to the source MongoDB URI}"
: "${TARGET_MONGO_URI:?Set TARGET_MONGO_URI to the target MongoDB URI}"
: "${CONFIRM_TARGET_REPLACE:?Set CONFIRM_TARGET_REPLACE=YES after verifying the target}"

if [[ "$CONFIRM_TARGET_REPLACE" != "YES" ]]; then
  echo "Refusing migration: set CONFIRM_TARGET_REPLACE=YES only after verifying the target." >&2
  exit 2
fi

if [[ "$SOURCE_MONGO_URI" == "$TARGET_MONGO_URI" ]]; then
  echo "Source and target URIs must differ." >&2
  exit 2
fi

backup_dir="${BACKUP_DIR:-./migration-backups}"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
archive="$backup_dir/mern-ecommerce-$(date -u +%Y%m%dT%H%M%SZ).archive.gz"
trap 'rm -f "$archive".partial' EXIT

echo "Dumping source database to $archive"
mongodump --uri="$SOURCE_MONGO_URI" --archive="$archive.partial" --gzip
mv "$archive.partial" "$archive"

echo "Restoring full dump to target; matching target collections will be dropped and recreated."
mongorestore --uri="$TARGET_MONGO_URI" --archive="$archive" --gzip --drop
echo "Migration completed. Keep the archive until the target has been verified."
