#!/usr/bin/env bash
# Ratatouille PC - the settings window on Linux (zenity), like "Ratatouille PC - Config.exe" on Windows:
# picture settings, PLAY with them, or Import ISO (the installer). Nothing installed yet: the installer opens straight away.
# The settings are kept in engine/ratatouille-linux.conf; play.sh starts the game with them.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/ui.sh"

if [ "$gui" != 1 ]; then
  echo "$(t 'This window needs a desktop with zenity. From a terminal, the same settings are options of play.sh:' 'Esta ventana necesita un escritorio con zenity. Desde la terminal, las mismas opciones son de play.sh:')" >&2
  sed -n '3,5p' "$here/play.sh" >&2
  exit 1
fi

# a combo box's values with the current one first (zenity starts on the first)
first_then() { local cur="$1" v out; shift; out="$cur"; for v in "$@"; do [ "$v" = "$cur" ] || out="$out|$v"; done; printf '%s' "$out"; }
yes_no() { if [ "$1" = 1 ] || [ "$1" = on ]; then t 'Yes' 'Sí'; else t 'No' 'No'; fi; }
is_yes() { [ "$1" = "$(t 'Yes' 'Sí')" ]; }

looks_ids=(sharp_edges sharp crisp_edges crisp soft_edges soft)
looks_names=('Sharp + smooth edges' 'Sharp' 'Crisp + smooth edges' 'Crisp' 'Soft + smooth edges' 'Soft')
lang_ids=(3 1 2 4 5 6)
lang_names=('Español' 'English' 'Français' 'Deutsch' 'Italiano' 'Nederlands')
import_label="$(t 'Import ISO...' 'Importar ISO...')"

while true; do
  games=($(installed_games))
  if [ ${#games[@]} -eq 0 ]; then
    bash "$here/install.sh"
    games=($(installed_games)); [ ${#games[@]} -gt 0 ] || exit 0
  fi
  version="$(conf_get version)"; [ -n "$version" ] || version="${games[0]}"
  scale="$(conf_get scale)"; [ -n "$scale" ] || scale=2   # 4x makes some of this game's scene changes stutter
  look="$(conf_get look)"; [ -n "$look" ] || look=sharp_edges
  vsync="$(conf_get vsync)"; [ -n "$vsync" ] || vsync=on
  full="$(conf_get full)"; [ -n "$full" ] || full=1
  lang="$(conf_get lang)"; [ -n "$lang" ] || { [ "$es" = 1 ] && lang=3 || lang=1; }

  look_name="${looks_names[0]}"; for i in "${!looks_ids[@]}"; do [ "${looks_ids[$i]}" = "$look" ] && look_name="${looks_names[$i]}"; done
  lang_name="${lang_names[0]}"; for i in "${!lang_ids[@]}"; do [ "${lang_ids[$i]}" = "$lang" ] && lang_name="${lang_names[$i]}"; done
  scale_name="${scale}x"; [ "$scale" = 1 ] && scale_name='1x (PS2)'

  fields=()
  has_eu=0; for g in "${games[@]}"; do [ "$g" = ratatouille_eu ] && has_eu=1; done
  if [ ${#games[@]} -gt 1 ]; then
    v_eu="$(t 'Europe (Spanish, Portuguese)' 'Europa (español, portugués)')"; v_us="$(t 'USA / Latin America (English)' 'USA / Latinoamérica (inglés)')"
    fields+=(--add-combo="$(t 'Version' 'Versión')" --combo-values="$(first_then "$([ "$version" = ratatouille_us ] && echo "$v_us" || echo "$v_eu")" "$v_eu" "$v_us")")
  fi
  fields+=(--add-combo="$(t 'Inner resolution' 'Resolución interna')" --combo-values="$(first_then "$scale_name" '1x (PS2)' 2x 3x 4x)")
  fields+=(--add-combo="$(t 'Picture look' 'Estilo de imagen')" --combo-values="$(first_then "$look_name" "${looks_names[@]}")")
  fields+=(--add-combo="$(t 'Vertical sync' 'Sincronización vertical')" --combo-values="$(first_then "$(yes_no "$vsync")" "$(t Yes Sí)" No)")
  fields+=(--add-combo="$(t 'Full screen' 'Pantalla completa')" --combo-values="$(first_then "$(yes_no "$full")" "$(t Yes Sí)" No)")

  out="$(z --forms --width=520 --separator='|' --text="RATATOUILLE  ·  PC  ·  By NyxBorn  ·  v1.1.0" \
         --ok-label="$(t 'PLAY' 'JUGAR')" --cancel-label="$(t 'Quit' 'Salir')" --extra-button="$import_label" "${fields[@]}")"
  rc=$?
  if [ "$out" = "$import_label" ]; then bash "$here/install.sh"; continue; fi
  [ "$rc" = 0 ] || exit 0

  IFS='|' read -r -a got <<< "$out"
  i=0
  if [ ${#games[@]} -gt 1 ]; then
    case "${got[$i]}" in USA*) conf_set version ratatouille_us ;; *) conf_set version ratatouille_eu ;; esac; i=$((i + 1))
  else
    conf_set version "${games[0]}"
  fi
  case "${got[$i]:-}" in 1x*) conf_set scale 1 ;; 2x) conf_set scale 2 ;; 3x) conf_set scale 3 ;; 4x) conf_set scale 4 ;; esac; i=$((i + 1))
  for j in "${!looks_names[@]}"; do [ "${looks_names[$j]}" = "${got[$i]:-}" ] && conf_set look "${looks_ids[$j]}"; done; i=$((i + 1))
  [ -n "${got[$i]:-}" ] && { is_yes "${got[$i]}" && conf_set vsync on || conf_set vsync off; }; i=$((i + 1))
  [ -n "${got[$i]:-}" ] && { is_yes "${got[$i]}" && conf_set full 1 || conf_set full 0; }
  exec bash "$here/play.sh"
done
