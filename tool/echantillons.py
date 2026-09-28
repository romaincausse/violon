#!/usr/bin/env python3
# Prepare les echantillons d'instruments de l'application depuis VSCO 2 CE.
#
#   python3 tool/echantillons.py [dossier-de-cache]
#
# Demande numpy et soundfile (pip install numpy soundfile). Ecrit dans
# assets/sons/ un OGG par echantillon et un index, instruments.json.
#
# Pourquoi un script plutot que des fichiers poses a la main : chaque
# echantillon est **mesure** (sa hauteur reelle, au centieme de hertz), coupe,
# boucle et compresse toujours de la meme facon. Refaire les assets doit
# redonner les memes assets.
#
# Source : VSCO 2 Community Edition, Versilian Studios, CC0 1.0.
# https://github.com/sgossner/VSCO-2-CE
import json
import os
import sys
import urllib.parse
import urllib.request

import numpy as np
import soundfile as sf

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, 'assets', 'sons')
DEPOT = 'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/master/'
# Niveau efficace commun, bien sous la saturation : l'accompagnement additionne
# plusieurs voix, et un accord de piano ne doit pas ecreter.
NIVEAU = 0.06
TAUX = 32000  # Assez pour un violon (harmoniques utiles sous 12 kHz), moitie moins lourd.

NOTES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi_de(nom, decalage=0):
    # 'A#3' -> 70 + decalage d'octave propre a l'instrument
    lettre, reste = nom[0], nom[1:]
    alt = 0
    if reste.startswith('#'):
        alt, reste = 1, reste[1:]
    return (int(reste) + 1) * 12 + NOTES[lettre] + alt + decalage


# (fichier, midi nominal). Un echantillon tous les trois a cinq demi-tons :
# au-dela de trois demi-tons de transposition, un timbre se deforme.
def piano():
    carte = [21 + 2 * i for i in range(44)] + [108]
    return [(f'Keys/Upright Piano/Player_dyn1_rr1_{i:03d}.wav', m)
            for i, m in enumerate(carte) if 37 <= m <= 101 and (m - 37) % 4 == 0]


def violon():
    noms = ['G3', 'A3', 'C4', 'E4', 'G4', 'A4', 'C5', 'E5', 'G5', 'A5',
            'C6', 'E6', 'G6', 'A6']
    return [(f'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_{n}_p.wav', midi_de(n))
            for n in noms]


def violoncelle():
    # Les noms de ce dossier sont decales d'une octave : C1 est le do grave
    # du violoncelle (do2). La mesure le confirmera.
    noms = ['C1', 'E1', 'G1', 'B1', 'D2', 'F2', 'A2', 'C3', 'E3', 'G3',
            'B3', 'D4', 'F4']
    return [(f'Strings/Cello Section/susvib/susvib_{n}_v1_1.wav',
             midi_de(n, 12)) for n in noms]


def flute():
    noms = ['C3', 'E3', 'A3', 'C4', 'E4', 'A4', 'C5', 'E5', 'A5', 'C6']
    return [(f'Woodwinds/Flute/susvib/LDFlute_susvib_{n}_v1_1.wav',
             midi_de(n, 12)) for n in noms]


def orgue():
    # Man3Open_01 est le do2 ; un fichier tous les trois demi-tons.
    return [(f'Keys/Organ/Loud/Rode_Man3Open_{i:02d}.wav', 35 + i)
            for i in range(1, 62, 3) if 36 <= 35 + i <= 96 and (i - 1) % 6 == 0]


def clarinette():
    # F#5 manque : le fichier de ce nom sonne fa, la mesure l'a refuse.
    noms = ['D2', 'F2', 'A#2', 'D3', 'F3', 'A#3', 'D4', 'F4', 'A#4', 'D5']
    return [(f'Woodwinds/Clarinet/susLong/DCClar_susLong_{n}_v2_rr1_sum.wav',
             midi_de(n, 12)) for n in noms]


INSTRUMENTS = {
    # id: (liste, tient la note, nom affiche)
    'piano': (piano, False, 'Piano'),
    'violon': (violon, True, 'Violon'),
    'violoncelle': (violoncelle, True, 'Violoncelle'),
    'flute': (flute, True, 'Flute'),
    'orgue': (orgue, True, 'Orgue'),
    'clarinette': (clarinette, True, 'Clarinette'),
}


def telecharger(chemin, cache):
    local = os.path.join(cache, chemin.replace('/', '__'))
    if not os.path.exists(local):
        url = DEPOT + urllib.parse.quote(chemin)
        urllib.request.urlretrieve(url, local)
    return local


def reechantillonner(x, sr):
    if sr == TAUX:
        return x
    n = int(round(len(x) * TAUX / sr))
    t = np.linspace(0, len(x) - 1, n)
    return np.interp(t, np.arange(len(x)), x)


def hauteur(x, sr, attendu):
    # Pic du spectre pres de la fondamentale attendue, sur la partie tenue :
    # on mesure l'accord reel de l'echantillon, pas sa note. Le spectre est
    # tres suralimente en zeros (un dixieme de hertz par case) et le pic
    # interpole : une autocorrelation manquait de finesse dans l'aigu, ou une
    # periode ne fait qu'une quinzaine d'echantillons.
    seg = x[int(0.3 * sr):int(1.3 * sr)]
    seg = (seg - seg.mean()) * np.hanning(len(seg))
    n = 1 << 19
    spectre = np.log(np.abs(np.fft.rfft(seg, n)) + 1e-12)
    f0 = 440 * 2 ** ((attendu - 69) / 12)
    lo = int(f0 / 1.06 * n / sr)
    hi = int(f0 * 1.06 * n / sr)
    i = lo + int(np.argmax(spectre[lo:hi]))
    a, b, c = spectre[i - 1], spectre[i], spectre[i + 1]
    i = i + 0.5 * (a - c) / (a - 2 * b + c)
    return i * sr / n


def debut(x):
    seuil = np.max(np.abs(x)) * 10 ** (-40 / 20)
    i = int(np.argmax(np.abs(x) > seuil))
    return max(0, i - int(0.005 * TAUX))


def boucle(x, sr, depart=0.9, longueur=1.2, fondu=0.25):
    # Une boucle sans couture : la fin du corps se fond dans son debut.
    a = int(depart * sr)
    n = int(longueur * sr)
    f = int(fondu * sr)
    corps = x[a:a + n].copy()
    queue = x[a + n:a + n + f]
    if len(queue) < f:
        raise ValueError('echantillon trop court pour boucler')
    r = np.linspace(0, 1, f)
    corps[:f] = corps[:f] * np.sqrt(r) + queue * np.sqrt(1 - r)
    return np.concatenate([x[:a], corps]), a / sr


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
        '~/.cache/violon-vsco')
    os.makedirs(cache, exist_ok=True)
    os.makedirs(SORTIE, exist_ok=True)
    index = {'source': 'VSCO 2 Community Edition (CC0 1.0)',
             'instruments': []}
    for ident, (liste, tient, nom) in INSTRUMENTS.items():
        echantillons = []
        brut = []
        for chemin, attendu in liste():
            x, sr = sf.read(telecharger(chemin, cache), always_2d=True)
            x = reechantillonner(x.mean(axis=1), sr)
            x = x[debut(x):]
            hz = hauteur(x, TAUX, attendu)
            ecart = 1200 * np.log2(hz / (440 * 2 ** ((attendu - 69) / 12)))
            if abs(ecart) > 60:
                raise SystemExit(f'{chemin}: {hz:.1f} Hz, {ecart:+.0f} cents '
                                 f'de la note attendue')
            brut.append((chemin, attendu, hz, x))
        # Meme niveau pour tous : sinon la melodie monterait et baisserait
        # d'un echantillon a l'autre.
        niveaux = [np.sqrt(np.mean(x[:int(1.5 * TAUX)] ** 2)) for *_, x in brut]
        for (chemin, attendu, hz, x), niveau in zip(brut, niveaux):
            x = x * (NIVEAU / niveau)
            entree = {'midi': attendu, 'hz': round(hz, 3)}
            if tient:
                x, depart = boucle(x, TAUX)
                entree['loopStart'] = round(depart, 4)
            else:
                x = x[:int(3.0 * TAUX)]
                x[-int(0.3 * TAUX):] *= np.linspace(1, 0, int(0.3 * TAUX))
            fichier = f'{ident}_{attendu}.ogg'
            entree['file'] = fichier
            echantillons.append(entree)
            sf.write(os.path.join(SORTIE, fichier), x.clip(-1, 1), TAUX,
                     format='OGG', subtype='VORBIS')
        index['instruments'].append({'id': ident, 'name': nom,
                                     'sustains': tient,
                                     'samples': echantillons})
        print(f'{nom}: {len(echantillons)} echantillons')
    with open(os.path.join(SORTIE, 'instruments.json'), 'w') as f:
        json.dump(index, f, indent=1)


if __name__ == '__main__':
    main()
