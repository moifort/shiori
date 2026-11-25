/* Shiori landing page: English for every browser that is not set to French.
 * The page is written in French; elements carrying data-i18n get their English
 * HTML from here before the first paint (the head script hides the page until
 * then). data-i18n-aria translates an aria-label, data-i18n-alt an image's alt. */
(() => {
  "use strict";
  const root = document.documentElement;
  if (!root.classList.contains("i18n-en")) return;

  const EN = {
    "meta.title": "Shiori — Snap a book cover, your library sorts itself",
    "nav.features": "Features",
    "nav.pricing": "Pricing",
    "nav.faq": "FAQ",
    "nav.download": "App Store",
    "hero.pill": "First month free",
    "hero.title": "Snap a book.<br>Your library sorts itself.",
    "hero.subtitle": "One cover or a whole shelf: every book arrives with its summary, its series and its author. The next volume is announced to you, Kindle and Audible stay up to date, your friends see what you read.",
    "hero.price": "Then $29.99 a year, or $3.99 a month. No ads.",
    "aria.store": "Download on the App Store",
    "store.small": "Download on the",
    "store.soon": "Coming soon to Google Play",
    "premium": "Premium",

    "scan.title": "One photo of the cover. That's it.",
    "scan.text": "No barcode to hunt for: the cover is enough, even on an old edition. Title, author, series and volume, genre, publisher, summary and page count fill themselves in. A typo? Fix it before saving.",
    "scan.c1": "Series and volume recognised",
    "scan.c2": "Every language",
    "scan.c3": "30 scans a month",
    "shelf.title": "A whole shelf in one photo.",
    "shelf.text": "Photograph a shelf: every spine is recognised, every book gets its record. Tick the ones that come in, and thirty books join your library without taking a single one out.",
    "book.title": "Every book has its record.",
    "book.text": "To read, reading, read or given up. One to five stars, a heart for your favourites, a comment, who recommended it. Paperback and e-reader on one record, with the cover of your choice.",
    "book.c1": "Paper, e-reader, audio",
    "book.c2": "Comics and manga",
    "book.c3": "Every edition in its language",
    "series.title": "The next volume, as soon as its date is known.",
    "series.text": "Every volume joins its series. The ones you miss are there, and so are the announced ones: you hear the day a volume is announced, then on its release day, in print, audio or translation.",
    "series.c1": "Missing volumes",
    "series.c2": "The release agenda",
    "series.c3": "An alert on the day",
    "news.title": "The news of your reading.",
    "news.text": "What comes out today in your series, the winners of the big awards in your genres, your friends' favourites, and every month books picked from what you loved.",
    "news.c1": "Hugo, Nebula, Goncourt…",
    "news.c2": "The month's discoveries",
    "library.title": "Your library, your reading pile.",
    "library.text": "Books, series, authors, narrators: it all sorts itself. Filter by format, search from three letters, and keep at hand the pile of what is waiting for you, and since when.",
    "wish.title": "The wishlist.",
    "wish.text": "A book seen at a friend's, in the news or shared from another app: keep it for later. It joins your library the day you have it.",
    "friends.title": "What your friends are reading.",
    "friends.text": "Invite a friend with a simple link: each of you sees the other's current reads, favourites, finished books and whole library. A book you would rather keep to yourself stays hidden.",
    "friends.c1": "Invitation by link",
    "friends.c2": "Comments between friends",
    "sync.title": "Kindle and Audible, up to date every night.",
    "sync.text": "Connect your Amazon account once: your Kindle and Audible purchases arrive with their covers and series, and your progress too. Then everything updates every night, with nothing to do. Your password stays with Amazon.",
    "goodreads.title": "Coming from Goodreads? It all comes with you.",
    "goodreads.text": "Give Shiori the Goodreads export file: your shelves, ratings and reading dates come in, each book with its cover and series. What you already have is recognised, nothing is doubled.",

    "more.title": "And everything that makes the difference.",

    "notif.now": "now",
    "notif.date": "Tuesday, October 20",
    "notif.title": "Told on release day",
    "notif.text": "On the release day of a volume, a translation or an audiobook you are waiting for. On Sundays, the newly announced volumes. Every month, your discoveries. Each alert switches off on its own.",

    "rate.title": "Rate, love, give up",
    "rate.text": "Read, reading, to read or given up, one to five stars, a heart for your favourites: all a tap away, at the top of the record.",
    "note.title": "A comment on every book",
    "note.text": "What you thought of it, and what your friends say about it, under every book.",
    "info.title": "The whole record, yours to edit",
    "info.text": "Reading dates, genre, format, publisher, where the book came from: everything can be corrected.",
    "narr.title": "Your favourite narrators",
    "narr.text": "An audiobook has its narrator. Follow the ones you love: their new books show up in the news.",
    "followed.title": "The series you follow",
    "followed.text": "The next volume of every series, with the time left before it comes out.",
    "one.title": "Books, audio, comics, manga",
    "one.text": "A paperback and its Kindle edition are one record. The audiobook has its own, and every format filters in a tap.",
    "alt.releases": "Home: this month's release from your series, up front",

    "offer.pill": "One subscription, everything included",
    "offer.title": "Your free month.",
    "offer.lead": "Shiori comes with a subscription, with no free version and no ads. The first month is free, and nothing is charged if you cancel before it ends.",
    "offer.yearly.tag": "1 month free",
    "offer.yearly.name": "Yearly",
    "offer.yearly.price": "$29.99 <small>/ year</small>",
    "offer.yearly.note": "that is $2.50 a month",
    "offer.monthly.name": "Monthly",
    "offer.monthly.price": "$3.99 <small>/ month</small>",
    "offer.monthly.note": "no trial",
    "promise.sync.title": "Kindle and Audible up to date",
    "promise.sync.text": "Your purchases and your reading arrive every night, with nothing to do.",
    "promise.alerts.title": "Release alerts",
    "promise.alerts.text": "The next volume of your series, as soon as its date is known.",
    "promise.scan.title": "A cover or a shelf in a photo",
    "promise.scan.text": "Every book recognised, with its summary and series. 30 scans a month.",
    "promise.all.title": "And everything else",
    "promise.all.text": "Library, series, authors, news, friends, wishlist, Goodreads import.",
    "offer.note": "Auto-renewing, cancel anytime in your App Store account settings. Prices vary by country. iPhone, iOS 26, in English and French.",

    "faq.title": "Questions",
    "faq.q1": "Is there a free version?",
    "faq.a1": "No. Shiori comes with a subscription: $29.99 a year with the first month free, or $3.99 a month with no trial. There are no ads and your data is never sold. If you stop, your books, series and ratings are kept, and you find them again when you subscribe again.",
    "faq.q2": "Why the cover rather than the barcode?",
    "faq.a2": "A barcode tells the edition, not the series or the volume. The cover tells it all: title, author, volume, publisher. It is enough, even on an old book with no code on the back.",
    "faq.q3": "What do 30 scans a month mean?",
    "faq.a3": "Every photo analysed, of a cover or a shelf, counts as one scan. The counter starts again each month. Adding a book by its title, by sharing from another app, or from Kindle, Audible or Goodreads does not count.",
    "faq.q4": "How does the Kindle and Audible connection work?",
    "faq.a4": "You sign in on Amazon's own page, as in the Kindle app; your password stays with Amazon. You choose what comes in, then every night new purchases and your progress arrive by themselves.",
    "faq.q5": "How is a release found?",
    "faq.a5": "Every week, the web is searched for each series you read: the next volume announced in its language, and its translation or audio edition if you are waiting for one. You hear at the announcement, then on release day.",
    "faq.q6": "What do my friends see?",
    "faq.a6": "Your books, favourites, current reads, stars and comments. A hidden book shows up for no one.",
    "faq.q7": "Where does my data go?",
    "faq.a7": "Sign in with your Apple account, email hideable. Library stored in Europe, in Frankfurt. The photo of a cover is used to recognise it, then deleted.",
    "faq.q8": "What about Android?",
    "faq.a8": "Shiori is coming soon to Google Play, with the same subscription. For now, the app is on iPhone, iOS 26.",

    "footer.credit": "Shiori is an app by <a href=\"https://github.com/moifort\" rel=\"noopener\">Polyforms</a>. 栞 (<i>shiori</i>) means “bookmark” in Japanese.",
    "footer.privacy": "Privacy",
    "footer.source": "Source code",
    "footer.issues": "Report a problem",

    "alt.home": "Home: the year's reading in figures, a release this month, the books being read",
    "alt.scan": "A book recognised from its cover, ready to join the library",
    "alt.shelf": "The books recognised on the photo of a shelf, to tick",
    "alt.book": "A book's record: cover, status, rating and series",
    "alt.series": "A series: the volumes read, the missing ones and the next announced",
    "alt.agenda": "The agenda of your series' upcoming releases",
    "alt.news": "News: the release agenda, friends' news and the month's discoveries",
    "alt.library": "The library: books, series, authors and recent reads",
    "alt.pile": "The reading pile, and what comes next in your series",
    "alt.wishlist": "The wishlist",
    "alt.friends": "Friends: their current reads, favourites and finished books",
    "alt.sync": "Home, with the books being read on Kindle and Audible",
    "alt.goodreads": "The Goodreads import: the books found in the export",
    "alt.offer": "The offer in the app: the free month, then the yearly or monthly plan",
  };

  for (const el of document.querySelectorAll("[data-i18n]")) {
    const text = EN[el.dataset.i18n];
    if (text !== undefined) el.innerHTML = text;
  }
  for (const el of document.querySelectorAll("[data-i18n-alt]")) {
    const text = EN[el.dataset.i18nAlt];
    if (text !== undefined) el.alt = text;
  }
  for (const el of document.querySelectorAll("[data-i18n-src]")) {
    el.src = el.dataset.i18nSrc;
  }
  for (const el of document.querySelectorAll("[data-i18n-aria]")) {
    const text = EN[el.dataset.i18nAria];
    if (text !== undefined) el.setAttribute("aria-label", text);
  }
  document.querySelector("meta[name=description]")?.setAttribute("content",
    "Snap a cover or a whole shelf: every book arrives with its summary, series and author. Alerts at every new volume, Kindle and Audible kept up to date nightly, Goodreads import, reading shared with friends. First month free, on iPhone.");
  root.lang = "en";
  root.classList.remove("i18n-pending");
})();
