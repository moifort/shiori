# Journal des modifications

Traduction française de `CHANGELOG.md`, qui fait foi. Les deux fichiers avancent ensemble.

## Unreleased

- Le graphique de lecture de l’accueil compte aussi les heures écoutées : un troisième onglet
  trace les heures de livre audio de chaque mois, d’après la durée qu’Audible indique pour
  chaque titre importé. Chaque barre porte désormais son propre chiffre, et la vue par année
  couvre neuf ans au lieu de six.
- La bibliothèque Audible peut être importée dans Shiori. On connecte le compte Amazon une
  fois depuis les réglages, on choisit la boutique, et toute la bibliothèque s’affiche avec ses
  couvertures, ses séries et l’avancement d’écoute ; les titres cochés sont catalogués comme
  livres audio, ceux terminés gardant la date à laquelle ils l’ont été. Les titres déjà
  présents sont signalés comme tels, et un second import ne crée aucun doublon. Un import ne
  coûte aucun scan.
- Les écrans de chargement montrent désormais un gros grimoire que l’on marque : un ruban
  tombe dans la reliure et le livre se referme dessus, à la place de la page tournante.
- Pendant un scan, l’écran d’attente montre la photo qui vient d’être prise, cadrée comme une
  couverture et balayée de haut en bas par un faisceau lumineux, à la place d’un chargement
  générique.
- Un scan n’échoue plus au bout d’une minute quand les modèles tardent à répondre, et une
  analyse qui échoue peut être relancée sur la même photo sans dépenser de scan supplémentaire.
- L’accueil devient un tableau de bord de lecture : livres lus par année et pages par mois,
  lectures en cours, quelques idées tirées de la pile à lire, dernier livre terminé, tendances
  par rapport à l’an dernier, pile à lire et note moyenne, genres lus dans l’année et séries
  en cours.
- Chaque livre est rangé dans un genre choisi dans une liste fixe, accompagné d’au plus trois
  sous-genres libres. Les deux se corrigent depuis la fiche du livre.
- Les livres scannés affichent désormais leur couverture d’éditeur, retrouvée grâce à l’ISBN.
  Un livre dont la couverture est introuvable garde ses initiales.
- Toutes les informations d’un livre se corrigent désormais depuis sa fiche avec « Modifier » :
  titre, auteurs, format, note, résumé, éditeur, année, pages, genres et ISBN. Un champ peut
  être vidé, et une note retirée.
