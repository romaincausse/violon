import 'package:flutter_test/flutter_test.dart';
import 'package:violon/core/device/screen_awake.dart';
import 'package:violon/platform/device/wakelock_screen_keeper.dart';

void main() {
  // Le canal de plateforme a besoin du binding, comme dans un vrai test de
  // widget : sans lui l'appel echouerait sur une erreur de binding et non sur
  // l'absence de greffon, ce qui ne prouverait rien.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression : ici il n'y a pas de greffon enregistre, donc l'appel natif
  // echoue. Un ecran qui s'eteint est une gene ; une exception qui traverse
  // l'interface pendant que l'enfant joue est pire -- et c'est exactement ce
  // qui arriverait si un jour quelqu'un retirait le try/catch.
  test('n echoue pas quand le greffon natif est absent', () async {
    const ScreenKeeper gardien = WakelockScreenKeeper();

    await expectLater(gardien.toggle(on: true), completes);
    await expectLater(gardien.toggle(on: false), completes);
  });

  test('defaultScreenKeeper rend le gardien reel', () {
    expect(defaultScreenKeeper(), isA<WakelockScreenKeeper>());
  });
}
