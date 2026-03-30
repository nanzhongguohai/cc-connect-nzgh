#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_PATH="$ROOT_DIR/.git/hooks/pre-push"
MARKER="cc-connect pre-push redeploy hook"

if [[ ! -d "$ROOT_DIR/.git" ]]; then
  echo "[hook] ERROR: .git directory not found under $ROOT_DIR" >&2
  exit 1
fi

if [[ -f "$HOOK_PATH" ]] && ! grep -q "$MARKER" "$HOOK_PATH"; then
  echo "[hook] ERROR: existing pre-push hook found at $HOOK_PATH" >&2
  echo "[hook] Refusing to overwrite a hook that was not installed by this repo helper." >&2
  exit 1
fi

cat >"$HOOK_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# cc-connect pre-push redeploy hook

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

bash scripts/redeploy-local.sh
EOF

chmod +x "$HOOK_PATH"
echo "[hook] installed $HOOK_PATH"
echo "[hook] every git push will now run bash scripts/redeploy-local.sh first"
