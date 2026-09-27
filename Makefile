.PHONY: setup format analyze test test-lent test-tout check core-pur run apk clean

setup:
	flutter pub get

format:
	dart format .

analyze:
	flutter analyze --fatal-infos

# Les tests etiquetes `lent` (alignement de bout en bout sur la synthese)
# sont exclus de la boucle courante. La CI lance tout, sans exclusion.
test:
	flutter test --exclude-tags lent

test-lent:
	flutter test --tags lent

test-tout:
	flutter test

check: format analyze test core-pur

# Regle d'architecture n1 : lib/core/ reste du Dart pur.
# On interdit tout paquet, pas seulement Flutter : depuis l'arrivee de la
# capture micro, le risque n'est plus d'importer Material, c'est d'importer
# un plugin. Un plugin ne se teste pas sans appareil, ce qui viderait la
# regle de son sens. La couche qui en a besoin vit dans lib/platform/.
core-pur:
	@if grep -rn "^import 'package:" lib/core/; then \
		echo "ERREUR : lib/core/ ne doit dependre d'aucun paquet"; \
		exit 1; \
	fi; \
	echo "OK : lib/core/ est du Dart pur"

run:
	flutter run

apk:
	flutter build apk --release

clean:
	flutter clean
