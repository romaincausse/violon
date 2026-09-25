import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/device/screen_awake.dart';

void main() {
  group('ScreenAwake', () {
    test('la premiere demande allume, la derniere eteint', () async {
      final FakeScreenKeeper gardien = FakeScreenKeeper();
      final ScreenAwake ecran = ScreenAwake(gardien);

      expect(gardien.toggles, isEmpty);

      await ecran.acquire();
      expect(gardien.toggles, <bool>[true]);

      await ecran.release();
      expect(gardien.toggles, <bool>[true, false]);
    });

    test('les demandes empilees ne touchent le materiel qu aux transitions',
        () async {
      final FakeScreenKeeper gardien = FakeScreenKeeper();
      final ScreenAwake ecran = ScreenAwake(gardien);

      // Trois ecrans empiles : la prise, l'accordeur par-dessus, le bourdon
      // par-dessus encore.
      await ecran.acquire();
      await ecran.acquire();
      await ecran.acquire();
      expect(gardien.toggles, <bool>[true], reason: 'un seul appel');

      // On referme les deux du dessus : l'ecran doit rester allume, la prise
      // le reclame encore.
      await ecran.release();
      await ecran.release();
      expect(ecran.demandes, 1);
      expect(gardien.on, isTrue);

      await ecran.release();
      expect(gardien.toggles, <bool>[true, false]);
    });

    test('un relachement de trop ne rend pas le compte negatif', () async {
      final FakeScreenKeeper gardien = FakeScreenKeeper();
      final ScreenAwake ecran = ScreenAwake(gardien);

      await ecran.release();
      await ecran.release();
      expect(ecran.demandes, 0);
      expect(gardien.toggles, isEmpty, reason: 'rien a eteindre');

      // Et l'ecran suivant qui demande rallume bien : c'est tout l'enjeu d'un
      // compte qui ne descend pas sous zero.
      await ecran.acquire();
      expect(gardien.toggles, <bool>[true]);
    });

    test('pose dit ce qui a ete demande au materiel', () async {
      final ScreenAwake ecran = ScreenAwake(FakeScreenKeeper());
      expect(ecran.pose, isFalse);
      await ecran.acquire();
      expect(ecran.pose, isTrue);
      await ecran.release();
      expect(ecran.pose, isFalse);
    });
  });
}
