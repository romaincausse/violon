#!/usr/bin/env python3
# Une annotation du banc d'essai **independante de l'application** (jalon 5).
#
#   python3 tool/reference.py <banc> <prise> [--images <dossier>] [--tout]
#
# Pourquoi : l'annotation corrigee (docs/banc-d-essai.md) demande une oreille
# humaine qui ecoute chaque prise. Quand elle n'est pas disponible, il faut au
# moins une reference qui ne partage pas les defauts de l'aligneur qu'elle
# doit juger. Celle-ci ne reutilise **rien** de la chaine de l'application :
#
#   - la hauteur vient de pYIN (librosa), pas de YIN ;
#   - les attaques viennent du flux spectral "superflux" de librosa, pas du
#     detecteur de l'application ;
#   - le calage sur la partition est **symbolique** : on decoupe d'abord la
#     prise en notes, puis on aligne la suite des notes jouees sur la suite
#     des notes ecrites, la ou l'application aligne trame par trame avec un
#     modele de Markov.
#
# Elle ecrit <prise>.ref.txt (meme format qu'un export Audacity) et compare
# avec <prise>.app.txt, les marqueurs de l'aligneur. Avec --images, elle
# dessine chaque fenetre ou les deux divergent (--tout : toutes) : le
# spectre, la hauteur jouee, les notes attendues et les deux annotations.
# C'est sur ces images qu'un desaccord se tranche, a defaut d'oreille.
#
# Dans le conteneur violon-banc (python:3.12-slim + numpy, scipy, soundfile,
# librosa, matplotlib) :
#   docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/w -v ~/violon-banc:/banc \
#     -w /w violon-banc python3 tool/reference.py /banc 05-stars-arret-reprise
import json
import os
import sys

import numpy as np

SR = 22050
HOP = 220  # 10 ms
NOMS = ['do', 'do#', 're', 're#', 'mi', 'fa', 'fa#', 'sol', 'sol#', 'la',
        'la#', 'si']


def partition(banc, meta):
    """Les notes de la partition, tenues fusionnees comme le fait
    BenchScore.

    **Toute la partition, pas seulement les mesures de la consigne** : la
    prise 05 devait porter sur les mesures 15 a 22 et commence a la mesure
    8. Une consigne dit ce qu'on a demande, pas ce qui a ete joue."""
    d = json.load(open(os.path.join(banc, 'partitions',
                                    meta['partition'] + '.json')))
    notes = []
    for n in d['notes']:
        if n.get('tie') and notes:
            notes[-1]['fin'] = n['onsetTicks'] + n['durationTicks']
            continue
        notes.append({'id': n['id'], 'midi': n['midi'],
                      'mesure': n['measure'], 'debut': n['onsetTicks'],
                      'fin': n['onsetTicks'] + n['durationTicks'],
                      'slur': n.get('slur')})
    return notes


def analyser(chemin, a4):
    import librosa
    y, _ = librosa.load(chemin, sr=SR, mono=True)
    f0, voise, proba = librosa.pyin(
        y, fmin=180, fmax=2200, sr=SR, frame_length=2048, hop_length=HOP)
    rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=HOP)[0]
    env = librosa.onset.onset_strength(
        y=y, sr=SR, hop_length=HOP, lag=2, max_size=3)
    n = min(len(f0), len(rms), len(env))
    f0, voise, proba, rms, env = f0[:n], voise[:n], proba[:n], rms[:n], env[:n]
    midi = 69 + 12 * np.log2(np.where(np.isfinite(f0) & (f0 > 0), f0, 1) / a4)
    # Le plancher se mesure la ou pYIN n'entend pas de hauteur : une prise
    # presque entierement jouee n'a pas assez de silence pour un centile.
    muet = rms[~voise]
    plancher = float(np.median(muet)) if muet.size > 20 else float(np.percentile(rms, 5))
    actif = voise & (proba > 0.3) & (rms > max(plancher * 2, 2e-3))
    # L'accord reel de l'instrument : on juge relativement, comme
    # l'application (CLAUDE.md, justesse relative).
    frac = (midi[actif] - np.round(midi[actif]))
    decal = float(np.median(frac)) if frac.size else 0.0
    midi = midi - decal
    attaques = librosa.onset.onset_detect(
        onset_envelope=env, sr=SR, hop_length=HOP, wait=6, delta=0.07,
        units='frames')
    # Les creux d'energie entre deux coups d'archet : c'est par eux que se
    # comptent des notes repetees a la meme hauteur, que ni la hauteur ni le
    # flux spectral ne separent toujours (piece B : huit la de suite).
    # Fenetre courte (23 ms) : un changement d'archet ne dure que quelques
    # dizaines de millisecondes, une fenetre de 93 ms l'effacait.
    court = librosa.feature.rms(y=y, frame_length=512, hop_length=HOP)[0][:n]
    db = 20 * np.log10(np.maximum(court, 1e-6))
    creux = set()
    for i in range(4, n - 4):
        if db[i] > db[i - 4:i + 5].min():
            continue
        gauche = db[max(0, i - 12):i].max()
        droite = db[i + 1:i + 13].max()
        if min(gauche, droite) - db[i] >= 4.0 and db[i] > -70:
            creux.add(i)
    return {'y': y, 'midi': midi, 'actif': actif, 'env': env,
            'attaques': set(int(a) for a in attaques), 'creux': creux,
            'db': db, 'decal': decal, 'n': n}


def lisser(m, actif, k=5):
    s = m.copy()
    for i in range(len(m)):
        a, b = max(0, i - k // 2), min(len(m), i + k // 2 + 1)
        v = m[a:b][actif[a:b]]
        if v.size:
            s[i] = np.median(v)
    return s


def segments(a):
    """La prise decoupee en notes jouees : (debut, fin, hauteur, ecart)."""
    midi, actif, att = a['midi'], a['actif'], a['attaques']
    lis = lisser(midi, actif)
    arr = np.round(lis)
    segs = []
    debut = None
    for i in range(a['n'] + 1):
        fin_ici = i == a['n'] or not actif[i]
        coupe = False
        if not fin_ici and debut is not None:
            # Une attaque coupe ; un changement de hauteur aussi, s'il tient
            # quatre trames (40 ms) -- une liaison n'a pas d'attaque.
            # 100 ms au moins entre deux coupures : une attaque qui suit un
            # creux de quelques centiemes est le meme coup d'archet, et la
            # plus courte note de ces partitions dure plus de 200 ms.
            if (i in att or i in a['creux']) and i - debut >= 10:
                coupe = True
            elif arr[i] != arr[i - 1]:
                suite = arr[i:i + 4]
                if len(suite) == 4 and np.all(suite == arr[i]) and i - debut >= 4:
                    coupe = True
        if debut is not None and (fin_ici or coupe):
            if i - debut >= 5:
                coeur = lis[debut + (i - debut) // 4: i - (i - debut) // 4 or i]
                h = float(np.median(coeur)) if coeur.size else float(lis[debut])
                segs.append((debut, i, int(round(h)), h - round(h)))
            debut = None
        if not fin_ici and debut is None:
            debut = i
    return segs


def aligner(segs, notes, depart=None):
    """Calage symbolique : chaque note jouee sur une note ecrite, ou 'x'.

    Les transitions sont celles d'un enfant qui travaille : la suivante,
    une sautee, la meme rejouee, et le retour au debut de n'importe quelle
    mesure deja jouee (une reprise), plus cher a mesure qu'il recule."""
    J, K = len(notes), len(segs)
    if K == 0:
        return []
    mes = np.array([n['mesure'] for n in notes])
    debut_mesure = {}
    for j, n in enumerate(notes):
        debut_mesure.setdefault(n['mesure'], j)
    tr = np.full((J, J), 8.0)
    for j in range(J):
        if j + 1 < J:
            tr[j, j + 1] = 0.0
        if j + 2 < J:
            tr[j, j + 2] = 1.6
        if j + 3 < J:
            tr[j, j + 3] = 3.0
        tr[j, j] = 1.2
        for m, jm in debut_mesure.items():
            if m <= mes[j] and jm <= j:
                tr[j, jm] = min(tr[j, jm], 1.8 + 0.25 * (mes[j] - m))
            if m == mes[j] + 1 and jm > j + 1:
                tr[j, jm] = min(tr[j, jm], 3.0)

    def emission(h):
        d = np.abs(np.array([n['midi'] for n in notes]) - h)
        e = np.where(d == 0, 0.0, np.where(d <= 2, 1.4 + 0.6 * (d - 1), 5.0))
        e = np.where(d == 12, 2.0, e)
        return e

    EXTRA = 2.2
    # On commence au debut d'une mesure, celle de la consigne de preference ;
    # une autre coute un peu, pour qu'entre deux passages identiques -- la
    # piece B repete ses quatre premieres mesures -- la consigne tranche.
    cout = np.full(J, 3.0)
    for m, jm in debut_mesure.items():
        cout[jm] = 0.0 if m == depart else 1.0
    cout = cout + emission(segs[0][2])
    retour = []
    for k in range(1, K):
        e = emission(segs[k][2])
        cand = cout[:, None] + tr
        prec = np.argmin(cand, axis=0)
        nouveau = cand[prec, np.arange(J)] + e
        reste = cout + EXTRA
        prend = nouveau <= reste
        retour.append((np.where(prend, prec, np.arange(J)), ~prend))
        cout = np.where(prend, nouveau, reste)
    # Retour arriere : l'etat apres le segment k est la derniere note
    # ecrite rattachee ; un segment "en plus" laisse l'etat en place.
    j = int(np.argmin(cout))
    chemin = [None] * K
    for k in range(K - 1, 0, -1):
        prec, extra = retour[k - 1]
        if extra[j]:
            chemin[k] = None
        else:
            chemin[k] = j
            j = int(prec[j])
    chemin[0] = j
    # Le premier segment est toujours rattache : il ouvre la prise.
    sortie = []
    for k, s in enumerate(segs):
        jj = chemin[k]
        if jj is None:
            sortie.append((s, None, False))
        else:
            sortie.append((s, notes[jj], notes[jj]['midi'] != s[2]))
    return sortie


def lire_marqueurs(chemin):
    if not os.path.exists(chemin):
        return []
    out = []
    for ligne in open(chemin):
        champs = ligne.rstrip('\n').split('\t')
        if len(champs) >= 3 and not ligne.startswith('\\'):
            out.append((float(champs[0]), champs[2].strip()))
    return out


def ident(texte):
    for mot in texte.split():
        if mot.startswith('n') and mot[1:].isdigit():
            return mot
    return 'x' if texte.strip() == 'x' else None


def comparer(ref, app):
    """Pour chaque note de la reference, ce que l'aligneur dit **a la
    majorite** entre l'etiquette et la suivante -- la regle meme de
    tool/banc.dart (AlignmentReport) : un retard de cent millisecondes sur une
    note de huit cents ne compte pas, une autre note si."""
    def a_l_instant(t):
        a = None
        for ta, txa in app:
            if ta <= t:
                a = ident(txa)
            else:
                break
        return a

    desaccords = []
    for i, (t, texte) in enumerate(ref):
        r = ident(texte)
        fin = ref[i + 1][0] if i + 1 < len(ref) else t + 1.5
        fin = min(fin, t + 1.5)
        compte = {}
        u = t + 0.03
        while u < fin:
            a = a_l_instant(u)
            compte[a] = compte.get(a, 0) + 1
            u += 0.01
        a = max(compte, key=compte.get) if compte else a_l_instant(t)
        if r != a and r is not None:
            desaccords.append((t, r, a))
    return desaccords


def dessiner(a, notes_par_id, ref, app, t0, t1, chemin, titre):
    import librosa
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    i0, i1 = int(t0 * SR), int(t1 * SR)
    seg = a['y'][i0:i1]
    C = np.abs(librosa.cqt(seg, sr=SR, hop_length=HOP, fmin=librosa.midi_to_hz(53),
                           n_bins=60, bins_per_octave=12))
    db = librosa.amplitude_to_db(C, ref=np.max)
    fig, (ax, ax2) = plt.subplots(2, 1, figsize=(16, 7), sharex=True,
                                  gridspec_kw={'height_ratios': [5, 1]})
    ax.imshow(db, aspect='auto', origin='lower', cmap='Greys',
              extent=[t0, t1, 53 - 0.5, 113 - 0.5], vmin=-60, vmax=0)
    f0, f1 = int(t0 * 100), min(a['n'], int(t1 * 100))
    tt = np.arange(f0, f1) / 100
    m = np.where(a['actif'][f0:f1], a['midi'][f0:f1], np.nan)
    ax.plot(tt, m, color='tab:red', lw=1.2)
    bas = np.nanmin(m) if np.isfinite(m).any() else 60
    haut = np.nanmax(m) if np.isfinite(m).any() else 80
    ax.set_ylim(bas - 4, haut + 4)
    for t, texte in app:
        if t0 <= t <= t1:
            ax.axvline(t, color='tab:blue', lw=0.8, ymin=0.55)
            ax.text(t, haut + 3.2, texte.split()[-1], color='tab:blue',
                    fontsize=8, rotation=90, va='top')
    for t, texte in ref:
        if t0 <= t <= t1:
            ax.axvline(t, color='tab:green', lw=0.8, ymax=0.45)
            i = ident(texte)
            ax.text(t, bas - 3.6, texte, color='tab:green', fontsize=8,
                    rotation=90, va='bottom')
            n = notes_par_id.get(i)
            if n:
                ax.plot([t, t + 0.15], [n['midi'], n['midi']], color='tab:green',
                        lw=3, alpha=0.6)
    ax.set_yticks(range(int(bas) - 3, int(haut) + 4))
    ax.set_yticklabels([NOMS[v % 12] + str(v // 12 - 1)
                        for v in range(int(bas) - 3, int(haut) + 4)], fontsize=7)
    ax.grid(axis='y', alpha=0.2)
    ax.set_title(titre + '  (bleu : application, vert : reference)')
    ax2.plot(np.arange(f0, f1) / 100, a['env'][f0:f1] / max(1e-6, a['env'][f0:f1].max()),
             color='k', lw=0.8)
    ax3 = ax2.twinx()
    ax3.plot(np.arange(f0, f1) / 100, a['db'][f0:f1], color='tab:purple', lw=0.8)
    for at in a['attaques']:
        if f0 <= at < f1:
            ax2.axvline(at / 100, color='tab:orange', lw=0.8)
    for c in a['creux']:
        if f0 <= c < f1:
            ax2.axvline(c / 100, color='tab:purple', lw=0.8, ls=':')
    ax2.set_xlabel('secondes')
    fig.tight_layout()
    fig.savefig(chemin, dpi=80)
    plt.close(fig)


def main():
    banc, prise = sys.argv[1], sys.argv[2]
    images = None
    if '--images' in sys.argv:
        images = sys.argv[sys.argv.index('--images') + 1]
        os.makedirs(images, exist_ok=True)
    tout = '--tout' in sys.argv
    base = os.path.join(banc, 'prises', prise)
    meta = json.load(open(base + '.json'))
    notes = partition(banc, meta)
    par_id = {n['id']: n for n in notes}
    a = analyser(base + '.wav', float(meta.get('la_mesure_hz') or 440))
    segs = segments(a)
    cale = aligner(segs, notes, (meta.get('mesures') or [None])[0])
    # Un debris de changement d'archet -- moins de 120 ms, colle a la note
    # suivante et rattache a la meme note ecrite -- n'est pas une note jouee.
    nettoye = []
    for i, (s_, n, faux) in enumerate(cale):
        if i + 1 < len(cale) and n is not None:
            s2, n2, _ = cale[i + 1]
            if (n2 is not None and n2['id'] == n['id'] and s_[1] - s_[0] < 12
                    and s2[0] - s_[1] < 6):
                continue
        nettoye.append((s_, n, faux))
    # Une note longue coupee par un changement d'archet reste une note : deux
    # segments de suite rattaches a la meme note ecrite n'en font qu'un.
    fusionne = []
    for s_, n, faux in nettoye:
        if (fusionne and n is not None and fusionne[-1][1] is not None
                and fusionne[-1][1]['id'] == n['id']):
            continue
        fusionne.append((s_, n, faux))
    cale = fusionne
    lignes = []
    for (d, f, h, ecart), n, faux in cale:
        t = d / 100
        if n is None:
            lignes.append((t, 'x'))
        else:
            lignes.append((t, f"m{n['mesure']} {NOMS[n['midi'] % 12]} {n['id']}"
                              + (' faux' if faux else '')))
    with open(base + '.ref.txt', 'w') as s:
        for t, texte in lignes:
            s.write(f'{t:.3f}\t{t:.3f}\t{texte}\n')
    app = lire_marqueurs(base + '.app.txt')
    des = comparer(lignes, app)
    accord = 1 - len(des) / max(1, len(lignes))
    print(f'{prise}: {len(segs)} notes jouees, accord {accord:.0%} '
          f'({len(des)} desaccords), accord du la {a["decal"] * 100:+.0f} c',
          flush=True)
    for t, r, ap in des:
        print(f'  {t:7.2f} s  reference {r or "-":6}  application {ap or "-"}')
    if images:
        duree = a['n'] / 100
        fen = 6.0
        t0 = 0.0
        while t0 < duree:
            t1 = min(duree, t0 + fen)
            if tout or any(t0 <= t < t1 for t, _, _ in des):
                dessiner(a, par_id, lignes, app, t0, t1,
                         os.path.join(images, f'{prise}-{int(t0):03d}.png'),
                         f'{prise}  {t0:.0f}-{t1:.0f} s')
            t0 += fen


if __name__ == '__main__':
    main()
