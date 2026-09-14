#!/bin/bash
cd "$(dirname "$0")" || exit 1
printf 'PrintQuote — Apple + Android\n1) Status\n2) Pull updates\n3) Build and test both\n4) Push all edits\n5) Start a feature for both\n'
read -r -p 'Choose 1–5: ' choice
case "$choice" in
  1) ./pq status ;;
  2) ./pq pull ;;
  3) ./pq check ;;
  4) ./pq status; read -r -p 'Commit message (blank cancels): ' message
     if [ -n "$message" ]; then ./pq push --all -m "$message"; fi ;;
  5) read -r -p 'Feature slug (example quote-pdf-export): ' slug
     read -r -p 'Feature title: ' title
     ./pq feature "$slug" "$title" ;;
  *) printf 'Cancelled.\n' ;;
esac
read -r -p 'Press Return to close.' unused
