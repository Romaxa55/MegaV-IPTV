/* Catalog data + procedural poster art generator. */
/* Posters are original SVG compositions (no copyrighted artwork). */

const POSTER_PALETTES = [
  // [bg1, bg2, accent, motif]
  ["#0c0a1a", "#3a1058", "#ffd166", "orb"],
  ["#0a1410", "#0d4a2e", "#e8b96a", "stripes"],
  ["#19090a", "#7a1b25", "#f8d7c2", "silhouette"],
  ["#0a0e1a", "#1d3a8a", "#9ec5ff", "grid"],
  ["#1a1208", "#a05a14", "#ffe9c2", "horizon"],
  ["#06060a", "#3b2862", "#e8b96a", "moon"],
  ["#0a0a0a", "#262626", "#ff3b5c", "type"],
  ["#0a1216", "#244e5e", "#a8e0d2", "wave"],
  ["#11070a", "#5a1242", "#ffb3d9", "orb"],
  ["#0d0d05", "#5a4a0e", "#ffe066", "type"],
  ["#06080d", "#1a2238", "#d4d8e6", "horizon"],
  ["#100610", "#4d0e6b", "#caa6ff", "moon"],
  ["#0e0a06", "#3b2810", "#e8b96a", "stripes"],
  ["#0a0a14", "#2c1f6d", "#a18bff", "grid"],
  ["#180a0a", "#8a2616", "#ffd1a8", "silhouette"],
  ["#08120e", "#0e3a2c", "#a8e0c4", "wave"],
];

const TITLES = [
  { t: "Полуночное эхо",   y: 1979, g: "Драма",   d: "1ч 48м" },
  { t: "Северный ветер",   y: 1985, g: "Триллер", d: "2ч 12м" },
  { t: "Каменный сад",     y: 2003, g: "Артхаус", d: "1ч 33м" },
  { t: "Перрон №7",        y: 1972, g: "Нуар",    d: "1ч 56м" },
  { t: "Тихая аллея",      y: 1968, g: "Драма",   d: "1ч 44м" },
  { t: "Долгая весна",     y: 1991, g: "Романтика", d: "2ч 03м" },
  { t: "Серый бархат",     y: 1958, g: "Нуар",    d: "1ч 38м" },
  { t: "Берег без имени",  y: 2011, g: "Триллер", d: "2ч 24м" },
  { t: "Ночной экспресс",  y: 1976, g: "Детектив", d: "1ч 52м" },
  { t: "Молочный путь",    y: 1995, g: "Семейный",d: "1ч 29м" },
  { t: "Декабрьский свет", y: 1983, g: "Драма",   d: "1ч 47м" },
  { t: "Антверпен",        y: 2018, g: "Артхаус", d: "1ч 36м" },
  { t: "Третий мост",      y: 1962, g: "Драма",   d: "2ч 06м" },
  { t: "Облака над Тегераном", y: 2004, g: "Драма", d: "1ч 51м" },
  { t: "Карта забытых",    y: 1989, g: "Приключения", d: "2ч 15м" },
  { t: "Желтый шарф",      y: 1971, g: "Романтика", d: "1ч 42м" },
  { t: "Окраины",          y: 2007, g: "Артхаус", d: "1ч 39м" },
  { t: "Голос рек",        y: 1996, g: "Документальный", d: "1ч 12м" },
];

const CHANNELS = [
  { name: "MM Classic HD",        cat: "Кино",     era: "ретро" },
  { name: "MM USSR Комедия HD",   cat: "Кино",     era: "ретро" },
  { name: "MM Стивен Кинг HD",    cat: "Кино",     era: "хоррор" },
  { name: "MM Артхаус HD",        cat: "Кино",     era: "арт" },
  { name: "MM Romance HD",        cat: "Кино",     era: "роман" },
  { name: "MM Action HD",         cat: "Кино",     era: "экшн" },
  { name: "Discovery 4K",         cat: "Док.",     era: "док" },
  { name: "BBC Earth",            cat: "Док.",     era: "док" },
  { name: "Eurosport 1",          cat: "Спорт",    era: "спорт" },
  { name: "Match! Premier",       cat: "Спорт",    era: "спорт" },
  { name: "MTV Live HD",          cat: "Музыка",   era: "муз" },
  { name: "Cartoon Network",      cat: "Дети",     era: "дет" },
];

// Procedural poster builder — returns a data: SVG URL
function buildPoster(idx, opts = {}) {
  const p = POSTER_PALETTES[idx % POSTER_PALETTES.length];
  const t = TITLES[idx % TITLES.length];
  const [bg1, bg2, ac, motif] = p;
  const w = opts.w || 600;
  const h = opts.h || 900;
  const seed = (idx * 7919) % 1000;

  const grain = `<filter id="g${idx}"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="${seed}"/><feColorMatrix values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 0.18 0"/></filter>`;

  let motifSVG = "";
  if (motif === "orb") {
    motifSVG = `
      <defs><radialGradient id="o${idx}" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="${ac}" stop-opacity="0.9"/>
        <stop offset="60%" stop-color="${ac}" stop-opacity="0.15"/>
        <stop offset="100%" stop-color="${ac}" stop-opacity="0"/>
      </radialGradient></defs>
      <circle cx="${w*0.5}" cy="${h*0.42}" r="${h*0.32}" fill="url(#o${idx})"/>
      <circle cx="${w*0.5}" cy="${h*0.42}" r="${h*0.18}" fill="${ac}" opacity="0.55"/>
    `;
  } else if (motif === "stripes") {
    motifSVG = Array.from({length: 7}, (_, i) =>
      `<rect x="${(i*w/7)+10}" y="${h*0.2}" width="${(w/7)-22}" height="${h*0.55}" fill="${ac}" opacity="${0.08 + (i%3)*0.06}"/>`
    ).join("");
  } else if (motif === "silhouette") {
    motifSVG = `
      <ellipse cx="${w*0.5}" cy="${h*0.35}" rx="${w*0.18}" ry="${w*0.18}" fill="#000" opacity="0.55"/>
      <rect x="${w*0.32}" y="${h*0.5}" width="${w*0.36}" height="${h*0.45}" fill="#000" opacity="0.55" rx="${w*0.16}"/>
      <rect x="0" y="${h*0.78}" width="${w}" height="${h*0.22}" fill="${ac}" opacity="0.18"/>
    `;
  } else if (motif === "grid") {
    let g = "";
    for (let i=0; i<10; i++) for (let j=0; j<14; j++)
      g += `<rect x="${i*w/10}" y="${j*h/14}" width="${w/10-2}" height="${h/14-2}" fill="${ac}" opacity="${(((i*3+j*7+seed)%9)/40)}"/>`;
    motifSVG = g;
  } else if (motif === "horizon") {
    motifSVG = `
      <rect x="0" y="${h*0.55}" width="${w}" height="${h*0.45}" fill="${ac}" opacity="0.25"/>
      <circle cx="${w*0.7}" cy="${h*0.55}" r="${h*0.16}" fill="${ac}" opacity="0.7"/>
      <line x1="0" y1="${h*0.55}" x2="${w}" y2="${h*0.55}" stroke="${ac}" stroke-width="1" opacity="0.6"/>
    `;
  } else if (motif === "moon") {
    motifSVG = `
      <circle cx="${w*0.7}" cy="${h*0.3}" r="${h*0.14}" fill="${ac}" opacity="0.85"/>
      <circle cx="${w*0.78}" cy="${h*0.26}" r="${h*0.12}" fill="${bg2}" opacity="0.95"/>
    `;
  } else if (motif === "type") {
    motifSVG = `
      <text x="${w*0.5}" y="${h*0.55}" text-anchor="middle"
            font-family="serif" font-style="italic" font-size="${w*0.55}"
            fill="${ac}" opacity="0.18">${t.t.charAt(0)}</text>
    `;
  } else if (motif === "wave") {
    let path = `M 0 ${h*0.55} `;
    for (let x=0; x<=w; x+=20) path += `L ${x} ${h*0.55 + Math.sin((x+seed)/40)*30} `;
    path += `L ${w} ${h} L 0 ${h} Z`;
    motifSVG = `<path d="${path}" fill="${ac}" opacity="0.35"/>
                <path d="${path}" fill="${ac}" opacity="0.18" transform="translate(0,-30)"/>`;
  }

  const showText = opts.showText !== false;
  const titleY = h - 90;
  const subY = h - 50;

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
    <defs>
      <linearGradient id="bg${idx}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="${bg1}"/>
        <stop offset="100%" stop-color="${bg2}"/>
      </linearGradient>
      ${grain}
    </defs>
    <rect width="${w}" height="${h}" fill="url(#bg${idx})"/>
    ${motifSVG}
    <rect width="${w}" height="${h}" filter="url(#g${idx})" opacity="0.6"/>
    <rect x="0" y="${h*0.65}" width="${w}" height="${h*0.35}" fill="url(#sh${idx})"/>
    <defs><linearGradient id="sh${idx}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${bg1}" stop-opacity="0"/>
      <stop offset="100%" stop-color="#000" stop-opacity="0.85"/>
    </linearGradient></defs>
    ${showText ? `
      <text x="${w*0.08}" y="${titleY}" font-family="Times New Roman, serif" font-style="italic"
            font-size="${w*0.085}" fill="#F4F1E9">${escapeXml(t.t)}</text>
      <text x="${w*0.08}" y="${subY}" font-family="JetBrains Mono, monospace"
            font-size="${w*0.025}" fill="#F4F1E9" opacity="0.7" letter-spacing="2">
        ${t.y} · ${t.g.toUpperCase()}
      </text>
    ` : ""}
  </svg>`;
  return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
}

function escapeXml(s) {
  return String(s).replace(/[<>&'"]/g, c => ({"<":"&lt;",">":"&gt;","&":"&amp;","'":"&apos;","\"":"&quot;"}[c]));
}

function buildBackdrop(idx, w = 1600, h = 900) {
  const p = POSTER_PALETTES[idx % POSTER_PALETTES.length];
  const [bg1, bg2, ac] = p;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
    <defs>
      <radialGradient id="r${idx}" cx="30%" cy="40%" r="65%">
        <stop offset="0%" stop-color="${ac}" stop-opacity="0.55"/>
        <stop offset="50%" stop-color="${bg2}" stop-opacity="0.85"/>
        <stop offset="100%" stop-color="${bg1}" stop-opacity="1"/>
      </radialGradient>
    </defs>
    <rect width="${w}" height="${h}" fill="${bg1}"/>
    <rect width="${w}" height="${h}" fill="url(#r${idx})"/>
    <circle cx="${w*0.25}" cy="${h*0.4}" r="${h*0.5}" fill="${ac}" opacity="0.18"/>
    <circle cx="${w*0.7}" cy="${h*0.3}" r="${h*0.3}" fill="${bg2}" opacity="0.55"/>
  </svg>`;
  return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
}

Object.assign(window, {
  POSTER_PALETTES, TITLES, CHANNELS, buildPoster, buildBackdrop
});
