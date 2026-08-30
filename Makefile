.PHONY: setup format analyze test check run apk clean scores

setup:
	flutter pub get

format:
	dart format .

analyze:
	flutter analyze --fatal-infos

test:
	flutter test

check: format analyze test
	@grep -rn "package:flutter/" lib/core/ && \
		(echo "ERREUR : lib/core/ ne doit pas importer Flutter" && exit 1) || \
		echo "OK : lib/core/ est du Dart pur"

run:
	flutter run

apk:
	flutter build apk --release

scores:
	node tool/build_scores.mjs

clean:
	flutter clean
