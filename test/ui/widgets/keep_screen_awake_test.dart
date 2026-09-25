import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/device/screen_awake.dart';
import 'package:violon/ui/widgets/keep_screen_awake.dart';

void main() {
  late FakeScreenKeeper gardien;
  late ScreenAwake ecran;

  setUp(() {
    gardien = FakeScreenKeeper();
    ecran = ScreenAwake(gardien);
  });

  Widget sous(Widget enfant) => ScreenAwakeScope(
        awake: ecran,
        child: MaterialApp(home: enfant),
      );

  testWidgets('sans portee il affiche son enfant et ne reclame rien',
      (WidgetTester tester) async {
    // Le cas de tous les tests d'ecran deja ecrits : ils montent un ecran
    // seul, sans portee. Rien ne doit casser.
    await tester.pumpWidget(
      const MaterialApp(home: KeepScreenAwake(child: Text('la partition'))),
    );

    expect(find.text('la partition'), findsOneWidget);
    expect(ecran.demandes, 0);
  });

  testWidgets('il reclame a l affichage et rend au demontage',
      (WidgetTester tester) async {
    await tester.pumpWidget(sous(const KeepScreenAwake(child: Text('joue'))));
    expect(gardien.on, isTrue);
    expect(ecran.demandes, 1);

    await tester.pumpWidget(sous(const Text('fini')));
    await tester.pump();
    expect(gardien.toggles, <bool>[true, false]);
  });

  testWidgets('actif faux ne reclame rien, et le passage a vrai rallume',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      sous(const KeepScreenAwake(actif: false, child: Text('a l arret'))),
    );
    expect(gardien.toggles, isEmpty);

    // Ce qui se passe quand on lance le metronome.
    await tester.pumpWidget(
      sous(const KeepScreenAwake(child: Text('a l arret'))),
    );
    expect(gardien.on, isTrue);

    await tester.pumpWidget(
      sous(const KeepScreenAwake(actif: false, child: Text('a l arret'))),
    );
    expect(gardien.toggles, <bool>[true, false]);
  });

  testWidgets('un ecran empile puis referme laisse l ecran allume dessous',
      (WidgetTester tester) async {
    // C'est le scenario qui justifie le compte : on accorde par-dessus une
    // prise en cours, et refermer l'accordeur ne doit pas eteindre l'ecran.
    await tester.pumpWidget(
      sous(
        Builder(
          builder: (BuildContext context) => KeepScreenAwake(
            child: Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext c) => KeepScreenAwake(
                      child: Scaffold(
                        appBar: AppBar(title: const Text('accordeur')),
                      ),
                    ),
                  ),
                ),
                child: const Text('accorder'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(ecran.demandes, 1);

    await tester.tap(find.text('accorder'));
    await tester.pumpAndSettle();
    expect(find.text('accordeur'), findsOneWidget);
    expect(ecran.demandes, 2);
    expect(gardien.toggles, <bool>[true], reason: 'un seul appel au materiel');

    // Retour en arriere : l'ecran du dessous reclame encore.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(ecran.demandes, 1);
    expect(gardien.on, isTrue);
  });
}
