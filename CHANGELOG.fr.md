# Journal des modifications

Traduction française de `CHANGELOG.md`, qui fait foi. Les deux fichiers avancent ensemble.

## Unreleased

- L’onglet Séries est découpé par genre et, dans un genre, place les sagas en cours
  d’abord, puis les terminées, puis celles pas encore commencées, le dernier changement
  d’état de lecture en tête de chacune. Chaque saga dit en toutes lettres où en est le
  lecteur — en cours, terminée, à lire — et montre ses tomes en une bande de couvertures,
  qui défile de côté, chacune portant son état de lecture. L’écran d’une série s’ouvre sur
  un anneau d’activité à côté du nom, de l’auteur et du nombre de tomes, liste les tomes un
  par ligne, ne dit où en est le lecteur d’un tome que par le badge sur sa couverture, et
  modifie d’un coup le genre et les sous-genres de tous les tomes.
- Un livre scanné dont Open Library n’a pas la couverture la cherche désormais sur Amazon,
  par l’ISBN, avant de se replier sur la couverture typographique. Les livres déjà dans la
  bibliothèque ont droit une fois à la même seconde chance. L’ISBN et le nombre de pages
  qu’un scan enregistre sont désormais ceux de l’édition photographiée, désignée par son
  éditeur et sa langue, et non ceux d’une édition quelconque du livre : le poche Folio ne
  prend plus la couverture de l’édition québécoise.
- La bibliothèque est triée par état de lecture : les livres en cours d’abord, puis ceux à
  lire, puis ceux terminés. Une saga se range, entière, avec son tome le plus actif, et les
  livres hors série suivent les sagas de chaque groupe sans titre de section. Dans un groupe,
  la saga dont un tome vient d’être commencé, terminé ou remis sur la pile est en tête ;
  corriger un livre ou écrire une note ne déplace rien. Le filtre par état disparaît, et le
  bouton appareil photo de la barre d’onglets ouvre désormais la fenêtre d’ajout — scan,
  photos récentes, titre ou saisie à la main — à la place du bouton « + » de la
  bibliothèque. L’en-tête d’une saga porte désormais le cœur ou les étoiles que le lecteur
  lui a donnés, à droite, et chaque ligne garde les siens au même endroit : le cœur si le
  livre est un favori, les étoiles sinon, jamais les deux.
- La fiche du livre fond les informations de publication dans la section principale, nomme
  le tome à côté de la couverture, montre le format en icône dans le coin et ouvre une fenêtre
  de genre depuis sa ligne de genre. Un résumé de plus de cinq cents mots se replie derrière
  « Lire la suite ». La liste des autres tomes quitte la fiche : l’écran de la série, à un
  geste, est là où vit le catalogue.
- Un genre ou un sous-genre corrigé sur un tome s’applique à tous les tomes de sa saga dans
  la bibliothèque, et le champ des sous-genres propose les mots déjà employés par le lecteur.
- L’accueil compte les favoris, livres et séries confondus, dans une tuile qui ouvre la liste
  de tout ce qui porte un cœur. Les heures d’écoute quittent le graphique d’une bibliothèque
  sans livre audio, et le graphique se souvient de la mesure choisie d’un lancement à l’autre.
- Une bibliothèque peut être partagée avec un ami. Le lecteur envoie un lien d’invitation, et
  celui qui l’accepte voit son étagère pendant qu’il voit la sienne : cela s’ouvre des deux
  côtés à la fois, et chacun des deux peut y mettre fin pour les deux. Le profil d’un ami
  montre ses lectures en cours, sa pile, ses favoris et les séries qu’il suit. Les livres
  marqués « ne pas partager » n’y figurent jamais, et aucune note de lecture n’est montrée.
  Toucher l’invitation depuis un iPhone qui a Shiori ouvre l’application directement sur
  l’invitation, avec un geste pour l’accepter — et un pour la refuser, parce que le lien
  vient d’ailleurs. Sans l’application, il ouvre la page comme avant.
- Une bibliothèque Kindle peut être cataloguée depuis l’export de données qu’Amazon fournit à
  ses clients. Amazon n’expose aucune API de bibliothèque Kindle : il n’y a donc pas de compte
  à connecter ni de synchronisation nocturne. Le lecteur demande ses données une fois, puis
  donne le fichier à Shiori. Les titres qu’il contient sont listés, ceux déjà sur l’étagère
  cochés d’office, et ceux qu’on garde arrivent sur la pile en livres numériques avec leur
  titre et leur auteur : c’est tout ce qu’un historique d’achats contient.
- L’écran d’une saga est devenu une étagère : ses tomes côte à côte dans l’ordre du cycle,
  ceux qui sont sur l’étagère en couleur, ceux qui manquent en vignettes estompées avec un
  bouton pour les ajouter, et ceux qui ne sont pas parus signalés comme tels. Une barre sous
  la description dit où en est le lecteur sur les tomes parus. Toucher un tome possédé l’ouvre.
- Le bouton « ajouter » de la bibliothèque ouvre une feuille disposée comme celle des fichiers
  de Vinarium : l’appareil photo et les dernières photos sur une même bande, un titre à taper de
  mémoire — l’IA retrouve le livre et propose la même fiche qu’un scan, pour un scan du quota —
  et le formulaire à remplir à la main.
- Shiori apparaît dans la feuille de partage de l’iPhone. La page d’un livre partagée depuis
  Safari ou l’application Amazon, un titre sélectionné, la photo d’une couverture : ce qui est
  envoyé arrive dans Shiori, et à la prochaine ouverture la fiche attend d’être vérifiée. Une
  page partagée est lue pour son titre, débarrassé du nom de la boutique et du format ; une
  page qui ne mène nulle part ne coûte rien.
- Les réglages, derrière une roue sur l’accueil : le profil avec déconnexion et suppression du
  compte, l’abonnement, les nouveautés, un formulaire pour nous écrire, et la connexion
  Audible, qui quitte le menu des imports.
- La bibliothèque et l’onglet des séries se chargent page par page et vont chercher la suivante
  quand le lecteur approche de la fin de la liste, si bien qu’une bibliothèque de trois cents
  livres s’affiche aussi vite qu’une de trente.
- La bibliothèque, les séries et l’accueil s’ouvrent sur ce qu’ils montraient la dernière fois
  et se rafraîchissent dessous, sous une roue en haut, plutôt que sur un chargement. Chaque
  bouton qui attend le réseau tourne dès l’appui, et chaque liste se redessine après tout
  changement fait ailleurs.

- Une saga importée depuis Audible a désormais son écran de série. Jusqu’ici, seul un scan
  constituait le catalogue d’une saga, si bien que toute saga nommée par un import s’ouvrait
  pour de bon sur « non cataloguée ». Le catalogue se constitue maintenant à la première
  ouverture de la saga, à partir du tome déjà dans la bibliothèque ; cette première ouverture
  prend quelques secondes, les suivantes sont immédiates.
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
- Un drapeau ne marque plus que les éditions dans une autre langue que celle de l’iPhone. Un
  lecteur dont le téléphone est en français a une bibliothèque française par défaut, et un 🇫🇷
  sur chaque ligne ne disait rien ; le drapeau reste pour l’exception, l’édition anglaise ou
  japonaise parmi les autres.
