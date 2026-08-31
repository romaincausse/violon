.PHONY: setup format analyze test check core-pur run apk clean scores

setup:
	flutter pub get

format:
	dart format .

analyze:
	flutter analyze --fatal-infos

test:
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

scores:
	node tool/build_scores.mjs

clean:
	flutter clean
