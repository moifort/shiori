/* Shiori landing page.
 *
 * Everything that moves on this page is driven from here:
 *  1. The wall: rows of covers gliding across a tilted plane under the hero.
 *  2. The scan demo: a scripted loop that frames a cover, takes the photo,
 *     lets the AI read it, fills the record line by line, then files the book
 *     in the library.
 *  3. Small loops in the feature cards.
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

  // The showcase library's covers, shuffled once per row so no two rows match.
  const COVERS = [
    "nom-du-vent", "one-piece-01", "dune", "frieren-01", "trois-corps", "blacksad-01", "projet-derniere-chance",
    "blue-lock-01", "hyperion", "chateau-animaux-01", "fourth-wing", "spy-family-01", "sapiens", "one-piece-05",
    "peur-du-sage", "frieren-03", "veiller-sur-elle", "blue-lock-04", "fondation", "dcc-01", "messie-de-dune",
    "blacksad-03", "jacaranda", "one-piece-12", "foret-sombre", "frieren-07", "demain-et-demain", "blue-lock-09",
    "shibumi", "chateau-animaux-02", "horde-du-contrevent", "one-piece-100", "monte-cristo", "dcc-03",
    "sorceleur-01", "frieren-10", "furtifs", "blue-lock-32", "mort-immortelle", "blacksad-05", "one-piece-110",
    "dcc-05", "frieren-14", "chateau-animaux-04", "blue-lock-35", "one-piece-114", "blacksad-07", "dcc-06",
    "frieren-15", "one-piece-08", "blue-lock-15", "blacksad-02", "one-piece-03", "frieren-05", "dcc-02",
  ];
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
  // The wall
  // ---------------------------------------------------------------------------

  const wall = document.querySelector("[data-wall]");
  if (wall) {
    const fade = document.createElement("div");
    fade.className = "wall-fade";
    wall.appendChild(fade);

    const rows = Array.from(wall.querySelectorAll("[data-wall-row]"));
    rows.forEach((row, index) => {
      // Fourteen covers a row, laid twice so the loop never shows a seam.
      const slugs = shuffled(COVERS, index + 1).slice(0, 14);
      for (const slug of [...slugs, ...slugs]) row.appendChild(coverImage(slug, index < 2));
      // Each row starts somewhere else along its length.
      row.dataset.offset = String(hash(index + 7));
    });

    let visible = true;
    new IntersectionObserver((entries) => { visible = entries.some((e) => e.isIntersecting); }, { rootMargin: "100px" }).observe(wall);

    // Half the row's width per 60 s at speed 1, moved frame by frame rather
    // than by a CSS animation, which iOS Safari paints only in part on a
    // track this wide. Reduced motion keeps the wall still.
    if (!reducedMotion) {
      const glide = (now) => {
        if (visible) {
          for (const row of rows) {
            const half = row.scrollWidth / 2;
            if (!half) continue;
            const speed = Number(row.dataset.speed || 1);
            const phase = ((now / 60000) * speed + Number(row.dataset.offset)) % 1;
            const x = -((phase + 1) % 1) * half;
            row.style.transform = `translate3d(${x}px, 0, 0)`;
          }
        }
        requestAnimationFrame(glide);
      };
      requestAnimationFrame(glide);
    } else {
      for (const row of rows) row.style.transform = `translate3d(${-Number(row.dataset.offset) * 40}%, 0, 0)`;
    }
  }

  // ---------------------------------------------------------------------------
  // The scan demo
  // ---------------------------------------------------------------------------

  const BOOKS_FR = [
    {
      slug: "hyperion", title: "Hypérion", author: "Dan Simmons", series: "Les Cantos d'Hypérion · Tome 1",
      genre: "Science-fiction", publisher: "Robert Laffont", year: "1989", pages: "576", language: "Français",
      summary: "Sept pèlerins montent vers les Tombeaux du Temps, et chacun raconte ce qui l'amène au gritche.",
    },
    {
      slug: "nom-du-vent", title: "Le Nom du vent", author: "Patrick Rothfuss", series: "Chronique du tueur de roi · Tome 1",
      genre: "Fantasy", publisher: "Bragelonne", year: "2007", pages: "662", language: "Français",
      summary: "Kvothe, aubergiste sous un faux nom, raconte comment il est devenu la légende que tout le monde croit morte.",
    },
    {
      slug: "one-piece-01", title: "One Piece, tome 1", author: "Eiichirō Oda", series: "One Piece · Tome 1",
      genre: "Shōnen", publisher: "Glénat", year: "1997", pages: "208", language: "Français",
      summary: "Luffy, un garçon au corps élastique, prend la mer pour trouver le One Piece et devenir le roi des pirates.",
    },
    {
      slug: "projet-derniere-chance", title: "Projet Dernière Chance", author: "Andy Weir", series: "—",
      genre: "Science-fiction", publisher: "Bragelonne", year: "2021", pages: "480", language: "Français",
      summary: "Un homme se réveille seul à bord d'un vaisseau, sans mémoire, avec l'humanité à sauver.",
    },
    {
      slug: "frieren-01", title: "Frieren, tome 1", author: "Kanehito Yamada, Tsukasa Abe", series: "Frieren · Tome 1",
      genre: "Fantasy", publisher: "Ki-oon", year: "2020", pages: "192", language: "Français",
      summary: "La magicienne elfe Frieren survit à ses compagnons et part comprendre, trop tard, ce qu'ils étaient pour elle.",
    },
  ];
  const BOOKS_EN = [
    {
      slug: "en/hyperion", title: "Hyperion", author: "Dan Simmons", series: "Hyperion Cantos · Book 1",
      genre: "Science fiction", publisher: "Bantam Spectra", year: "1989", pages: "482", language: "English",
      summary: "Seven pilgrims travel to the Time Tombs, and each tells the tale that brings them to the Shrike.",
    },
    {
      slug: "en/nom-du-vent", title: "The Name of the Wind", author: "Patrick Rothfuss", series: "The Kingkiller Chronicle · Book 1",
      genre: "Fantasy", publisher: "DAW Books", year: "2007", pages: "662", language: "English",
      summary: "Kvothe, an innkeeper under a false name, tells how he became the legend everyone believes dead.",
    },
    {
      slug: "en/one-piece-01", title: "One Piece, Vol. 1", author: "Eiichiro Oda", series: "One Piece · Vol. 1",
      genre: "Shōnen", publisher: "VIZ Media", year: "1997", pages: "216", language: "English",
      summary: "Luffy, a boy with a rubber body, sets sail to find the One Piece and become King of the Pirates.",
    },
    {
      slug: "en/projet-derniere-chance", title: "Project Hail Mary", author: "Andy Weir", series: "—",
      genre: "Science fiction", publisher: "Ballantine Books", year: "2021", pages: "476", language: "English",
      summary: "A man wakes alone on a spaceship with no memory and humanity to save.",
    },
    {
      slug: "en/frieren-01", title: "Frieren, Vol. 1", author: "Kanehito Yamada, Tsukasa Abe", series: "Frieren · Vol. 1",
      genre: "Fantasy", publisher: "VIZ Media", year: "2021", pages: "192", language: "English",
      summary: "The elf mage Frieren outlives her companions and sets out to understand, too late, what they meant to her.",
    },
  ];
  const BOOKS = english ? BOOKS_EN : BOOKS_FR;

  const dom = {
    phone: document.querySelector("[data-phone]"),
    camera: document.querySelector("[data-camera]"),
    cameraCover: document.querySelector("[data-camera-cover]"),
    flash: document.querySelector("[data-flash]"),
    shutter: document.querySelector("[data-shutter]"),
    record: document.querySelector("[data-record]"),
    recordCover: document.querySelector("[data-record-cover]"),
    recordOk: document.querySelector("[data-record-ok]"),
    shelf: document.querySelector("[data-shelf]"),
    shelfGrid: document.querySelector("[data-shelf-grid]"),
    orb: document.querySelector("[data-orb]"),
    steps: Array.from(document.querySelectorAll("[data-step]")),
    caption: document.querySelector("[data-tl-caption]"),
    fields: Object.fromEntries(Array.from(document.querySelectorAll("[data-field]")).map((el) => [el.dataset.field, el])),
  };

  /** Lights the timeline up to `name`: earlier steps done, that one active. */
  function setStep(name) {
    if (dom.caption) {
      const label = dom.steps.find((li) => li.dataset.step === name)?.querySelector(".tl-label");
      dom.caption.innerHTML = label ? label.innerHTML : "";
    }
    let reached = false;
    for (const li of dom.steps) {
      li.classList.remove("active", "done");
      if (name === null) continue;
      if (li.dataset.step === name) { li.classList.add("active"); reached = true; }
      else if (!reached) li.classList.add("done");
    }
  }

  async function typeInto(el, text, perChar) {
    el.classList.add("live");
    for (let i = 1; i <= text.length; i++) {
      el.textContent = text.slice(0, i);
      await sleep(perChar);
    }
    el.classList.remove("live");
    el.classList.add("filled");
  }

  // The library the scanned books land in: a dozen covers already there.
  const SHELF_START = ["one-piece-110", "blue-lock-35", "frieren-15", "dcc-06", "veiller-sur-elle", "blacksad-07", "trois-corps", "chateau-animaux-04", "sapiens", "monte-cristo", "fourth-wing"];

  let demoVisible = false;

  async function playBook(book) {
    const fast = reducedMotion;
    // Set the scene: the camera, the cover slightly off.
    for (const el of Object.values(dom.fields)) { el.textContent = ""; el.classList.remove("filled", "live"); }
    dom.recordOk.classList.remove("ready");
    dom.record.classList.remove("visible");
    dom.shelf.classList.remove("visible");
    dom.camera.classList.remove("hidden", "framed");
    dom.phone.classList.add("camera-on");
    dom.cameraCover.src = `covers/${book.slug}.jpg`;
    dom.recordCover.src = `covers/${book.slug}.jpg`;
    setStep(null);
    await sleep(fast ? 300 : 900);

    // Frame it.
    setStep("frame");
    dom.camera.classList.add("framed");
    await sleep(fast ? 400 : 1400);

    // Take the photo.
    dom.shutter.classList.add("pressed");
    dom.flash.classList.add("on");
    await sleep(160);
    dom.shutter.classList.remove("pressed");
    await sleep(400);
    dom.flash.classList.remove("on");

    // The AI reads the cover: the orb breathes over the frozen photo.
    setStep("recognize");
    dom.orb.classList.add("on");
    await sleep(fast ? 500 : 1700);
    dom.orb.classList.remove("on");

    // The record comes up and fills, line by line.
    setStep("fill");
    dom.camera.classList.add("hidden");
    dom.phone.classList.remove("camera-on");
    dom.record.classList.add("visible");
    await sleep(350);
    const perChar = fast ? 2 : 16;
    for (const key of ["title", "author", "series", "genre", "publisher", "year", "pages", "language"]) {
      await typeInto(dom.fields[key], book[key], perChar);
      await sleep(fast ? 20 : 90);
    }
    await typeInto(dom.fields.summary, book.summary, fast ? 1 : 7);
    dom.recordOk.classList.add("ready");
    await sleep(fast ? 400 : 1400);

    // Into the library.
    setStep("shelf");
    dom.record.classList.remove("visible");
    dom.shelf.classList.add("visible");
    const incoming = coverImage(book.slug, true);
    incoming.classList.add("arriving");
    dom.shelfGrid.prepend(incoming);
    while (dom.shelfGrid.children.length > 16) dom.shelfGrid.lastElementChild.remove();
    await sleep(fast ? 800 : 2600);
  }

  if (dom.phone) {
    for (const slug of SHELF_START) dom.shelfGrid.appendChild(coverImage(slug));
    new IntersectionObserver((entries) => {
      demoVisible = entries.some((e) => e.isIntersecting);
    }, { threshold: 0.2 }).observe(document.getElementById("demo"));

    (async () => {
      let index = 0;
      for (;;) {
        await playBook(BOOKS[index]);
        if (!demoVisible) { await sleep(500); continue; }
        index = (index + 1) % BOOKS.length;
      }
    })();
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

  // The series ring fills up to the volumes read, with the count.
  const seriesDemo = document.querySelector("[data-series-demo]");
  whenVisible(seriesDemo, async () => {
    const arc = seriesDemo.querySelector("[data-series-arc]");
    const count = seriesDemo.querySelector("[data-series-count]");
    const read = 22, total = 114;
    for (;;) {
      arc.style.transition = "none";
      arc.style.strokeDashoffset = "100";
      count.textContent = "0";
      await sleep(600);
      arc.style.transition = "stroke-dashoffset 1.6s cubic-bezier(0.2, 0.8, 0.2, 1)";
      arc.style.strokeDashoffset = String(100 - (read / total) * 100);
      const started = performance.now();
      while (performance.now() - started < 1600) {
        const t = Math.min(1, (performance.now() - started) / 1600);
        count.textContent = String(Math.round(read * (1 - Math.pow(1 - t, 3))));
        await sleep(40);
      }
      count.textContent = String(read);
      await sleep(5000);
    }
  });

  // The notifications, one after the other.
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
    ];
    const alertsEn = [
      { title: "Blue Lock, Vol. 35 is out today", body: "Muneyuki Kaneshiro · Blue Lock · Vol. 35" },
      { title: "Frieren, Vol. 15 is available", body: "Kanehito Yamada · the volume you were waiting for" },
      { title: "La Horde du Contrevent is out in English", body: "Alain Damasio · The Windwalkers" },
      { title: "Hyperion is out as an audiobook", body: "Dan Simmons · available on Audible" },
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

  // The statistics: bars grow, the total counts up.
  const statsDemo = document.querySelector("[data-stats-demo]");
  whenVisible(statsDemo, async () => {
    const total = statsDemo.querySelector("[data-stats-total]");
    const target = 11504;
    const format = (n) => english ? n.toLocaleString("en-US") : n.toLocaleString("fr-FR").replace(/ | /g, " ");
    for (;;) {
      statsDemo.classList.remove("in");
      total.textContent = "0";
      await sleep(500);
      statsDemo.classList.add("in");
      const started = performance.now();
      while (performance.now() - started < 1500) {
        const t = Math.min(1, (performance.now() - started) / 1500);
        total.textContent = format(Math.round(target * (1 - Math.pow(1 - t, 3))));
        await sleep(40);
      }
      total.textContent = format(target);
      await sleep(6000);
    }
  });

  // Friends: a heart lands on each favourite, then the challenge bars grow.
  const friendsDemo = document.querySelector("[data-friends-demo]");
  whenVisible(friendsDemo, async () => {
    const rows = Array.from(friendsDemo.querySelectorAll("[data-friend]"));
    for (;;) {
      for (const r of rows) r.classList.remove("loved");
      friendsDemo.classList.remove("in");
      await sleep(600);
      for (const r of rows) { r.classList.add("loved"); await sleep(700); }
      friendsDemo.classList.add("in");
      await sleep(5000);
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
