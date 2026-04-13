#!/bin/bash
# ============================================================
# DEPLOY German A1 Learner to GitHub Pages
# Usage: bash deploy-to-github.sh YOUR_GITHUB_TOKEN
# ============================================================

set -e

TOKEN="$1"
GITHUB_USER="jimal254"
REPO_NAME="german-a1-learner"
BRANCH="main"

if [ -z "$TOKEN" ]; then
  echo "❌ Please provide your GitHub Personal Access Token."
  echo "Usage: bash deploy-to-github.sh YOUR_TOKEN"
  echo ""
  echo "Get a token at: https://github.com/settings/tokens"
  echo "Required scopes: repo, workflow"
  exit 1
fi

echo "🚀 Starting GitHub deployment..."
echo "   User: $GITHUB_USER"
echo "   Repo: $REPO_NAME"
echo ""

# ── 1. Check if repo exists ──────────────────────────────────
echo "📦 Step 1: Checking / creating repository..."

REPO_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME")

if [ "$REPO_CHECK" == "200" ]; then
  echo "   ✅ Repository already exists."
else
  echo "   Creating new repository..."
  CREATE_RESP=$(curl -s -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/user/repos" \
    -d "{
      \"name\": \"$REPO_NAME\",
      \"description\": \"Goethe-Zertifikat A1 German Exam Prep — Interactive Study App\",
      \"private\": false,
      \"auto_init\": false,
      \"homepage\": \"https://$GITHUB_USER.github.io/$REPO_NAME\"
    }")
  echo "   ✅ Repository created."
fi

# ── 2. Encode index.html to base64 ──────────────────────────
echo ""
echo "📄 Step 2: Encoding app file..."
CONTENT=$(base64 -w 0 index.html)
echo "   ✅ File encoded ($(wc -c < index.html) bytes)"

# ── 3. Check if index.html already exists (need SHA for update)
echo ""
echo "📤 Step 3: Uploading index.html..."

EXISTING=$(curl -s \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/contents/index.html")

SHA=$(echo "$EXISTING" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$SHA" ]; then
  echo "   File exists — updating..."
  PAYLOAD="{\"message\":\"Update German A1 Learner app\",\"content\":\"$CONTENT\",\"sha\":\"$SHA\",\"branch\":\"$BRANCH\"}"
else
  echo "   New file — uploading..."
  PAYLOAD="{\"message\":\"Initial deployment: German A1 Learner app\",\"content\":\"$CONTENT\",\"branch\":\"$BRANCH\"}"
fi

UPLOAD_RESP=$(curl -s -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/contents/index.html" \
  -d "$PAYLOAD")

if echo "$UPLOAD_RESP" | grep -q '"content"'; then
  echo "   ✅ index.html uploaded successfully."
else
  echo "   ❌ Upload failed. Response:"
  echo "$UPLOAD_RESP" | head -5
  exit 1
fi

# ── 4. Enable GitHub Pages ───────────────────────────────────
echo ""
echo "🌐 Step 4: Enabling GitHub Pages..."

PAGES_RESP=$(curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/pages" \
  -d "{\"source\":{\"branch\":\"$BRANCH\",\"path\":\"/\"}}" 2>/dev/null)

# If already enabled, try PUT to update
if echo "$PAGES_RESP" | grep -q "already enabled\|409"; then
  curl -s -X PUT \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/pages" \
    -d "{\"source\":{\"branch\":\"$BRANCH\",\"path\":\"/\"}}" > /dev/null
fi

echo "   ✅ GitHub Pages configured."

# ── 5. Done ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "📁 Repository:"
echo "   https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "🌐 Live App (active in ~60 seconds):"
echo "   https://$GITHUB_USER.github.io/$REPO_NAME"
echo ""
echo "Guten Erfolg beim Lernen, Jimmy! 🇩🇪"
echo "════════════════════════════════════════════════"
