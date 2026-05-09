/* Data layer — production shape from https://iptv.megav.app
   Tries live fetch first, falls back to realistic fixtures matching NowPlayingItem schema.
   Computes isNow / progress / elapsed / remaining / parsedYear / synopsis on the client. */

const API_BASE = "https://iptv.megav.app";

// Realistic fixtures matching NowPlayingItem shape — used if CORS / network blocks fetch.
// Times are anchored to "now" so progress bars look alive.
const NOW = () => new Date();
const iso = (mins) => new Date(Date.now() + mins * 60_000).toISOString();

const FIXTURE_FEATURED = [
  {
    channelId: 1234, channelName: "MM Classic HD", groupTitle: "Кино",
    logoUrl: null,
    thumbnailUrl: null,
    program: {
      id: 987654, channelId: 1234,
      title: "Волны Чёрного моря",
      description: "1975 г.\n\nВ шумной и весёлой Одессе в разгаре лето. Непоседливый Гаврик и его дед ловят рыбу, продавая её жадной мадам Стороженко с привоза, а Петя, сын кондуктора, бредит подвигами и революцией.",
      category: "Семейный", icon: null, lang: "ru",
      start: iso(-44), end: iso(30),
    },
  },
  {
    channelId: 2002, channelName: "MM Romance HD", groupTitle: "Кино",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 222, channelId: 2002, title: "Дикая орхидея",
      description: "1989 г.\n\nЮная американская юристка приезжает в Рио и встречает загадочного миллионера, чьи правила игры ей предстоит выучить за одну ночь карнавала.",
      category: "Драма", icon: null, lang: "ru",
      start: iso(-12), end: iso(78),
    },
  },
  {
    channelId: 3003, channelName: "Match! Премьер", groupTitle: "Спорт",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 333, channelId: 3003, title: "ЦСКА — Зенит",
      description: "Прямая трансляция матча 27-го тура РПЛ из Москвы. Комментируют Геннадий Орлов и Константин Генич.",
      category: "Футбол", icon: null, lang: "ru",
      start: iso(-22), end: iso(68),
    },
  },
  {
    channelId: 4004, channelName: "BBC Earth", groupTitle: "Документальные",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 444, channelId: 4004, title: "Голубая планета II",
      description: "2017 г.\n\nКоралловые рифы Большого Барьера, населённые миллионами форм жизни — от карликовых морских коньков до акул-молотов.",
      category: "Документальный", icon: null, lang: "ru",
      start: iso(-46), end: iso(14),
    },
  },
  {
    channelId: 5005, channelName: "MM Артхаус HD", groupTitle: "Кино",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 555, channelId: 5005, title: "Зеркало",
      description: "1974 г.\n\nАндрей Тарковский плетёт автобиографическую медитацию из снов, кадров военной хроники и стихов отца.",
      category: "Драма", icon: null, lang: "ru",
      start: iso(-100), end: iso(6),
    },
  },
  {
    channelId: 6006, channelName: "МУЗ-ТВ HD", groupTitle: "Музыка",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 666, channelId: 6006, title: "Танцпол. Прямой эфир",
      description: "Электронные релизы недели и интервью с резидентами клуба Mutabor.",
      category: "Музыка", icon: null, lang: "ru",
      start: iso(-8), end: iso(52),
    },
  },
  {
    channelId: 7007, channelName: "Карусель", groupTitle: "Детские",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 777, channelId: 7007, title: "Барбоскины",
      description: "Семейная мультсерия о собачьем семействе из шести детей.",
      category: "Анимация", icon: null, lang: "ru",
      start: iso(-3), end: iso(12),
    },
  },
  {
    channelId: 8008, channelName: "Россия 24", groupTitle: "Новости",
    logoUrl: null, thumbnailUrl: null,
    program: {
      id: 888, channelId: 8008, title: "Вести в 04:00",
      description: "Главные события ночи — экономика, политика, погода.",
      category: "Новости", icon: null, lang: "ru",
      start: iso(-2), end: iso(28),
    },
  },
];

const FIXTURE_CATEGORIES = [
  { name: "Кино",            count: 142 },
  { name: "Спорт",           count: 38 },
  { name: "Новости",         count: 24 },
  { name: "Документальные",  count: 19 },
  { name: "Детские",         count: 16 },
  { name: "Музыка",          count: 12 },
  { name: "Сериалы",         count: 47 },
  { name: "18+",             count: 9 },
];

const FIXTURE_MOVIES = {
  total: 142,
  items: [
    FIXTURE_FEATURED[0], FIXTURE_FEATURED[1], FIXTURE_FEATURED[4],
    {
      channelId: 9009, channelName: "MM USSR Комедия HD", groupTitle: "Кино",
      logoUrl: null, thumbnailUrl: null,
      program: {
        id: 909, channelId: 9009, title: "Бриллиантовая рука",
        description: "1969 г.\n\nСкромного советского служащего по ошибке принимают за курьера контрабандистов и под видом перелома гипсуют ему руку с золотом.",
        category: "Комедия", icon: null, lang: "ru",
        start: iso(-15), end: iso(85),
      },
    },
    {
      channelId: 1010, channelName: "MM Action HD", groupTitle: "Кино",
      logoUrl: null, thumbnailUrl: null,
      program: {
        id: 1011, channelId: 1010, title: "Тёмная башня",
        description: "2017 г.\n\nПоследний стрелок преследует Человека в чёрном через миры, чтобы спасти Башню, удерживающую вселенную.",
        category: "Фэнтези", icon: null, lang: "ru",
        start: iso(-30), end: iso(60),
      },
    },
    {
      channelId: 1111, channelName: "MM Pirates HD", groupTitle: "Кино",
      logoUrl: null, thumbnailUrl: null,
      program: {
        id: 1112, channelId: 1111, title: "Пираты Карибского моря: На странных берегах",
        description: "2011 г.\n\nДжек Воробей оказывается на борту корабля Чёрной Бороды — в погоне за источником вечной молодости.",
        category: "Приключения", icon: null, lang: "ru",
        start: iso(-18), end: iso(72),
      },
    },
  ],
};

// --- Computed helpers ---
function computeProgress(program) {
  if (!program) return null;
  const start = new Date(program.start).getTime();
  const end   = new Date(program.end).getTime();
  const now   = Date.now();
  const isNow = now >= start && now < end;
  const total = end - start;
  const elapsed = Math.max(0, Math.min(total, now - start));
  const remaining = Math.max(0, end - now);
  const progress = total > 0 ? elapsed / total : 0;
  return {
    isNow,
    progress,
    elapsedMin: Math.round(elapsed / 60_000),
    remainingMin: Math.round(remaining / 60_000),
  };
}

function parseYear(description) {
  if (!description) return null;
  const s = String(description).replace(/\\n/g, "\n");
  const m = s.match(/(\d{4})\s*г?\.?/);
  return m ? m[1] : null;
}

function parseSynopsis(description) {
  if (!description) return null;
  // Normalise escaped newlines ("\\n") that arrive as literal text from prod.
  const s = String(description)
    .replace(/\\n/g, "\n")
    .replace(/\r/g, "");
  const parts = s.split(/\n{2,}/);
  const body = (parts.length > 1 ? parts.slice(1).join(" ") : parts[0]);
  return body.replace(/\s+/g, " ").trim();
}

// --- Normalisers (live API shape varies from spec) ---
function absUrl(u) {
  if (!u) return u;
  if (u.startsWith("//")) return "https:" + u;
  if (u.startsWith("/")) return API_BASE + u;
  return u;
}
function normItem(it) {
  if (!it) return it;
  return {
    ...it,
    thumbnailUrl: absUrl(it.thumbnailUrl),
    logoUrl: absUrl(it.logoUrl),
    program: it.program ? { ...it.program, icon: absUrl(it.program.icon) } : it.program,
  };
}
function normCategory(c) {
  // live: { category, channelCount }; fixture: { name, count }
  return {
    name:  c.name  ?? c.category ?? "",
    count: c.count ?? c.channelCount ?? 0,
  };
}

// --- Network with timeout + fallback ---
async function fetchJson(url, fallback, timeoutMs = 2500) {
  try {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    const r = await fetch(url, { signal: ctl.signal, mode: "cors" });
    clearTimeout(timer);
    if (!r.ok) throw new Error(r.status);
    return { data: await r.json(), source: "live" };
  } catch (e) {
    return { data: fallback, source: "fixture", error: String(e) };
  }
}

async function loadFeatured(limit = 10) {
  const r = await fetchJson(`${API_BASE}/api/epg/featured?limit=${limit}`, FIXTURE_FEATURED);
  const arr = Array.isArray(r.data) ? r.data : (r.data?.items || FIXTURE_FEATURED);
  return { ...r, data: arr.map(normItem) };
}
async function loadCategories() {
  const r = await fetchJson(`${API_BASE}/api/categories`, FIXTURE_CATEGORIES);
  const arr = Array.isArray(r.data) ? r.data : (r.data?.items || FIXTURE_CATEGORIES);
  return { ...r, data: arr.map(normCategory).filter(c => c.name) };
}
async function loadCategory(name, limit = 12) {
  const enc = encodeURIComponent(name);
  const pool = [...FIXTURE_FEATURED, ...FIXTURE_MOVIES.items];
  const fb = pool.filter(p => p.groupTitle === name);
  const r = await fetchJson(`${API_BASE}/api/epg/now?category=${enc}&limit=${limit}&offset=0`, fb.length ? fb : pool.slice(0, 6));
  const arr = Array.isArray(r.data) ? r.data : (r.data?.items || []);
  return { ...r, data: arr.map(normItem) };
}
async function loadMovies(limit = 20) {
  const r = await fetchJson(`${API_BASE}/api/epg/movies?limit=${limit}&offset=0`, FIXTURE_MOVIES);
  const items = Array.isArray(r.data?.items) ? r.data.items : (Array.isArray(r.data) ? r.data : FIXTURE_MOVIES.items);
  const total = r.data?.total ?? items.length;
  return { ...r, data: { items: items.map(normItem), total } };
}

Object.assign(window, {
  API_BASE,
  computeProgress, parseYear, parseSynopsis,
  loadFeatured, loadCategories, loadCategory, loadMovies,
});
