#!/usr/bin/env python3
# Le banc d'ecoute (lot J7, ADR-017) : rend l'accompagnement en WAV, **comme
# le telephone le joue**, et le mesure.
#
#   python3 tool/ecoute.py [dossier-de-sortie] [instrument ...]
#
# Pourquoi : celui qui ecrit le code n'a pas d'oreilles sur le S22. Ce banc
# imite le moteur de son -- l'echantillon le plus proche lu a la vitesse qui
# donne la frequence, **en interpolant lineairement comme SoLoud**, la boucle
# de tenue, le relache, les accords egrenes -- et ecrit trois scenes par
# instrument : une note tenue, une gamme, une suite d'accords "oum-pa-pa".
# Puis il mesure ce qu'une oreille reprocherait : les clics, le vrombissement
# de l'aigu replie, la houle d'une boucle qui s'entend, le vibrato qui fait
# battre un accord.
#
# Les chiffres ne remplacent pas l'ecoute : ils disent ou ecouter. Les WAV
# sont la pour ca.
#
# Meme conteneur que tool/echantillons.py :
#   docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/w -w /w violon-sons \
#     python3 tool/ecoute.py /w/build/ecoute
import json
import os
import sys

import numpy as np
import soundfile as sf

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SONS = os.path.join(RACINE, 'assets', 'sons')
TAUX = 48000

# Les constantes du moteur (SoloudAudioEngine) et de la main (Humanizer).
RELACHE_TENU = 0.070
RELACHE_PIANO = 0.600
EGRENAGE_MS = 6
EGRENAGE_MAX_MS = 18
VOLUME = 0.6


def charger(ident):
    index = json.load(open(os.path.join(SONS, 'instruments.json')))
    for i in index['instruments']:
        if i['id'] == ident:
            echantillons = []
            for s in i['samples']:
                x, sr = sf.read(os.path.join(SONS, s['file']))
                assert sr == TAUX, s['file']
                echantillons.append({**s, 'x': x.astype(np.float64)})
            return {**i, 'samples': echantillons}
    raise SystemExit(f'instrument inconnu : {ident}')


def hz_de(midi, a4=440.0):
    return a4 * 2 ** ((midi - 69) / 12)


def plus_proche(instrument, hz):
    return min(instrument['samples'], key=lambda s: abs(np.log(hz / s['hz'])))


def lire(instrument, hz, duree, volume):
    """Une note, comme le moteur la lit : vitesse, boucle, interpolation
    lineaire, relache en fondu lineaire."""
    s = plus_proche(instrument, hz)
    x = s['x']
    vitesse = hz / s['hz']
    tient = instrument['sustains'] and 'loopStart' in s
    relache = RELACHE_TENU if instrument['sustains'] else RELACHE_PIANO
    n = int((duree + relache) * TAUX)
    pos = np.arange(n, dtype=np.float64) * vitesse
    if tient:
        debut = s['loopStart'] * TAUX
        longueur = len(x) - debut
        pos = np.where(pos >= len(x), debut + (pos - debut) % longueur, pos)
    i0 = np.floor(pos).astype(np.int64)
    frac = pos - i0
    valable = i0 + 1 < len(x)
    i0 = np.clip(i0, 0, len(x) - 2)
    y = (x[i0] * (1 - frac) + x[i0 + 1] * frac) * valable
    env = np.ones(n)
    fin = int(duree * TAUX)
    env[fin:] = np.linspace(1, 0, n - fin)
    return y * env * volume


def rendre(instrument, notes, duree_totale):
    """notes : (midi, depart s, duree s, force). Les accords sont egrenes
    comme par le Humanizer."""
    sortie = np.zeros(int(duree_totale * TAUX) + TAUX)
    par_instant = {}
    for n in notes:
        par_instant.setdefault(round(n[1], 6), []).append(n)
    for instant, accord in par_instant.items():
        accord.sort()
        for rang, (midi, depart, duree, force) in enumerate(accord):
            retard = min(rang * EGRENAGE_MS, EGRENAGE_MAX_MS) / 1000
            y = lire(instrument, hz_de(midi), duree, VOLUME * force)
            a = int((depart + retard) * TAUX)
            b = min(a + len(y), len(sortie))
            sortie[a:b] += y[:b - a]
    return sortie


def scene_tenue(instrument):
    # Une note au milieu de la tessiture, six secondes : la boucle y tourne
    # au moins une fois.
    s = instrument['samples']
    midi = s[len(s) // 2]['midi']
    return [(midi, 0.5, 6.0, 0.8)], 7.5


def scene_gamme(instrument):
    # Sol majeur en noires a 100, sur la tessiture disponible.
    s = instrument['samples']
    grave, aigu = s[0]['midi'], s[-1]['midi']
    gamme = [m for m in range(grave, aigu + 1) if m % 12 in (7, 9, 11, 0, 2, 4, 6)]
    gamme = gamme[:15]
    noire = 0.6
    return [(m, 0.5 + i * noire, noire * 0.9, 0.8) for i, m in enumerate(gamme)], \
        1.5 + len(gamme) * noire


def scene_accords(instrument):
    # "Oum-pa-pa" en sol : I, IV, V, I, deux mesures chacun, a 120.
    s = instrument['samples']
    grave, aigu = s[0]['midi'], s[-1]['midi']

    def dans(m):
        while m < grave:
            m += 12
        while m > aigu:
            m -= 12
        return m

    accords = [(55, [67, 71, 74]), (60, [67, 72, 76]), (62, [66, 69, 74]),
               (55, [67, 71, 74])]
    noire = 0.5
    notes = []
    t = 0.5
    for basse, accord in accords:
        for _ in range(2):
            notes.append((dans(basse), t, noire, 0.8))
            for k in (1, 2):
                for m in accord:
                    notes.append((dans(m), t + k * noire, noire * 0.75, 0.55))
            t += 3 * noire
    return notes, t + 1.0


def clics(x):
    # Un saut de plus de 8 % de la pleine echelle d'un echantillon au
    # suivant est un clic, pas de la musique.
    return int(np.sum(np.abs(np.diff(x)) > 0.08))


def aigu_db(x):
    # Part de l'energie au-dessus de 10 kHz : un violon en a peu, un aigu
    # replie par l'interpolation en a trop.
    spectre = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1 / TAUX)
    haut = spectre[f > 10000].sum()
    return 10 * np.log10(haut / spectre.sum() + 1e-12)


def enveloppe(x, fenetre=0.05):
    n = int(fenetre * TAUX)
    h = np.hanning(n)
    h /= h.sum()
    return np.sqrt(np.convolve(x * x, h, mode='same') + 1e-12)


def houle_db(x, depuis, jusqua):
    e = enveloppe(x)[int(depuis * TAUX):int(jusqua * TAUX)]
    return 20 * np.log10(e.max() / e.min())


def vibrato(x, hz, depuis, jusqua):
    """Etendue (cents, du 5e au 95e centile) et vitesse (Hz) du vibrato d'une
    note tenue, par le pic spectral de trames de 50 ms."""
    seg = x[int(depuis * TAUX):int(jusqua * TAUX)]
    n = int(0.05 * TAUX)
    pas = n // 2
    hauteurs = []
    for a in range(0, len(seg) - n, pas):
        tr = seg[a:a + n] * np.hanning(n)
        sp = np.abs(np.fft.rfft(tr, 1 << 16))
        f = np.fft.rfftfreq(1 << 16, 1 / TAUX)
        zone = (f > hz / 1.06) & (f < hz * 1.06)
        i = np.argmax(np.where(zone, sp, 0))
        if 0 < i < len(sp) - 1:
            a_, b_, c_ = np.log(sp[i - 1] + 1e-12), np.log(sp[i] + 1e-12), np.log(sp[i + 1] + 1e-12)
            i = i + 0.5 * (a_ - c_) / (a_ - 2 * b_ + c_)
        hauteurs.append(1200 * np.log2(f[1] * i / hz))
    h = np.array(hauteurs) - np.median(hauteurs)
    etendue = float(np.percentile(h, 95) - np.percentile(h, 5))
    # La vitesse : le pic du spectre de la courbe de hauteur, entre 3 et 9 Hz.
    sp = np.abs(np.fft.rfft(h - h.mean(), 1 << 12))
    f = np.fft.rfftfreq(1 << 12, pas / TAUX)
    zone = (f > 3) & (f < 9)
    vitesse = float(f[np.argmax(np.where(zone, sp, 0))]) if zone.any() else 0.0
    return etendue, vitesse


def main():
    sortie = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RACINE, 'build', 'ecoute')
    os.makedirs(sortie, exist_ok=True)
    index = json.load(open(os.path.join(SONS, 'instruments.json')))
    voulus = sys.argv[2:] or [i['id'] for i in index['instruments']]
    print(f"{'instrument':12} {'scene':8} {'clics':>5} {'aigu dB':>8} {'houle dB':>9} "
          f"{'vibrato c':>9} {'vib Hz':>6}")
    for ident in voulus:
        instrument = charger(ident)
        for nom, scene in (('tenue', scene_tenue), ('gamme', scene_gamme),
                           ('accords', scene_accords)):
            notes, duree = scene(instrument)
            x = rendre(instrument, notes, duree)
            crete = np.abs(x).max()
            if crete > 1:
                x = x / crete
            sf.write(os.path.join(sortie, f'{ident}_{nom}.wav'), x, TAUX, subtype='PCM_16')
            ligne = f'{ident:12} {nom:8} {clics(x):5d} {aigu_db(x):8.1f}'
            # La houle et le vibrato n'ont de sens que sur une note qui
            # tient : un piano s'eteint, c'est sa nature.
            if nom == 'tenue' and instrument['sustains']:
                midi = notes[0][0]
                ligne += f' {houle_db(x, 1.5, 6.0):9.1f}'
                etendue, vitesse = vibrato(x, hz_de(midi), 1.5, 6.0)
                ligne += f' {etendue:9.0f} {vitesse:6.1f}'
            print(ligne, flush=True)


if __name__ == '__main__':
    main()
