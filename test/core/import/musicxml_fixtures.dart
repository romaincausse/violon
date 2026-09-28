/// Fabriques de MusicXML pour les tests : assez pour ecrire une partition
/// en une ligne, sans fichier a cote.
library;

/// Une partition MusicXML minimale autour de [mesures].
String partition(
  String mesures, {
  String entete = '<work><work-title>Essai</work-title></work>',
  String parties = '',
}) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<score-partwise version="4.0">$entete'
    '<part-list><score-part id="P1"><part-name>Violon</part-name>'
    '</score-part></part-list>'
    '<part id="P1">$mesures</part>$parties</score-partwise>';

/// Une note : hauteur a la francaise simplifiee (`G4`, `F#4`, `Bb3`),
/// duree en divisions.
String note(
  String hauteur,
  int duree, {
  String extra = '',
  String notations = '',
}) {
  final String step = hauteur[0];
  final String alter = hauteur.contains('#')
      ? '<alter>1</alter>'
      : hauteur.contains('b')
          ? '<alter>-1</alter>'
          : '';
  final String octave = hauteur[hauteur.length - 1];
  return '<note>$extra<pitch><step>$step</step>$alter'
      '<octave>$octave</octave></pitch><duration>$duree</duration>'
      '<voice>1</voice>'
      '${notations.isEmpty ? '' : '<notations>$notations</notations>'}'
      '</note>';
}

String silence(int duree) =>
    '<note><rest/><duration>$duree</duration><voice>1</voice></note>';

/// Attributs de 6/8 en re majeur, deux divisions par noire.
const String sixHuit = '<attributes><divisions>2</divisions>'
    '<key><fifths>2</fifths></key>'
    '<time><beats>6</beats><beat-type>8</beat-type></time></attributes>';
