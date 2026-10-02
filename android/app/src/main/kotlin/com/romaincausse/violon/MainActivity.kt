package com.romaincausse.violon

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Le selecteur de documents du systeme, expose a Dart sur "violon/documents".
 *
 * ACTION_OPEN_DOCUMENT ne demande aucune permission : l'utilisateur choisit
 * un fichier, l'application ne recoit que celui-la. C'est ce qui permet
 * d'importer une partition sans toucher au stockage (ADR-005).
 */
class MainActivity : FlutterActivity() {
    private var enAttente: MethodChannel.Result? = null
    private var aEcrire: Pair<MethodChannel.Result, ByteArray>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    "choisir" -> choisir(resultat)
                    "enregistrer" -> enregistrer(
                        appel.argument<String>("nom") ?: "violon.txt",
                        appel.argument<ByteArray>("octets") ?: ByteArray(0),
                        resultat,
                    )
                    else -> resultat.notImplemented()
                }
            }
    }

    private fun choisir(resultat: MethodChannel.Result) {
        if (enAttente != null) {
            resultat.error("occupe", "Un choix de fichier est deja ouvert", null)
            return
        }
        enAttente = resultat
        // Tous les types : un .musicxml arrive souvent en
        // application/octet-stream, et filtrer par type le rendrait grise.
        // C'est le contenu qui sera verifie, pas l'extension.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        startActivityForResult(intent, REQUETE)
    }

    /**
     * L'utilisateur choisit ou ranger un fichier, et on n'ecrit que la : le
     * rapport de la semaine (lot T3) part par ce geste volontaire, jamais
     * tout seul. ACTION_CREATE_DOCUMENT ne demande aucune permission.
     */
    private fun enregistrer(nom: String, octets: ByteArray, resultat: MethodChannel.Result) {
        if (aEcrire != null || enAttente != null) {
            resultat.error("occupe", "Un choix de fichier est deja ouvert", null)
            return
        }
        aEcrire = Pair(resultat, octets)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, nom)
        }
        startActivityForResult(intent, REQUETE_ECRIRE)
    }

    @Deprecated("startActivityForResult reste le chemin de FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUETE_ECRIRE) {
            val (resultat, octets) = aEcrire ?: return
            aEcrire = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                resultat.success(false)
                return
            }
            Thread {
                try {
                    contentResolver.openOutputStream(uri).use { flux ->
                        requireNotNull(flux) { "Fichier impossible a ecrire" }
                        flux.write(octets)
                    }
                    runOnUiThread { resultat.success(true) }
                } catch (e: Exception) {
                    runOnUiThread { resultat.error("ecriture", e.message, null) }
                }
            }.start()
            return
        }
        if (requestCode != REQUETE) return
        val resultat = enAttente ?: return
        enAttente = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            resultat.success(null)
            return
        }
        // La lecture se fait hors du fil principal : un fichier sur Drive
        // peut mettre une seconde a arriver.
        Thread {
            try {
                val octets = lire(uri)
                runOnUiThread {
                    resultat.success(mapOf("nom" to nom(uri), "octets" to octets))
                }
            } catch (e: Exception) {
                runOnUiThread { resultat.error("lecture", e.message, null) }
            }
        }.start()
    }

    private fun lire(uri: Uri): ByteArray {
        contentResolver.openInputStream(uri).use { flux ->
            requireNotNull(flux) { "Fichier illisible" }
            val sortie = java.io.ByteArrayOutputStream()
            val tampon = ByteArray(64 * 1024)
            while (true) {
                val n = flux.read(tampon)
                if (n < 0) break
                sortie.write(tampon, 0, n)
                // Meme borne que PieceImporter.maxBytes, pour ne pas charger
                // en memoire une video choisie par erreur.
                require(sortie.size() <= MAX_OCTETS) { "Fichier trop gros" }
            }
            return sortie.toByteArray()
        }
    }

    private fun nom(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { curseur ->
                if (curseur.moveToFirst()) return curseur.getString(0) ?: ""
            }
        return uri.lastPathSegment ?: ""
    }

    companion object {
        private const val CANAL = "violon/documents"
        private const val REQUETE = 4217
        private const val REQUETE_ECRIRE = 4218
        private const val MAX_OCTETS = 20 * 1024 * 1024
    }
}
