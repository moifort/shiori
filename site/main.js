/* Shiori landing page.
 *
 * Everything that moves on this page is driven from here:
 *  1. The showcase: three iPhones under the hero that fan out as the page
 *     scrolls.
 *  2. Small loops in the feature cards.
 */

(() => {
  "use strict";

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  // Set by i18n.js for every browser that is not in French.
  const english = document.documentElement.lang === "en";
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  // ---------------------------------------------------------------------------
  // The covers
  // ---------------------------------------------------------------------------

  // The library's covers.
  const LIBRARY = [
    "nom-du-vent", "one-piece-01", "dune", "frieren-01", "trois-corps", "blacksad-01", "projet-derniere-chance",
    "blue-lock-01", "hyperion", "chateau-animaux-01", "fourth-wing", "spy-family-01", "sapiens", "one-piece-05",
    "peur-du-sage", "frieren-03", "veiller-sur-elle", "blue-lock-04", "fondation", "dcc-01", "messie-de-dune",
    "blacksad-03", "jacaranda", "one-piece-12", "foret-sombre", "frieren-07", "demain-et-demain", "blue-lock-09",
    "shibumi", "chateau-animaux-02", "horde-du-contrevent", "one-piece-100", "monte-cristo", "dcc-03",
    "sorceleur-01", "frieren-10", "furtifs", "blue-lock-32", "mort-immortelle", "blacksad-05", "one-piece-110",
    "dcc-05", "frieren-14", "chateau-animaux-04", "blue-lock-35", "one-piece-114", "blacksad-07", "dcc-06",
    "frieren-15", "one-piece-08", "blue-lock-15", "blacksad-02", "one-piece-03", "frieren-05", "dcc-02",
  ];
  // The science-fiction classics, from scripts/site-covers.ts.
  const CLASSICS = [
    "sf-1984", "sf-2001", "sf-ancillary-justice", "sf-androids-dream", "sf-annihilation", "sf-brave-new-world",
    "sf-canticle-leibowitz", "sf-children-of-time", "sf-dispossessed", "sf-enders-game", "sf-fahrenheit-451",
    "sf-forever-war", "sf-fourmis", "sf-handmaids-tale", "sf-high-castle", "sf-hitchhiker", "sf-klara",
    "sf-left-hand-darkness", "sf-leviathan-wakes", "sf-martian", "sf-monde-des-a", "sf-murderbot", "sf-neuromancer",
    "sf-nuit-des-temps", "sf-planete-singes", "sf-rama", "sf-ready-player-one", "sf-slaughterhouse-five",
    "sf-snow-crash", "sf-solaris", "sf-stars-destination", "sf-starship-troopers", "sf-station-eleven",
    "sf-stranger-strange-land", "sf-the-road", "sf-time-machine", "sf-war-of-the-worlds", "sf-wool",
  ];
  const COVERS = [...LIBRARY, ...CLASSICS];
  const SQUARE = new Set(["hyperion-audio-01", "hyperion-audio-02", "hyperion-audio-03", "hyperion-audio-04"]);

  /** Deterministic noise in [0, 1) for a given integer. */
  function hash(n) {
    const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
    return x - Math.floor(x);
  }

  function shuffled(list, seed) {
    const out = list.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j = Math.floor(hash(seed * 1000 + i) * (i + 1));
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  }

  function coverImage(slug, eager = false) {
    const img = document.createElement("img");
    img.src = `covers/${slug}.jpg`;
    img.alt = "";
    img.loading = eager ? "eager" : "lazy";
    img.decoding = "async";
    if (SQUARE.has(slug)) img.classList.add("square");
    return img;
  }

  // ---------------------------------------------------------------------------
  // The showcase
  // ---------------------------------------------------------------------------

  // The three iPhones: they stand on the first screen, so the side ones wait
  // behind the library until the page moves, then come out with the scroll,
  // fully fanned after a third of a screen. Reduced motion leaves them fanned,
  // as the stylesheet draws them.
  const trio = document.querySelector(".trio");
  if (trio && !reducedMotion) {
    let pending = false;
    const fan = () => {
      pending = false;
      const progress = scrollY / (innerHeight * 0.33);
      trio.style.setProperty("--fan", String(Math.min(1, Math.max(0, progress)).toFixed(3)));
    };
    const schedule = () => {
      if (!pending) { pending = true; requestAnimationFrame(fan); }
    };
    addEventListener("scroll", schedule, { passive: true });
    addEventListener("resize", schedule);
    fan();
  }

  // ---------------------------------------------------------------------------
  // Feature cards
  // ---------------------------------------------------------------------------

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

  // The shelf: a box snaps around one spine after another, the count follows.
  const shelfDemo = document.querySelector("[data-shelf-demo]");
  whenVisible(shelfDemo, async () => {
    const spines = Array.from(shelfDemo.querySelectorAll(".spines i"));
    const count = shelfDemo.querySelector("[data-shelf-count] b");
    for (;;) {
      for (const s of spines) s.classList.remove("found");
      count.textContent = "0";
      await sleep(900);
      for (let i = 0; i < spines.length; i++) {
        spines[i].classList.add("found");
        count.textContent = String(i + 1);
        await sleep(reducedMotion ? 60 : 220);
      }
      await sleep(3200);
    }
  });

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

  // The download icon: a slow drift of covers behind the bookmark.
  const iconWall = document.querySelector("[data-icon-wall]");
  if (iconWall) {
    for (const slug of shuffled(COVERS, 42).slice(0, 24)) iconWall.appendChild(coverImage(slug));
    if (!reducedMotion) {
      const drift = (now) => {
        iconWall.style.transform = `rotate(-8deg) translateY(${-((now / 40000) % 1) * 30}%)`;
        requestAnimationFrame(drift);
      };
      requestAnimationFrame(drift);
    }
  }

  // ---------------------------------------------------------------------------
  // Reveal on scroll
  // ---------------------------------------------------------------------------

  for (const el of document.querySelectorAll(".card, .faq-list details, .section-title, .section-lead")) {
    el.classList.add("reveal");
  }
  const revealer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) { entry.target.classList.add("in"); revealer.unobserve(entry.target); }
    }
  }, { threshold: 0.15 });
  for (const el of document.querySelectorAll(".reveal")) revealer.observe(el);
})();
