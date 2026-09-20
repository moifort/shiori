# Journal des modifications

Traduction française de `CHANGELOG.md`, qui fait foi. Les deux fichiers avancent ensemble.

## Unreleased

- Shiori a une icône : un signet rouge qui pend sur une page crème. Le même signet est
  l’animation d’ouverture de l’app, qui tombe en place pendant que la bibliothèque se charge,
  et la marque des écrans de connexion et de bienvenue.
- Une bibliothèque Audible se tient désormais à jour toute seule. Chaque nuit, Shiori
  catalogue les titres achetés depuis le dernier passage et met un livre importé au statut
  qu’Audible indique — un titre terminé là-bas est marqué lu ici, à la date à laquelle il l’a
  réellement été, et un titre qu’Audible dit jamais ouvert retourne dans la pile. Les notes,
  les commentaires et les livres masqués ne sont jamais touchés, et un livre catalogué depuis
  l’édition papier n’est jamais déplacé. On désactive la synchronisation depuis la fiche
  Audible pour revenir à l’import manuel, ou on y demande un passage sur-le-champ sans
  attendre la nuit.
- Les imports ont leur propre menu sur l’onglet Accueil, qui ouvre une fiche par source. La
  fiche Audible rassemble ce qui était éparpillé : la boutique sur laquelle pointe le compte,
  la date de connexion, si la synchronisation tourne chaque nuit et quand elle l’a fait pour la
  dernière fois, la part de la bibliothèque déjà cataloguée, et le bouton qui demande un
  passage immédiat. Choisir les titres à la main est un cran plus loin, puisqu’une bibliothèque
  connectée se tient à jour toute seule. L’entrée du menu d’ajout de l’onglet Bibliothèque
  disparaît : importer une bibliothèque entière, c’est gérer un compte, pas ajouter un livre.
- Un livre audio importé depuis Audible arrive avec son genre, lu sur le rayon où Amazon le
  range plutôt que laissé à renseigner titre par titre. Un rayon qui désigne un public ou un
  thème plutôt qu’un type d’histoire — « Jeunesse », « LGBTQ+ » — est conservé en sous-genre, et
  à côté du genre et non à sa place : un thriller young adult est un thriller rangé sous
  « Young adult ». Les livres importés avant gardent le genre qu’on leur a donné à la main.
- Un livre audio traduit n’est plus crédité à son traducteur. Audible range tous les
  contributeurs parmi les auteurs et signale le rôle dans le nom lui-même, si bien que les
  livres affichaient « Danusia Stok - translator » sur leur fiche comme si elle les avait
  écrits.
- Une série se note désormais pour elle-même, de une à cinq étoiles, et se garde en favorite —
  un livre aussi. La note de la série juge le cycle et n’est pas la moyenne de ses tomes, et le
  cœur est indépendant des étoiles des deux côtés : un livre cinq étoiles qu’on ne rouvrira
  jamais et un livre trois étoiles gardé pour ce qu’il a représenté existent tous les deux.
- La langue d’une édition est lue sur la couverture pendant un scan, et reprise d’Audible lors
  d’un import. Chaque livre porte son drapeau dans la bibliothèque, et une série détenue en
  plusieurs langues est désormais rangée une fois par langue — « Dune » en français et « Dune »
  en anglais font deux sections et deux lignes dans l’onglet Séries, chacune avec son drapeau.
  Les livres catalogués avant n’affichent aucun drapeau tant que la langue n’est pas renseignée
  à la main depuis la fiche.
- Une ligne de la bibliothèque indique maintenant de quoi parle le livre, avec le genre et son
  icône sous les étoiles et, à côté, le sous-genre le plus parlant du livre — un scan classe
  désormais les sous-genres qu’il trouve pour que le premier soit celui qui le décrit le mieux.
  La ligne signale aussi un livre audio par un symbole de casque.
- Un livre audio crédite ses narrateurs et affiche sa durée sur sa fiche, l’un et l’autre repris
  d’Audible à l’import.
- Les séries importées depuis Audible, et celles des livres ajoutés à la main, apparaissent
  enfin dans l’onglet Séries. Elles en étaient purement absentes : l’onglet ne listait que les
  séries décrites par un scan, or ni un import ni une saisie manuelle n’en demande la
  description.

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
