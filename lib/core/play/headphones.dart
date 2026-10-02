/// Ce qui est branche en sortie (lot J5, ADR-016).
enum Headphones {
  /// Un casque filaire ou USB : le micro n'entend pas l'accompagnement, et le
  /// retard de sortie est celui que la calibration a mesure.
  wired,

  /// Un casque Bluetooth : le micro ne l'entend pas non plus, mais son retard
  /// -- souvent deux cents millisecondes -- ne se mesure pas.
  bluetooth,

  /// Le haut-parleur : l'accompagnement entrerait dans le micro (ADR-008).
  none,
}

/// La frontiere avec le systeme pour savoir ce qui est branche.
abstract class HeadphoneProbe {
  Future<Headphones> check();
}

class FakeHeadphoneProbe implements HeadphoneProbe {
  FakeHeadphoneProbe([this.state = Headphones.none]);

  Headphones state;

  @override
  Future<Headphones> check() async => state;
}
