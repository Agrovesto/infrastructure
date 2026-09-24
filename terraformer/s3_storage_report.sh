#!/bin/bash

set -u

OUTPUT="s3-storage-report.csv"

echo "account,bucket,region,objects,size_bytes,size_gb" > "$OUTPUT"

for PROFILE in agrovesto-dev agrovesto-prod; do

  echo
  echo "=========================================="
  echo "Account: $PROFILE"
  echo "=========================================="

  ACCOUNT_ID=$(aws sts get-caller-identity \
    --profile "$PROFILE" \
    --query 'Account' \
    --output text)

  for BUCKET in $(aws s3api list-buckets \
      --profile "$PROFILE" \
      --query 'Buckets[].Name' \
      --output text); do

    echo "Checking: $BUCKET"

    REGION=$(aws s3api get-bucket-location \
      --profile "$PROFILE" \
      --bucket "$BUCKET" \
      --query 'LocationConstraint' \
      --output text 2>/dev/null || echo "unknown")

    # AWS CLI returns "None" for us-east-1
    if [ "$REGION" = "None" ] || [ -z "$REGION" ]; then
      REGION="us-east-1"
    fi

    RESULT=$(aws s3api list-objects-v2 \
      --profile "$PROFILE" \
      --bucket "$BUCKET" \
      --query '[length(Contents || `[]`), sum(Contents[].Size || `[]`)]' \
      --output text 2>/dev/null)

    if [ -z "$RESULT" ]; then
      OBJECTS=0
      SIZE_BYTES=0
    else
      OBJECTS=$(echo "$RESULT" | awk '{print $1}')
      SIZE_BYTES=$(echo "$RESULT" | awk '{print $2}')

      [ "$OBJECTS" = "None" ] && OBJECTS=0
      [ "$SIZE_BYTES" = "None" ] && SIZE_BYTES=0
    fi

    SIZE_GB=$(awk "BEGIN {printf \"%.4f\", $SIZE_BYTES / 1024 / 1024 / 1024}")

    echo "$PROFILE,$BUCKET,$REGION,$OBJECTS,$SIZE_BYTES,$SIZE_GB" >> "$OUTPUT"

    printf "  %-45s %12s objects  %12.4f GB\n" \
      "$BUCKET" "$OBJECTS" "$SIZE_GB"

  done
done

echo
echo "=========================================="
echo "Report generated"
echo "=========================================="
echo "File: $(pwd)/$OUTPUT"
echo
echo "Largest buckets:"
echo

{
  head -1 "$OUTPUT"
  tail -n +2 "$OUTPUT" | sort -t',' -k6,6nr | head -15
} | column -s',' -t

