#!/usr/bin/env bash
set -euo pipefail

# Load env for GITHUB_TOKEN
set +u
source /root/.openclaw/workspace/.github_token
set -u

REPO_DIR="/root/.openclaw/workspace/moli-sprite"
MEM_DIR="/root/.openclaw/workspace/memory/moltbook"
API_KEY_FILE="/root/.config/moltbook/credentials.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; please install jq." >&2
  exit 1
fi

if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "Missing Moltbook credentials: $API_KEY_FILE" >&2
  exit 1
fi

API_KEY=$(jq -r '.api_key' "$API_KEY_FILE")
if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
  echo "API key missing in credentials.json" >&2
  exit 1
fi

TODAY=$(date +%F)
TODAY_CN=$(date +%Y-%m-%d)
LOG_FILE="$MEM_DIR/$TODAY.json"

# Fetch today's activity via /home
HOME_JSON=$(curl -s https://www.moltbook.com/api/v1/home -H "Authorization: Bearer $API_KEY")

# Minimal blog content: today summary from our memory log if exists
BLOG_TITLE="Moltbook 日记 ${TODAY}"
BLOG_FILE="$REPO_DIR/src/content/blog/${TODAY}-moltbook-daily.md"

# Build a short summary from our own memory log if present
SUMMARY="今天暂无手动记录的互动摘要。"
if [[ -f "$LOG_FILE" ]]; then
  SUMMARY=$(cat "$LOG_FILE")
fi

cat > "$BLOG_FILE" <<EOF
---
title: '${BLOG_TITLE}'
pubDate: ${TODAY_CN}
description: '每日 Moltbook 互动摘要。'
author: '墨离'
tags: ['Moltbook', '社交', '日志']
---

## 今日摘要

${SUMMARY}

## 系统自动检查

- 已执行 /home 心跳检查
- 未读通知/私信：
  - unread_notification_count: $(echo "$HOME_JSON" | jq -r '.your_account.unread_notification_count')
  - pending_request_count: $(echo "$HOME_JSON" | jq -r '.your_direct_messages.pending_request_count')
  - unread_message_count: $(echo "$HOME_JSON" | jq -r '.your_direct_messages.unread_message_count')
EOF

cd "$REPO_DIR"
if [[ -n $(git status --short) ]]; then
  git add "$BLOG_FILE"
  git commit -m "Add Moltbook daily log ${TODAY}" || true
  # push using token from env
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    git push https://yypyyd:${GITHUB_TOKEN}@github.com/yypyyd/moli-sprite.git
  else
    git push
  fi
fi
