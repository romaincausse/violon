import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/score/smufl.dart';

/// La police est un asset : rien dans le code Dart ne casse si elle
/// disparait du paquet. La partition afficherait des rectangles vides, et
/// aucun autre test ne s'en apercevrait. D'ou ces verifications.
void main() {
  group('asset Bravura', () {
    final File police = File('assets/fonts/Bravura.otf');

    test('la police est livree avec l application', () {
      expect(police.existsSync(), isTrue);
      // Une police musicale complete pese quelques centaines de ko. Un
      // fichier minuscule serait un pointeur Git LFS ou un telechargement
      // interrompu.
      expect(police.lengthSync(), greaterThan(100 * 1024));
    });

    test('le fichier est bien une police OpenType', () {
      final List<int> entete = police.openSync().readSync(4);
      expect(String.fromCharCodes(entete), 'OTTO');
    });

    test('la licence accompagne la police, comme l OFL l exige', () {
      final File licence = File('assets/fonts/Bravura-LICENSE.txt');
      expect(licence.existsSync(), isTrue);
      expect(licence.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });

    test('pubspec declare la famille sous le nom attendu par le code', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: ${Smufl.fontFamily}'));
      expect(pubspec, contains('asset: assets/fonts/Bravura.otf'));
    });
  });
}
