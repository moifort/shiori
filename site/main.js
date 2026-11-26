/* Shiori landing page.
 *
 *  1. The hero's wall of covers, as the app opens on it.
 *  2. The screens, in the visitor's language, and each chapter's backdrop:
 *     its own screen, blurred.
 *  3. Blocks rising into place as they come into view.
 */
(() => {
  "use strict";

  const lang = document.documentElement.classList.contains("i18n-en") ? "en" : "fr";
  const version = "20261125k";

  // ---------------------------------------------------------------------------
  // The wall of covers
  // ---------------------------------------------------------------------------

  // Novels readers rate highly today: no manga, no comics on the wall.
  const COVERS = [
    "projet-derniere-chance", "demain-et-demain", "fourth-wing", "trois-corps", "foret-sombre",
    "mort-immortelle", "dune", "messie-de-dune", "hyperion", "nom-du-vent", "peur-du-sage", "sapiens",
    "dernier-meurtre", "buffalo-hunter", "maison-vide", "veiller-sur-elle", "jacaranda", "horde-du-contrevent",
    "furtifs", "fondation", "sorceleur-01", "shibumi", "dcc-01", "dcc-02", "dcc-03", "dcc-05",
    "sf-children-of-time", "sf-klara", "sf-station-eleven", "sf-murderbot", "sf-stars-destination",
    "sf-ancillary-justice", "sf-martian", "sf-leviathan-wakes", "sf-annihilation", "sf-wool",
    "sf-the-road", "sf-handmaids-tale", "sf-ready-player-one", "friend-blood-of-hercules", "friend-powerful",
    "friend-wolf-king", "friend-maison-terre-sang", "monte-cristo",
  ];

  function hash(n) {
    const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
    return x - Math.floor(x);
  }

  const wall = document.querySelector("[data-cover-wall]");
  if (wall) {
    const columns = window.innerWidth < 700 ? 6 : 11;
    wall.style.setProperty("--cols", columns);
    // Enough rows to cover the whole hero, however tall, with the wall's tilt
    // and its slow drift upwards: a cover is (width / columns) * 1.5 tall.
    const hero = wall.closest(".hero");
    const coverHeight = ((window.innerWidth * 1.16) / columns) * 1.5;
    const rows = Math.ceil((hero.offsetHeight * 1.3) / coverHeight) + 3;
    const count = columns * rows;
    // A few dozen distinct covers, repeated: the wall stays light on a phone.
    const distinct = window.innerWidth < 700 ? 22 : 34;
    const order = COVERS.map((slug, i) => [hash(i + 7), slug]).sort((a, b) => a[0] - b[0]).map((p) => p[1]).slice(0, distinct);
    for (let i = 0; i < count; i++) {
      const img = new Image();
      img.alt = "";
      img.decoding = "async";
      img.onload = () => img.classList.add("loaded");
      img.src = `covers/${order[(i * 5) % order.length]}.jpg`;
      wall.appendChild(img);
    }
  }

  // ---------------------------------------------------------------------------
  // The screens
  // ---------------------------------------------------------------------------

  // The Dynamic Island, over every capture: a screenshot does not show it.
  for (const phone of document.querySelectorAll(".phone")) {
    const island = document.createElement("span");
    island.className = "island";
    island.setAttribute("aria-hidden", "true");
    phone.appendChild(island);
  }

  const shot = (name) => `screens/${lang}-${name}.jpg?v=${version}`;

  // ?capture=1, for the full-page renders: every screen at once, nothing hidden.
  const params = new URLSearchParams(location.search);
  const capture = params.has("capture");
  for (const img of document.querySelectorAll("[data-shot]")) {
    if (capture) img.loading = "eager";
    img.src = shot(img.dataset.shot);
  }
  for (const section of document.querySelectorAll("[data-bg]")) {
    const bg = section.querySelector(".chapter-bg");
    if (bg) bg.style.setProperty("--shot", `url("${shot(section.dataset.bg)}")`);
  }
  for (const crop of document.querySelectorAll("[data-crop]")) {
    crop.style.setProperty("--shot", `url("${shot(crop.dataset.crop)}")`);
  }
  for (const bg of document.querySelectorAll("[data-bg-shot]")) {
    bg.style.setProperty("--shot", `url("${shot(bg.dataset.bgShot)}")`);
  }

  // ---------------------------------------------------------------------------
  // The feature cards' live examples
  // ---------------------------------------------------------------------------

  const english = lang === "en";
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  /** Runs `loop` only while `el` is on screen. */
  function whenVisible(el, start) {
    if (!el) return;
    let started = false;
    new IntersectionObserver((entries) => {
      if (started || !entries.some((e) => e.isIntersecting)) return;
      started = true;
      start();
    }, { threshold: 0.3 }).observe(el);
  }

  const notifDemo = document.querySelector("[data-notif-demo]");
  whenVisible(notifDemo, async () => {
    const notif = notifDemo.querySelector("[data-notif]");
    const title = notif.querySelector("[data-notif-title]");
    const body = notif.querySelector("[data-notif-body]");
    const alertsFr = [
      { title: "Blue Lock, tome 35 sort aujourd'hui", body: "Muneyuki Kaneshiro · Blue Lock · Tome 35" },
      { title: "Frieren, tome 15 est disponible", body: "Kanehito Yamada · le tome que vous attendiez" },
      { title: "This Inevitable Ruin paraît en français", body: "Matt Dinniman · Dungeon Crawler Carl · Tome 7" },
      { title: "Hypérion est sorti en audio", body: "Dan Simmons · disponible sur Audible" },
      { title: "Prochaines sorties", body: "One Piece, tome 115, le 4 décembre, et 2 autres" },
      { title: "Nouvelles découvertes", body: "Voici les nouvelles découvertes de ce mois-ci." },
    ];
    const alertsEn = [
      { title: "Blue Lock, Vol. 35 is out today", body: "Muneyuki Kaneshiro · Blue Lock · Vol. 35" },
      { title: "Frieren, Vol. 15 is available", body: "Kanehito Yamada · the volume you were waiting for" },
      { title: "La Horde du Contrevent is out in English", body: "Alain Damasio · The Windwalkers" },
      { title: "Hyperion is out as an audiobook", body: "Dan Simmons · available on Audible" },
      { title: "Coming soon", body: "One Piece, book 115, on December 4, and 2 more" },
      { title: "New discoveries", body: "Here are this month's new discoveries." },
    ];
    const alerts = english ? alertsEn : alertsFr;
    let i = 0;
    for (;;) {
      title.textContent = alerts[i].title;
      body.textContent = alerts[i].body;
      notif.classList.add("in");
      await sleep(3600);
      notif.classList.remove("in");
      await sleep(900);
      i = (i + 1) % alerts.length;
    }
  });

  // ---------------------------------------------------------------------------
  // Reveal
  // ---------------------------------------------------------------------------

  const blocks = document.querySelectorAll(".chapter-text, .chapter .phone, .chapter .phones, .offer, .pricing .phone, .faq-list");
  if ("IntersectionObserver" in window && !capture) {
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("seen");
          observer.unobserve(entry.target);
        }
      }
    }, { threshold: 0.15 });
    for (const block of blocks) {
      block.classList.add("reveal");
      observer.observe(block);
    }
  }
})();
