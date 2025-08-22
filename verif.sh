#!/usr/bin/env bash

# vérifie l’équilibre des blocs dans un script
# Usage: /chemin/vers/votre/script.sh


FILE="$1"
if [[ ! -f "$FILE" ]]; then
  echo "Usage: $0 script.sh" >&2
  exit 1
fi

# Définition des paires à vérifier
declare -A opens=( ["if"]="fi" ["case"]="esac" ["function_open"]="#" )
declare -A opens_patterns=( 
  ["if"]="^\s*if\b" 
  ["case"]="^\s*case\b" 
  ["function_open"]="^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{" 
)
declare -A closes_patterns=( 
  ["if"]="^\s*fi\b" 
  ["case"]="^\s*esac\b" 
  ["function_open"]="^\s*\}" 
)

# Compteurs
declare -A level
for k in "${!opens[@]}"; do level[$k]=0; done

# Lecture du fichier
echo "Scanning $FILE…"
while IFS= read -r line; do
  ((LINENO++))
  for key in "${!opens[@]}"; do
    if [[ $line =~ ${opens_patterns[$key]} ]]; then
      (( level[$key]++ ))
      echo "  +1 ${key} at line $LINENO"
    elif [[ $line =~ ${closes_patterns[$key]} ]]; then
      (( level[$key]-- ))
      echo "  -1 ${key} at line $LINENO"
    fi
  done
done < "$FILE"

# Bilan
echo
ok=true
for key in "${!opens[@]}"; do
  if (( level[$key] != 0 )); then
    echo "!  Déséquilibre pour '$key…${opens[$key]}' : reste $(( level[$key] )) bloc(s) non fermés."
    ok=false
  fi
done

if $ok; then
  echo " Tous les blocs sont équilibrés (if/fi, case/esac, fonctions)."
  exit 0
else
  echo "X Veuillez ajouter/supprimer le(s) bloc(s) manquant(s)."
  exit 2
fi

