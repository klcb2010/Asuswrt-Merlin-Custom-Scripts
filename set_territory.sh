#!/bin/sh

LOG_FILE="/jffs/scripts/startup.log"
TARGET="US/01"

CURRENT="$(nvram get territory_code)"

if [ "$CURRENT" != "$TARGET" ]; then
    nvram set territory_code="$TARGET"
    nvram commit
    echo "$(date): territory_code changed from '$CURRENT' to '$TARGET'" > "$LOG_FILE"
else
    echo "$(date): territory_code already '$TARGET', no change" > "$LOG_FILE"
fi
