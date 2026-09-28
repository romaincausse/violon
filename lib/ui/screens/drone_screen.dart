import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/music/pitch_utils.dart';
import '../../core/play/audio_engine.dart';
import '../../core/play/drone.dart';
import '../../core/play/instrument.dart';
import '../widgets/keep_screen_awake.dart';

/// Le bourdon.
///
/// **L'exercice de justesse le plus efficace qui existe pour un instrument a
/// cordes, et le seul de l'application ou elle ne juge rien.** Une note tenue,
/// l'enfant joue contre, et les battements lui disent tout : il corrige seul, a
/// l'oreille, sans qu'aucun ecran ne lui annonce qu'il est faux. C'est l'exact
/// inverse d'un score, et c'est pour ca que ca marche.
///
/// **Mode d'entrainement, pas de notation (ADR-008).** L'application emet, donc
/// elle n'ecoute pas : le micro reste ferme ici, et rien n'est note.
class DroneScreen extends StatefulWidget {
  const DroneScreen({
    required this.engine,
    this.a4 = PitchUtils.defaultA4,
    super.key,
  });

  /// Le moteur de son, tenu par la coquille de navigation : deux ecrans ne
  /// doivent pas ouvrir deux fois le materiel audio.
  final AudioEngine engine;

  /// Diapason mesure sur les cordes a vide.
  final double a4;

  static const Key jouerKey = Key('bourdon-jouer');
  static const Key quinteKey = Key('bourdon-quinte');
  static const Key volumeKey = Key('bourdon-volume');

  static Key noteKey(int pitchClass) => Key('bourdon-note-$pitchClass');

  /// Le choix du son : `null` pour le son synthetique.
  static Key sonKey(String? instrument) =>
      Key('bourdon-son-${instrument ?? 'synthetique'}');

  @override
  State<DroneScreen> createState() => _DroneScreenState();
}

class _DroneScreenState extends State<DroneScreen> {
  late Drone _bourdon = Drone(pitchClass: Drone.sol, a4: widget.a4);
  double _volume = 0.3;
  bool _sonne = false;

  /// Une voix par frequence : la tonique, et la quinte si on la veut.
  final List<DroneVoice> _voix = <DroneVoice>[];

  /// L'instrument du bourdon, ou `null` pour le son synthetique.
  ///
  /// **Le synthetique reste le premier choix**, et ce n'est pas par defaut :
  /// une dent de scie est riche en harmoniques, donc en battements, et le
  /// battement est tout l'interet du bourdon. Un violoncelle ou un orgue sont
  /// plus agreables a entendre longtemps ; c'est a l'eleve d'arbitrer.
  String? _instrument;

  List<Instrument> _instruments = const <Instrument>[];

  @override
  void initState() {
    super.initState();
    unawaited(_chargerLesInstruments());
  }

  Future<void> _chargerLesInstruments() async {
    final InstrumentLibrary lib = await widget.engine.instruments();
    if (mounted) {
      setState(() => _instruments = lib.sustaining);
    }
  }

  /// Ramene une frequence dans la tessiture de l'instrument choisi, par
  /// octaves : un bourdon de sol grave confie a une flute monte d'une octave
  /// plutot que de devenir meconnaissable. Les battements, eux, restent.
  double _dansLaTessiture(double hz) {
    Instrument? choisi;
    for (final Instrument i in _instruments) {
      if (i.id == _instrument) {
        choisi = i;
      }
    }
    if (choisi == null) {
      return hz;
    }
    final double bas =
        PitchUtils.midiToFrequency(choisi.lowestMidi, a4: widget.a4);
    final double haut =
        PitchUtils.midiToFrequency(choisi.highestMidi, a4: widget.a4);
    double f = hz;
    while (f < bas && f * 2 <= haut) {
      f *= 2;
    }
    while (f > haut && f / 2 >= bas) {
      f /= 2;
    }
    return f;
  }

  Future<void> _changerDeSon(String? instrument) async {
    setState(() => _instrument = instrument);
    if (!_sonne) {
      return;
    }
    await _couper();
    setState(() => _sonne = false);
    await _basculer();
  }

  @override
  void dispose() {
    // Le son ne survit pas a l'ecran. Un bourdon qui continue derriere la
    // seance serait le pire bogue possible ici : l'application emettrait
    // pendant qu'elle note.
    unawaited(_couper());
    super.dispose();
  }

  Future<void> _couper() async {
    final List<DroneVoice> aArreter = List<DroneVoice>.of(_voix);
    _voix.clear();
    for (final DroneVoice voix in aArreter) {
      await voix.stop();
    }
  }

  Future<void> _basculer() async {
    if (_sonne) {
      setState(() => _sonne = false);
      await _couper();
      return;
    }
    setState(() => _sonne = true);
    await widget.engine.start();
    for (final double hz in _bourdon.frequencies) {
      if (!mounted || !_sonne) {
        return;
      }
      _voix.add(
        await widget.engine.startDrone(
          frequencyHz: _dansLaTessiture(hz),
          volume: _volume,
          instrument: _instrument,
        ),
      );
    }
  }

  /// Change la note **sans couper le son** : on cherche sa tonalite en
  /// glissant, pas en rallumant.
  Future<void> _choisir(int pitchClass) async {
    setState(() => _bourdon = _bourdon.copyWith(pitchClass: pitchClass));
    if (!_sonne) {
      return;
    }
    final List<double> hz = _bourdon.frequencies;
    if (hz.length != _voix.length) {
      await _couper();
      setState(() => _sonne = false);
      await _basculer();
      return;
    }
    for (int i = 0; i < _voix.length; i++) {
      await _voix[i].setFrequency(_dansLaTessiture(hz[i]));
    }
  }

  Future<void> _basculerLaQuinte(bool avec) async {
    setState(() => _bourdon = _bourdon.copyWith(withFifth: avec));
    if (!_sonne) {
      return;
    }
    // Le nombre de voix change : on relance, c'est le seul cas ou le son est
    // coupe une fraction de seconde.
    await _couper();
    setState(() => _sonne = false);
    await _basculer();
  }

  Future<void> _reglerLeVolume(double volume) async {
    setState(() => _volume = volume);
    for (final DroneVoice voix in _voix) {
      await voix.setVolume(volume);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KeepScreenAwake(
      actif: _sonne,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bourdon')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: <Widget>[
                    Text(
                      'Joue ta gamme par-dessus. Quand les battements disparaissent, '
                      'tu es juste.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (int n = 0; n < Drone.names.length; n++)
                          ChoiceChip(
                            key: DroneScreen.noteKey(n),
                            label: Text(Drone.names[n]),
                            selected: _bourdon.pitchClass == n,
                            onSelected: (bool choisi) {
                              if (choisi) {
                                unawaited(_choisir(n));
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Le son', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          key: DroneScreen.sonKey(null),
                          label: const Text('Synthetique'),
                          selected: _instrument == null,
                          onSelected: (bool oui) {
                            if (oui) {
                              unawaited(_changerDeSon(null));
                            }
                          },
                        ),
                        for (final Instrument i in _instruments)
                          ChoiceChip(
                            key: DroneScreen.sonKey(i.id),
                            label: Text(i.name),
                            selected: _instrument == i.id,
                            onSelected: (bool oui) {
                              if (oui) {
                                unawaited(_changerDeSon(i.id));
                              }
                            },
                          ),
                      ],
                    ),
                    if (_instrument == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Le plus riche en battements : le meilleur pour '
                          'entendre la justesse.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: DroneScreen.quinteKey,
                      contentPadding: EdgeInsets.zero,
                      value: _bourdon.withFifth,
                      onChanged: (bool v) => unawaited(_basculerLaQuinte(v)),
                      title: const Text('Avec la quinte'),
                      subtitle: const Text('Quinte pure, celle du violon'),
                    ),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.volume_down, size: 20),
                        Expanded(
                          child: Slider(
                            key: DroneScreen.volumeKey,
                            value: _volume,
                            max: 0.8,
                            divisions: 16,
                            onChanged: (double v) =>
                                unawaited(_reglerLeVolume(v)),
                          ),
                        ),
                        const Icon(Icons.volume_up, size: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.a4 == PitchUtils.defaultA4
                          ? 'Diapason : 440 Hz. Accorde d abord, le bourdon suivra.'
                          : 'Diapason mesure : ${widget.a4.toStringAsFixed(1)} Hz',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rien n est note ici : l application joue, elle n ecoute pas.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Le bouton reste en bas, toujours atteignable : les reglages
              // au-dessus peuvent defiler, pas lui.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  key: DroneScreen.jouerKey,
                  onPressed: () => unawaited(_basculer()),
                  icon: Icon(_sonne ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    _sonne ? 'Arreter' : 'Faire sonner ${_bourdon.label}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
