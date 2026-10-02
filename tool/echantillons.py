#!/usr/bin/env python3
# Prepare les echantillons d'instruments de l'application depuis VSCO 2 CE.
#
#   python3 tool/echantillons.py [dossier-de-cache]
#
# Demande numpy, scipy et soundfile (pip install numpy scipy soundfile). Ecrit dans
# assets/sons/ un OGG par echantillon et un index, instruments.json.
#
# Pourquoi un script plutot que des fichiers poses a la main : chaque
# echantillon est **mesure** (sa hauteur reelle, au centieme de hertz), coupe,
# boucle et compresse toujours de la meme facon. Refaire les assets doit
# redonner les memes assets.
#
# Sources :
#  - VSCO 2 Community Edition, Versilian Studios, CC0 1.0
#    https://github.com/sgossner/VSCO-2-CE
#  - Salamander Grand Piano V3, Alexander Holm, CC BY 3.0
#    https://github.com/sfzinstruments/SalamanderGrandPiano
#
# Sans Python equipe sous la main : la meme chose dans un conteneur, avec
# l'image decrite dans `docs/decisions.md` (ADR-017) :
#   docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/w \
#     -v ~/.cache/violon-vsco:/cache -w /w violon-sons python3 tool/echantillons.py /cache
import json
import os
import sys
import urllib.parse
import urllib.request

from fractions import Fraction
from math import gcd

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, 'assets', 'sons')
DEPOT = 'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/master/'
SALAMANDER = ('https://raw.githubusercontent.com/sfzinstruments/'
              'SalamanderGrandPiano/master/Samples/')
# Niveau efficace commun, bien sous la saturation : l'accompagnement additionne
# plusieurs voix, et un accord de piano ne doit pas ecreter.
NIVEAU = 0.06
# **Le taux du moteur de son, qui est celui du telephone.** La premiere
# version livrait du 32 kHz dans un moteur a 44,1 kHz, que l'appareil sortait
# a 48 kHz : deux reechantillonnages a l'execution, lineaires tous les deux
# (c'est tout ce que SoLoud sait faire), chacun repliant l'aigu en
# sifflements. A 48 kHz de bout en bout, une note lue a sa hauteur n'est
# reechantillonnee nulle part (ADR-017).
TAUX = 48000

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
#
# **Toujours la nuance la plus nette.** La premiere version prenait le violon
# joue piano : chaque note y commence par un crescendo, et l'attaque mettait
# plus d'une seconde a venir -- molle a l'oreille, et en retard sur le temps
# dans l'accompagnement. Le niveau est de toute facon remis au meme, seule
# l'attaque change : forte pour le violon, la plus forte pour le violoncelle
# et la clarinette, mezzo-forte pour le piano (plus timbre que le pianissimo,
# aussi rapide).
def piano():
    # Salamander Grand Piano V3 : un Yamaha C5 de concert, un echantillon
    # tous les trois demi-tons, seize nuances. Le piano droit de VSCO sonnait
    # boite a chaussures, et c'est le piano que l'eleve entend le plus. La
    # neuvieme nuance : un mezzo-forte franc, sans le bruit de marteau des
    # fortissimos. De la2 au do7 : la basse d'un accompagnement et bien
    # au-dela de la melodie d'un violon.
    noms = [f'{n}{o}' for o in range(1, 8) for n in ('A', 'C', 'D#', 'F#')]
    return [(SALAMANDER + urllib.parse.quote(f'{n}v9.flac'), midi_de(n))
            for n in noms if 33 <= midi_de(n) <= 96]


def violon():
    noms = ['G3', 'A3', 'C4', 'E4', 'G4', 'A4', 'C5', 'E5', 'G5', 'A5',
            'C6', 'E6', 'G6', 'A6']
    return [(f'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_{n}_f.wav', midi_de(n))
            for n in noms]


def violoncelle():
    # Les noms de ce dossier sont decales d'une octave : C1 est le do grave
    # du violoncelle (do2). La mesure le confirmera.
    noms = ['C1', 'E1', 'G1', 'B1', 'D2', 'F2', 'A2', 'C3', 'E3', 'G3',
            'B3', 'D4', 'F4']
    return [(f'Strings/Cello Section/susvib/susvib_{n}_v3_1.wav',
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
    return [(f'Woodwinds/Clarinet/susLong/DCClar_susLong_{n}_v3_rr1_sum.wav',
             midi_de(n, 12)) for n in noms]


INSTRUMENTS = {
    # id: (liste, tient la note, nom affiche, pas entre deux notes livrees)
    #
    # **Un fichier par note livree, transposes ici et pas dans le telephone.**
    # Le moteur ne sait transposer qu'en interpolant lineairement entre deux
    # echantillons, ce qui replie l'aigu : trois demi-tons de transposition a
    # l'execution s'entendaient, surtout sur le piano. Ici la transposition
    # passe par un filtre polyphase propre, et le moteur lit chaque note a sa
    # vitesse, ou presque (le diapason mesure, a quelques cents pres). Le
    # piano, riche en transitoires, est livre chromatique ; les instruments
    # tenus tous les deux demi-tons, un demi-ton d'ecart au plus a
    # l'execution.
    'piano': (piano, False, 'Piano', 1),
    'violon': (violon, True, 'Violon', 2),
    'violoncelle': (violoncelle, True, 'Violoncelle', 2),
    'flute': (flute, True, 'Flute', 2),
    'orgue': (orgue, True, 'Orgue', 2),
    'clarinette': (clarinette, True, 'Clarinette', 2),
}


def telecharger(chemin, cache):
    url = chemin if chemin.startswith('http') else DEPOT + urllib.parse.quote(chemin)
    local = os.path.join(cache, chemin.split('/master/')[-1].replace('/', '__'))
    if not os.path.exists(local):
        urllib.request.urlretrieve(url, local)
    return local


def transposer(x, demi_tons):
    # Transposition hors ligne : lire plus vite, c'est garder moins
    # d'echantillons. Le rapport 2^(k/12) est approche par une fraction, a
    # moins d'un dixieme de cent pres, et le filtre polyphase fait le reste --
    # la ou le moteur, lui, interpolerait entre deux echantillons.
    if demi_tons == 0:
        return x
    r = Fraction(2 ** (demi_tons / 12)).limit_denominator(2000)
    return resample_poly(x, r.denominator, r.numerator)


def reechantillonner(x, sr):
    # Filtre polyphase : une interpolation lineaire replierait l'aigu en
    # sifflements, audibles sur une note tenue.
    if sr == TAUX:
        return x
    g = gcd(TAUX, sr)
    return resample_poly(x, TAUX // g, sr // g)


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
    # Le son commence la ou il est deja la : a 20 % de son niveau, pas au
    # premier frottement. Un archet qui s'installe, un souffle qui s'etablit
    # durent parfois un quart de seconde ; ce qu'on attend d'un
    # accompagnement, c'est la note, a l'heure.
    env = enveloppe(x, TAUX, fenetre=0.02)
    reference = env[:int(2.0 * TAUX)].max()
    i = int(np.argmax(env > reference * SEUIL_DEBUT))
    return max(0, i - int(0.003 * TAUX))


def raffermir(x):
    # Ce qui reste d'une attaque lente, une fois le debut coupe, n'est plus un
    # silence : c'est une houle -- l'archet qui s'installe, le pupitre de
    # violoncelles qui s'accorde en jouant. On la releve, comme le bouton
    # "attaque" d'un echantillonneur : le niveau doit atteindre 70 % en
    # ATTAQUE_CIBLE_MS, en gardant le grain du debut (le mordant de l'archet),
    # simplement plus tot. Le gain est borne : un souffle ne devient pas un
    # coup de canon.
    env = enveloppe(x, TAUX, fenetre=0.02)
    reference = env[:int(2.0 * TAUX)].max()
    cible = 0.7 * reference
    atteint = int(np.argmax(env > cible))
    if atteint == 0:
        return x
    t = np.arange(atteint)
    voulu = cible * np.minimum(1, t / (ATTAQUE_CIBLE_MS * TAUX / 1000))
    gain = np.clip(voulu / np.maximum(env[:atteint], 1e-9), 1, 4)
    lisse = int(0.01 * TAUX)
    gain = np.convolve(
        np.concatenate([gain, np.ones(lisse)]),
        np.ones(lisse) / lisse,
        mode='same',
    )[:atteint]
    y = x.copy()
    y[:atteint] *= np.maximum(gain, 1)
    return y


def attaque_ms(x):
    # Du debut du fichier a 70 % du niveau : ce que l'oreille entend comme
    # l'arrivee de la note.
    env = enveloppe(x, TAUX, fenetre=0.02)
    reference = env[:int(2.0 * TAUX)].max()
    return 1000 * int(np.argmax(env > reference * 0.7)) / TAUX


def enveloppe(x, sr, fenetre=0.2):
    # Niveau efficace glissant, echantillon par echantillon.
    n = int(fenetre * sr)
    h = np.hanning(n)
    h /= h.sum()
    return np.sqrt(np.convolve(x * x, h, mode='same') + 1e-12)


def boucle(x, sr):
    """Une boucle de tenue qui ne s'entend pas.

    Trois defauts s'entendaient sur la premiere version, une boucle courte
    (1,2 s) fondue a l'aveugle : le fondu melangeait deux copies du meme son
    dephasees (un "wah" a chaque tour), et le souffle de l'archet ou de
    l'instrumentiste revenait toutes les 1,2 s. D'ou :

    - **une boucle longue**, prise dans toute la tenue de l'enregistrement
      (jusqu'a cinq secondes) : le vibrato et les irregularites ne se repetent
      plus assez vite pour qu'on les reconnaisse ;
    - **un niveau aplati** sur toute la tenue : plus de houle a chaque tour ;
    - **une fin choisie pour ressembler au debut** : parmi les fins possibles,
      celle dont la forme d'onde correle le mieux avec le point de retour, de
      sorte que le fondu melange deux signaux en phase ;
    - **un fondu lineaire**, le bon pour deux signaux en phase.
    """
    env = enveloppe(x, sr)
    t0 = int(0.6 * sr)
    reference = float(np.median(env[t0:]))
    tenue = np.where(env[t0:] >= 0.5 * reference)[0]
    t1 = t0 + int(tenue[-1]) - int(0.3 * sr)

    # Aplatir le niveau de la tenue, en entrant en douceur apres l'attaque.
    niveau = float(np.median(env[t0:t1]))
    gain = np.ones(len(x))
    gain[t0:] = niveau / np.maximum(env[t0:], niveau * 0.2)
    rampe = int(0.1 * sr)
    gain[t0:t0 + rampe] = 1 + (gain[t0:t0 + rampe] - 1) * np.linspace(0, 1, rampe)
    x = x * gain

    # Le debut **et** la fin qui se ressemblent le mieux : on essaie plusieurs
    # points de depart, et pour chacun la meilleure fin dans la derniere
    # seconde de la tenue.
    w = int(0.04 * sr)
    fin_max = t1 - int(0.35 * sr)
    # Stabilite locale du niveau, en decibels : un creux naturel pres du
    # raccord reviendrait au meme endroit a chaque tour, et se reconnaitrait.
    fine = enveloppe(x, sr, fenetre=0.05)
    d = int(0.2 * sr)

    def houle(c):
        z = fine[max(0, c - d):c + d]
        return 20 * np.log10(z.max() / z.min())

    meilleur = None
    for depart in np.arange(t0 + 0.2 * sr, t0 + 1.2 * sr, 0.1 * sr).astype(int):
        longueur = min(fin_max - depart, int(5.0 * sr))
        if longueur < int(1.0 * sr):
            continue
        modele = x[depart - w:depart + w]
        modele = modele / (np.linalg.norm(modele) + 1e-12)
        e_min = depart + longueur - int(1.0 * sr)
        zone = x[e_min - w:depart + longueur + w]
        corr = np.correlate(zone, modele, mode='valid')
        energie = np.sqrt(np.convolve(zone * zone, np.ones(2 * w), mode='valid'))
        score = corr / (energie + 1e-12)
        # Les dix fins les plus ressemblantes, departagees par la stabilite
        # du niveau autour d'elles et autour du depart.
        for i in np.argsort(score)[-10:]:
            fin = e_min + int(i)
            note = float(score[i]) - 0.08 * (houle(int(depart)) + houle(fin))
            if meilleur is None or note > meilleur[3]:
                meilleur = (int(depart), fin, float(score[i]), note)
    if meilleur is None:
        raise ValueError('tenue trop courte pour boucler')
    a, e, rho, _ = meilleur
    rho = float(np.clip(rho, 0, 1))

    # **Court quand les deux points se ressemblent**, long sinon. Sur un tiers
    # de seconde, deux copies d'un violon derivent l'une par rapport a l'autre
    # jusqu'a s'opposer et s'annuler : un trou de dix decibels au milieu du
    # fondu, que rien ne rattrape. Soixante millisecondes n'en laissent pas le
    # temps. Le fondu long ne sert qu'aux sons sans phase commune -- un pupitre
    # de violoncelles, un orgue dans sa reverberation --, qui ne s'annulent
    # pas.
    fondu = int((0.06 if rho >= 0.6 else 0.35) * sr)
    # Un fondu a puissance constante **quelle que soit la ressemblance** :
    # lineaire pour deux signaux en phase, il creuserait de trois decibels
    # entre deux signaux sans rapport -- un pupitre de violoncelles, un orgue
    # dans sa reverberation. On divise par la puissance attendue du melange.
    corps = x[a:e].copy()
    r = np.linspace(0, 1, fondu)
    melange = x[a:a + fondu] * r + x[e:e + fondu] * (1 - r)
    puissance = np.sqrt(r * r + (1 - r) * (1 - r) + 2 * rho * r * (1 - r))
    melange = melange / puissance
    # Sur un tiers de seconde, deux copies du meme son derivent l'une par
    # rapport a l'autre -- un rien de justesse, un pupitre qui respire -- et
    # s'annulent en partie : un creux de quatre a six decibels au milieu du
    # fondu, a chaque tour. La tenue ayant ete aplatie a un niveau connu, on y
    # ramene le fondu, instant par instant.
    marge = int(0.05 * sr)
    autour = np.concatenate([x[a - marge:a], melange, x[a + fondu:a + fondu + marge]])
    mesure = enveloppe(autour, sr, fenetre=0.05)[marge:marge + fondu]
    melange = melange * np.clip(niveau / mesure, 0.5, 2.0)
    corps[:fondu] = melange
    return np.concatenate([x[:a], corps]), a / sr, rho


def ecart_au_raccord(x, sr, depart):
    # Ce que le raccord ajoute a la houle naturelle de la tenue, en decibels :
    # on rejoue trois tours et on compare la variation de niveau autour des
    # raccords a celle de quarante points pris dans la boucle.
    #
    # **Une fenetre etroite, et beaucoup de points de comparaison.** Une note
    # de violon vit : elle a ses creux de cinq decibels, n'importe ou. Une
    # fenetre large autour du raccord en attrapait un, a un dixieme de seconde
    # du raccord, et accusait le raccord d'un creux qui appartenait a la note.
    # Deux dixiemes de seconde de part et d'autre couvrent le plus long fondu.
    a = int(round(depart * sr))
    corps = x[a:]
    y = np.concatenate([x[:a], corps, corps, corps])
    e = enveloppe(y, sr, fenetre=0.05)
    d = int(0.2 * sr)

    def houle(c):
        z = e[c - d:c + d]
        return 20 * np.log10(z.max() / z.min())

    raccords = max(houle(a + len(corps)), houle(a + 2 * len(corps)))
    ailleurs = [houle(a + len(corps) + int(f * len(corps)))
                for f in np.linspace(0.05, 0.95, 40)]
    return raccords - float(np.median(ailleurs))


# Ou commence un echantillon, en part de son niveau.
SEUIL_DEBUT = 0.2

# Ce qu'on vise : une note de violon detachee arrive en cinquante
# millisecondes environ.
ATTAQUE_CIBLE_MS = 50

# Au-dela, une attaque s'entend molle, et une note d'accompagnement arrive en
# retard sur le temps.
ATTAQUE_MAX_MS = 150

# Au-dela, un raccord s'entend a chaque tour : on refuse l'echantillon plutot
# que de livrer un bourdon qui hoquette.
ECART_MAX_DB = 2.5


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
        '~/.cache/violon-vsco')
    os.makedirs(cache, exist_ok=True)
    os.makedirs(SORTIE, exist_ok=True)
    index = {'source': 'VSCO 2 Community Edition (CC0 1.0) ; '
                       'Salamander Grand Piano V3 (CC BY 3.0)',
             'instruments': []}
    for ident, (liste, tient, nom, pas) in INSTRUMENTS.items():
        for ancien in os.listdir(SORTIE):
            if ancien.startswith(f'{ident}_'):
                os.remove(os.path.join(SORTIE, ancien))
        echantillons = []
        brut = []
        for chemin, attendu in liste():
            x, sr = sf.read(telecharger(chemin, cache), always_2d=True)
            x = reechantillonner(x.mean(axis=1), sr)
            x = x[debut(x):]
            # Trois millisecondes d'entree en fondu : couper une forme d'onde
            # en plein vol ferait un clic.
            entree_fondu = int(0.003 * TAUX)
            x[:entree_fondu] *= np.linspace(0, 1, entree_fondu)
            x = raffermir(x)
            ms = attaque_ms(x)
            if ms > ATTAQUE_MAX_MS:
                raise SystemExit(f'{chemin}: attaque trop lente ({ms:.0f} ms)')
            hz = hauteur(x, TAUX, attendu)
            ecart = 1200 * np.log2(hz / (440 * 2 ** ((attendu - 69) / 12)))
            if abs(ecart) > 60:
                raise SystemExit(f'{chemin}: {hz:.1f} Hz, {ecart:+.0f} cents '
                                 f'de la note attendue')
            brut.append((chemin, attendu, x))
        # Meme niveau pour tous : sinon la melodie monterait et baisserait
        # d'un echantillon a l'autre.
        niveaux = [np.sqrt(np.mean(x[:int(1.5 * TAUX)] ** 2)) for *_, x in brut]
        brut = [(chemin, attendu, x * (NIVEAU / niveau))
                for (chemin, attendu, x), niveau in zip(brut, niveaux)]
        # Les notes livrees : du grave a l'aigu des enregistrements, par pas,
        # chacune depuis l'enregistrement le plus proche.
        grave = min(m for _, m, _ in brut)
        aigu = max(m for _, m, _ in brut)
        for note in range(grave, aigu + 1, pas):
            chemin, source, x = min(brut, key=lambda b: abs(b[1] - note))
            x = transposer(x, note - source)
            # On mesure la note livree, pas la note d'origine : c'est elle
            # que le moteur lira.
            hz = hauteur(x, TAUX, note)
            # Le fichier doit s'arreter exactement la ou la boucle repart : le
            # decodeur OGG ne doit rien ajouter, ce que verifie le test.
            entree = {'midi': note, 'hz': round(hz, 3)}
            if tient:
                x, depart, ressemblance = boucle(x, TAUX)
                entree['loopStart'] = round(depart, 4)
                ecart = ecart_au_raccord(x, TAUX, depart)
                if ecart > ECART_MAX_DB:
                    raise SystemExit(f'{chemin} -> {note}: le raccord de '
                                     f'boucle s entend ({ecart:+.1f} dB, '
                                     f'ressemblance {ressemblance:.2f})')
            else:
                # Un piano de concert resonne longtemps ; cinq secondes
                # couvrent une ronde lente, le moteur eteint le reste.
                x = x[:int(5.0 * TAUX)]
                queue = int(0.6 * TAUX)
                x[-queue:] *= np.linspace(1, 0, queue)
            fichier = f'{ident}_{note}.ogg'
            entree['file'] = fichier
            echantillons.append(entree)
            sf.write(os.path.join(SORTIE, fichier), x.clip(-1, 1), TAUX,
                     format='OGG', subtype='VORBIS')
        index['instruments'].append({'id': ident, 'name': nom,
                                     'sustains': tient,
                                     'samples': echantillons})
        print(f'{nom}: {len(echantillons)} echantillons', flush=True)
    with open(os.path.join(SORTIE, 'instruments.json'), 'w') as f:
        json.dump(index, f, indent=1)


if __name__ == '__main__':
    main()
