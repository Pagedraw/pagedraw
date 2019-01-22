#!/bin/bash -e

echo "[cli]"
CLI_LOC=`wc -l $(git ls-files | grep -E "^cli" | grep -E -v "(\.md|yarn\.lock|\.gitignore|package\.json|\.env\.dev|tsconfig\.json)$") | sort`
echo "$CLI_LOC"

echo "[generated]"
GENERATED_LOC=`wc -l src/pagedraw/* | sort`
echo "$GENERATED_LOC"

echo "[tools/tests]"
TOOLS_LOC=`wc -l test/**/*.* e2e-tests/*.* src/editor/demos.cjsx src/editor/preview-for-puppeteer.cjsx | grep -E -v "(\.md|yarn\.lock|\.gitignore|package\.json|\.env\.dev|tsconfig\.json)$" | sort`
echo "$TOOLS_LOC"

echo "[editor]"
EDITOR_LOC=`wc -l $(git ls-files | grep -E "^src/editor/" | grep -E -v "^((src/editor/demos)|(src/editor/preview-for-puppeteer))") static/editor.css | sort`
echo "$EDITOR_LOC"

echo "[editor/platform]"
FRONTEND_LOC=`wc -l src/frontend/* | sort`
echo "$FRONTEND_LOC"

echo "[core]"
CORE_LOC=`wc -l $(git ls-files | grep -E "^(src|doc-validator)" \
    | grep -E -v "^src/migrations" \
    | grep -E -v "^src/pagedraw" \
    | grep -E -v "^src/editor" \
    | grep -E -v "^src/frontend" \
    | grep -E -v "((^e2e-tests)|(^src/editor/demos.cjsx$))" \
    | grep -E -v "(\.md|yarn\.lock|\.gitignore|package\.json|\.env\.dev|tsconfig\.json)$") \
    | sort`
echo "$CORE_LOC"

echo "[combined]"
COMBINED_LOC=$(echo """
$(echo "$CLI_LOC" | tail -n1)
$(echo "$GENERATED_LOC" | tail -n1)
$(echo "$TOOLS_LOC" | tail -n1)
$(echo "$EDITOR_LOC" | tail -n1)
$(echo "$FRONTEND_LOC" | tail -n1)
$(echo "$CORE_LOC" | tail -n1)
""" | awk '{ sum += $1; } END { print sum; }' "$@")
echo "   $COMBINED_LOC total"
