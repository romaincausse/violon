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
core-pur:
	@if grep -rn "package:flutter/" lib/core/; then \
		echo "ERREUR : lib/core/ ne doit pas importer Flutter"; \
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
