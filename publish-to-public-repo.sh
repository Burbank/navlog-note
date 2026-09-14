#!/bin/zsh
set -euo pipefail
# Run from this folder after: gh repo create Burbank/quicklog-privacy --public
git init
git add .
git commit -m "Add QUICKLOG privacy and support Pages."
git branch -M main
git remote add origin https://github.com/Burbank/quicklog-privacy.git
git push -u origin main
echo
echo "Then enable Pages: https://github.com/Burbank/quicklog-privacy/settings/pages"
echo "  Source: Deploy from a branch → main → / (root) → Save"
echo
echo "Privacy: https://burbank.github.io/quicklog-privacy/privacy-policy.html"
echo "Support: https://burbank.github.io/quicklog-privacy/support.html"
