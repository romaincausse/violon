#!/bin/sh
# Rapatrie les prises du banc d'essai depuis le telephone, puis les y efface.
#
# Les prises vivent dans le dossier prive de l'application (version de debug),
# que seul `run-as` sait lire. Elles arrivent dans $VIOLON_BANC/prises, hors
# du depot : elles n'y entrent jamais (docs/banc-d-essai.md, regle zero).
#
# Une prise n'est effacee du telephone qu'une fois copiee et de la bonne
# taille ; une prise deja presente dans le banc n'est jamais ecrasee.
set -eu

BANC="${VIOLON_BANC:-$HOME/violon-banc}"
PAQUET=com.romaincausse.violon
# adb n'est pas toujours dans le PATH : on prend celui du SDK a defaut.
if ! command -v adb >/dev/null 2>&1; then
  PATH="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:$PATH"
fi
mkdir -p "$BANC/prises"

liste=$(adb shell run-as "$PAQUET" ls banc 2>/dev/null | tr -d '\r' | grep '\.wav$' || true)
if [ -z "$liste" ]; then
  echo "Aucune prise sur le telephone."
  exit 0
fi

for f in $liste; do
  cible="$BANC/prises/$f"
  if [ -e "$cible" ]; then
    echo "$f : deja dans le banc, laissee sur le telephone."
    continue
  fi
  adb exec-out run-as "$PAQUET" cat "banc/$f" > "$cible.part"
  attendu=$(adb shell run-as "$PAQUET" stat -c %s "banc/$f" | tr -d '\r')
  recu=$(wc -c < "$cible.part" | tr -d ' ')
  if [ "$attendu" != "$recu" ]; then
    rm -f "$cible.part"
    echo "$f : copie incomplete ($recu sur $attendu octets), laissee sur le telephone." >&2
    continue
  fi
  mv "$cible.part" "$cible"
  adb shell run-as "$PAQUET" rm "banc/$f"
  echo "$f : rapatriee ($(( recu / 88200 )) s), effacee du telephone."
done
