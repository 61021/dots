#!/usr/bin/env bash
# Print a random uncommon English word and its definition.
#  word  — part of speech: definition

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
last_cache="$cache_dir/eww-word-last"
mkdir -p "$cache_dir"

# Source word list — prefer the larger system dictionary if present.
for f in /usr/share/dict/american-english-large /usr/share/dict/american-english /usr/share/dict/words /usr/share/dict/cracklib-small; do
  [ -r "$f" ] && words_file="$f" && break
done

pick_word() {
  if [ -n "$words_file" ]; then
    # Plain lowercase words, 7–14 letters, no apostrophes/proper nouns.
    grep -E '^[a-z]{2,14}$' "$words_file" | shuf -n 1
  else
    curl -fsS --max-time 4 \
      "https://random-word-api.herokuapp.com/word?length=9" 2>/dev/null \
      | jq -r '.[0] // empty'
  fi
}

format_def() {
  jq -r '
    .[0] as $e
    | $e.meanings[0] as $m
    | "\($e.word)  — \($m.partOfSpeech): \($m.definitions[0].definition)"
  ' 2>/dev/null
}

for _ in 1 2 3 4 5 6 8; do
  w="$(pick_word)"
  [ -z "$w" ] && continue

  resp="$(curl -fsS --max-time 5 "https://api.dictionaryapi.dev/api/v2/entries/en/$w" 2>/dev/null)"
  [ -z "$resp" ] && continue
  # Skip on API "no definitions found" responses (returns an object, not array).
  case "$resp" in '{'*) continue ;; esac

  out="$(printf '%s' "$resp" | format_def)"
  if [ -n "$out" ] && [ "$out" != "null" ]; then
    printf '%s' "$out" > "$last_cache"
    printf '%s' "$out"
    exit 0
  fi
done

if [ -s "$last_cache" ]; then
  cat "$last_cache"
else
  printf 'serendipity  — noun: the occurrence of events by chance in a happy way.'
fi



