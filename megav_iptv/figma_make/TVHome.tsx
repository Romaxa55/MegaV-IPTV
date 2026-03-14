import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { useApp } from '../../context/AppContext';
import { TVPlayer } from './TVPlayer';
import { TVSettings } from './TVSettings';
import { motion, AnimatePresence } from 'motion/react';
import {
  Star, Clock, Play, X, Film,
  ChevronLeft, ChevronRight, Settings, Tv,
  Bell, BellOff, Timer, Calendar,
} from 'lucide-react';
import { detectGeoLocation, type GeoData } from './GeoService';
import {
  buildCinemaCategories, getFeaturedContent, formatTime, formatDuration,
  getRatingColor, getAgeColor, getContentTypeLabel, getContentTypeIcon,
  type ContentOnAir, type CinemaCategory,
} from './EPGService';

export function TVHome() {
  const {
    channels, currentChannel, showPlayer,
    setShowPlayer, playChannel,
  } = useApp();

  const [showSettings, setShowSettings] = useState(false);
  const [currentTime, setCurrentTime] = useState(new Date());
  const [geoData] = useState<GeoData>(() => detectGeoLocation('UG'));

  // Cinema state
  const [categories, setCategories] = useState<CinemaCategory[]>([]);
  const [featured, setFeatured] = useState<ContentOnAir[]>([]);
  const [heroIndex, setHeroIndex] = useState(0);
  const [selectedContent, setSelectedContent] = useState<ContentOnAir | null>(null);
  const [reminders, setReminders] = useState<Set<string>>(new Set());
  const [showRemindToast, setShowRemindToast] = useState(false);
  const [focusedRow, setFocusedRow] = useState(0);
  const [focusedCol, setFocusedCol] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 30000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    setCategories(buildCinemaCategories(currentTime));
    setFeatured(getFeaturedContent(currentTime));
  }, [currentTime]);

  useEffect(() => {
    if (featured.length <= 1) return;
    const timer = setInterval(() => setHeroIndex(p => (p + 1) % featured.length), 8000);
    return () => clearInterval(timer);
  }, [featured.length]);

  useEffect(() => {
    if (featured[heroIndex]) setSelectedContent(featured[heroIndex]);
  }, [heroIndex, featured]);

  const toggleReminder = useCallback((id: string) => {
    setReminders(prev => {
      const next = new Set(prev);
      if (next.has(id)) { next.delete(id); }
      else {
        next.add(id);
        setShowRemindToast(true);
        setTimeout(() => setShowRemindToast(false), 3000);
      }
      return next;
    });
  }, []);

  const handlePlayContent = useCallback((item: ContentOnAir) => {
    const ch = channels.find(c => c.id === item.program.channelId);
    if (ch) playChannel(ch);
  }, [channels, playChannel]);

  const mySchedule = useMemo(() => {
    if (reminders.size === 0) return [];
    const all = categories.flatMap(c => c.items);
    return all.filter(item => reminders.has(item.program.id))
      .sort((a, b) => a.program.startTime.getTime() - b.program.startTime.getTime());
  }, [categories, reminders]);

  // Keyboard nav
  useEffect(() => {
    if (showPlayer || showSettings) return;
    const handler = (e: KeyboardEvent) => {
      switch (e.key) {
        case 'ArrowLeft':
          e.preventDefault();
          if (focusedRow === -1) setHeroIndex(p => p > 0 ? p - 1 : featured.length - 1);
          else setFocusedCol(c => Math.max(0, c - 1));
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (focusedRow === -1) setHeroIndex(p => (p + 1) % featured.length);
          else {
            const cat = categories[focusedRow];
            if (cat) setFocusedCol(c => Math.min(cat.items.length - 1, c + 1));
          }
          break;
        case 'ArrowUp':
          e.preventDefault();
          if (focusedRow <= 0) setFocusedRow(-1);
          else setFocusedRow(r => r - 1);
          break;
        case 'ArrowDown':
          e.preventDefault();
          if (focusedRow === -1) { setFocusedRow(0); setFocusedCol(0); }
          else setFocusedRow(r => Math.min(categories.length - 1, r + 1));
          break;
        case 'Enter':
          e.preventDefault();
          if (focusedRow === -1 && featured[heroIndex]) {
            if (featured[heroIndex].status === 'live') handlePlayContent(featured[heroIndex]);
            else toggleReminder(featured[heroIndex].program.id);
          } else {
            const cat = categories[focusedRow];
            const item = cat?.items[Math.min(focusedCol, (cat?.items.length || 1) - 1)];
            if (item) {
              if (item.status === 'live') handlePlayContent(item);
              else toggleReminder(item.program.id);
            }
          }
          break;
        case 'r': e.preventDefault();
          if (selectedContent) toggleReminder(selectedContent.program.id);
          break;
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [showPlayer, showSettings, focusedRow, focusedCol, categories, featured, heroIndex, selectedContent, handlePlayContent, toggleReminder]);

  useEffect(() => {
    if (focusedRow >= 0) {
      const cat = categories[focusedRow];
      if (cat) {
        const col = Math.min(focusedCol, cat.items.length - 1);
        if (cat.items[col]) setSelectedContent(cat.items[col]);
      }
    }
  }, [focusedRow, focusedCol, categories]);

  const fmtTime = (d: Date) => d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });

  if (showPlayer && currentChannel) {
    return <TVPlayer onBack={() => setShowPlayer(false)} />;
  }

  const heroItem = featured[heroIndex];

  return (
    <div className="h-screen bg-[#08080f] flex flex-col overflow-hidden select-none">

      {/* ===== HERO SECTION ===== */}
      <div className="relative shrink-0 overflow-hidden" style={{ height: '56vh', minHeight: '380px' }}>
        {/* Backdrop */}
        <AnimatePresence mode="wait">
          {heroItem && (
            <motion.div
              key={heroItem.program.id}
              initial={{ opacity: 0, scale: 1.05 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 1.2 }}
              className="absolute inset-0"
            >
              <img src={heroItem.program.backdrop} alt="" className="w-full h-full object-cover" />
            </motion.div>
          )}
        </AnimatePresence>

        {/* Gradients */}
        <div className="absolute inset-0 bg-gradient-to-r from-[#08080f] via-[#08080f]/70 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#08080f] via-transparent to-[#08080f]/50" />
        <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-[#08080f] to-transparent" />

        {/* ===== TOP BAR: Logo left — info right ===== */}
        <div className="absolute top-0 left-0 right-0 z-20 px-8 py-5 flex items-center">
          {/* Logo */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#6366f1] to-[#a78bfa] flex items-center justify-center shadow-lg shadow-indigo-500/25">
              <Tv className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="text-white/95 text-sm tracking-wider">MegaV</span>
              <span className="text-white/30 text-[10px] ml-1.5 tracking-widest">IPTV</span>
            </div>
          </div>

          <div className="flex-1" />

          {/* Right: geo, weather, time, settings */}
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 px-3.5 py-2 bg-white/[0.06] rounded-xl border border-white/[0.05] backdrop-blur-md">
              <span className="text-base">{geoData.location.flag}</span>
              <span className="text-white/50 text-xs">{geoData.location.city}</span>
              <span className="text-white/10 mx-0.5">|</span>
              <span className="text-base">{geoData.weather.icon}</span>
              <span className="text-white/50 text-xs">{geoData.weather.temp}°</span>
              <span className="text-white/10 mx-0.5">|</span>
              <span className="text-white/40 text-xs">{fmtTime(currentTime)}</span>
            </div>
            <button
              onClick={() => setShowSettings(true)}
              className="w-10 h-10 rounded-xl bg-white/[0.06] flex items-center justify-center hover:bg-white/[0.12] transition-colors border border-white/[0.05] backdrop-blur-md"
            >
              <Settings className="w-4 h-4 text-white/35" />
            </button>
          </div>
        </div>

        {/* ===== HERO CONTENT ===== */}
        <AnimatePresence mode="wait">
          {heroItem && (
            <motion.div
              key={heroItem.program.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.5 }}
              className="absolute bottom-12 left-8 right-8 z-10 flex gap-8"
            >
              <div className="flex-1 max-w-2xl">
                {/* Badges */}
                <div className="flex items-center gap-2 mb-3 flex-wrap">
                  {heroItem.status === 'live' && (
                    <span className="px-2.5 py-1 bg-red-500/90 rounded-lg text-white text-[11px] tracking-wide flex items-center gap-1.5 shadow-lg shadow-red-500/20">
                      <span className="w-1.5 h-1.5 rounded-full bg-white animate-pulse" />
                      В ЭФИРЕ
                    </span>
                  )}
                  {heroItem.status === 'starting_soon' && (
                    <span className="px-2.5 py-1 bg-amber-500/90 rounded-lg text-white text-[11px]">СКОРО</span>
                  )}
                  {heroItem.status === 'upcoming' && (
                    <span className="px-2.5 py-1 bg-indigo-500/80 rounded-lg text-white text-[11px]">СЕГОДНЯ</span>
                  )}
                  <span className="px-2.5 py-1 bg-white/10 backdrop-blur-md rounded-lg text-white/60 text-[11px]">
                    {heroItem.program.channelLogo} {heroItem.program.channelName}
                  </span>
                  <span className="px-2 py-1 bg-white/[0.06] rounded-lg text-white/40 text-[10px]">
                    {getContentTypeLabel(heroItem.program.contentType)}
                  </span>
                  {heroItem.program.ageRating && (
                    <span
                      className="px-2 py-0.5 rounded-lg text-[10px] border"
                      style={{
                        color: getAgeColor(heroItem.program.ageRating),
                        borderColor: getAgeColor(heroItem.program.ageRating) + '40',
                        backgroundColor: getAgeColor(heroItem.program.ageRating) + '10',
                      }}
                    >
                      {heroItem.program.ageRating}
                    </span>
                  )}
                </div>

                {/* Title */}
                <h1 className="text-white text-4xl mb-1 drop-shadow-2xl">{heroItem.program.title}</h1>
                {heroItem.program.originalTitle && (
                  <p className="text-white/25 text-sm mb-2">{heroItem.program.originalTitle}</p>
                )}
                {heroItem.program.subtitle && (
                  <p className="text-white/40 text-sm mb-2">{heroItem.program.subtitle}</p>
                )}

                {/* Meta */}
                <div className="flex items-center gap-3 mb-3 flex-wrap">
                  {heroItem.program.rating && (
                    <div className="flex items-center gap-1">
                      <Star className="w-3.5 h-3.5" style={{ color: getRatingColor(heroItem.program.rating) }} />
                      <span className="text-sm" style={{ color: getRatingColor(heroItem.program.rating) }}>
                        {heroItem.program.rating.toFixed(1)}
                      </span>
                    </div>
                  )}
                  {heroItem.program.year && (
                    <><span className="text-white/15">•</span><span className="text-white/40 text-xs">{heroItem.program.year}</span></>
                  )}
                  <span className="text-white/15">•</span>
                  <span className="text-white/40 text-xs">{heroItem.program.genre}</span>
                  <span className="text-white/15">•</span>
                  <span className="text-white/40 text-xs">{formatDuration(heroItem.program.duration)}</span>
                  {heroItem.program.seasonEpisode && (
                    <><span className="text-white/15">•</span><span className="text-indigo-300/60 text-xs">{heroItem.program.seasonEpisode}</span></>
                  )}
                </div>

                {/* Description */}
                <p className="text-white/40 text-sm mb-4 line-clamp-2 max-w-xl">{heroItem.program.description}</p>

                {/* Live progress */}
                {heroItem.status === 'live' && (
                  <div className="mb-4 max-w-md">
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-2 text-xs">
                        <Timer className="w-3 h-3 text-white/25" />
                        <span className="text-white/35">{formatTime(heroItem.program.startTime)}</span>
                        <span className="text-white/15">—</span>
                        <span className="text-white/35">{formatTime(heroItem.program.endTime)}</span>
                      </div>
                      <span className="text-white/50 text-xs">ещё {formatDuration(heroItem.remaining)}</span>
                    </div>
                    <div className="h-1.5 bg-white/10 rounded-full overflow-hidden">
                      <motion.div
                        className="h-full rounded-full bg-gradient-to-r from-[#6366f1] to-[#a78bfa]"
                        initial={{ width: 0 }}
                        animate={{ width: `${heroItem.progress * 100}%` }}
                        transition={{ duration: 0.8 }}
                      />
                    </div>
                  </div>
                )}

                {/* Time until start */}
                {heroItem.status !== 'live' && (
                  <div className="mb-4 flex items-center gap-2 px-3 py-2 bg-white/[0.05] rounded-xl border border-white/[0.06] w-fit">
                    <Clock className="w-3.5 h-3.5 text-amber-400/70" />
                    <span className="text-white/40 text-xs">Начало в {formatTime(heroItem.program.startTime)}</span>
                    <span className="text-white/15">•</span>
                    <span className="text-amber-400/70 text-xs">
                      через {formatDuration(Math.max(0, Math.floor((heroItem.program.startTime.getTime() - currentTime.getTime()) / 60000)))}
                    </span>
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center gap-2">
                  {heroItem.status === 'live' ? (
                    <button
                      onClick={() => handlePlayContent(heroItem)}
                      className="flex items-center gap-2 px-7 py-3 bg-white text-[#08080f] rounded-xl hover:scale-[1.03] transition-transform text-sm shadow-lg shadow-white/10"
                    >
                      <Play className="w-4 h-4" />
                      Смотреть
                    </button>
                  ) : (
                    <button
                      onClick={() => toggleReminder(heroItem.program.id)}
                      className={`flex items-center gap-2 px-7 py-3 rounded-xl transition-all text-sm ${
                        reminders.has(heroItem.program.id)
                          ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                          : 'bg-white text-[#08080f] hover:scale-[1.03] shadow-lg shadow-white/10'
                      }`}
                    >
                      {reminders.has(heroItem.program.id) ? (
                        <><BellOff className="w-4 h-4" />Напоминание</>
                      ) : (
                        <><Bell className="w-4 h-4" />Напомнить</>
                      )}
                    </button>
                  )}
                  {heroItem.status !== 'live' && (
                    <button
                      onClick={() => handlePlayContent(heroItem)}
                      className="flex items-center gap-2 px-5 py-3 bg-white/10 backdrop-blur-md text-white/70 rounded-xl hover:bg-white/15 transition-colors border border-white/[0.08] text-sm"
                    >
                      <Tv className="w-4 h-4" />
                      На канал
                    </button>
                  )}
                </div>
              </div>

              {/* Right: mini schedule + dots */}
              <div className="hidden xl:flex flex-col items-end gap-4 shrink-0 w-64">
                <div className="bg-black/40 backdrop-blur-xl rounded-2xl border border-white/[0.08] p-4 w-full">
                  <div className="flex items-center gap-2 mb-3">
                    <Calendar className="w-3.5 h-3.5 text-[#6366f1]" />
                    <span className="text-white/60 text-[11px]">Далее на канале</span>
                  </div>
                  {categories
                    .flatMap(c => c.items)
                    .filter(m => m.program.channelId === heroItem.program.channelId && m.program.id !== heroItem.program.id)
                    .slice(0, 3)
                    .map(m => (
                      <div
                        key={m.program.id}
                        onClick={() => {
                          const idx = featured.findIndex(f => f.program.id === m.program.id);
                          if (idx >= 0) setHeroIndex(idx);
                          else setSelectedContent(m);
                        }}
                        className="flex items-center gap-2 py-1.5 pl-3 border-l-2 border-white/10 cursor-pointer hover:border-indigo-400/50 transition-colors mb-1"
                      >
                        <div className="flex-1 min-w-0">
                          <div className="text-white/40 text-[11px] truncate">{m.program.title}</div>
                          <div className="text-white/20 text-[9px]">{formatTime(m.program.startTime)}</div>
                        </div>
                        {m.status === 'live' && (
                          <span className="text-[8px] text-red-400 bg-red-500/10 px-1.5 py-0.5 rounded">LIVE</span>
                        )}
                      </div>
                    ))}
                </div>

                {/* Dots */}
                <div className="flex items-center gap-1.5">
                  {featured.slice(0, 8).map((_, i) => (
                    <button
                      key={i}
                      onClick={() => setHeroIndex(i)}
                      className={`transition-all rounded-full ${
                        i === heroIndex ? 'w-6 h-1.5 bg-white' : 'w-1.5 h-1.5 bg-white/20 hover:bg-white/40'
                      }`}
                    />
                  ))}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* ===== MY SCHEDULE BAR ===== */}
      {mySchedule.length > 0 && (
        <div className="shrink-0 px-8 py-2 border-b border-white/[0.04]">
          <div className="flex items-center gap-4 overflow-x-auto scrollbar-hide">
            <div className="flex items-center gap-2 shrink-0">
              <Bell className="w-3.5 h-3.5 text-amber-400" />
              <span className="text-amber-400/70 text-[11px]">Мои перед��чи</span>
            </div>
            {mySchedule.map(item => (
              <button
                key={item.program.id}
                onClick={() => {
                  if (item.status === 'live') handlePlayContent(item);
                  else {
                    const idx = featured.findIndex(f => f.program.id === item.program.id);
                    if (idx >= 0) setHeroIndex(idx);
                  }
                }}
                className="shrink-0 flex items-center gap-2 px-3 py-1.5 bg-amber-500/[0.08] rounded-lg border border-amber-500/10 hover:bg-amber-500/15 transition-colors"
              >
                {item.status === 'live' && <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />}
                <span className="text-white/60 text-[11px] truncate max-w-[120px]">{item.program.title}</span>
                <span className="text-white/20 text-[10px]">
                  {item.status === 'live' ? 'сейчас' : formatTime(item.program.startTime)}
                </span>
                <button
                  onClick={(e) => { e.stopPropagation(); toggleReminder(item.program.id); }}
                  className="ml-1"
                >
                  <X className="w-3 h-3 text-white/20 hover:text-white/50" />
                </button>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* ===== CONTENT ROWS ===== */}
      <div className="flex-1 overflow-y-auto pb-8 scroll-smooth">
        {categories.map((cat, rowIdx) => (
          <ContentRow
            key={cat.id}
            category={cat}
            isFocusedRow={focusedRow === rowIdx}
            focusedCol={focusedRow === rowIdx ? focusedCol : -1}
            now={currentTime}
            reminders={reminders}
            onItemClick={handlePlayContent}
            onItemFocus={setSelectedContent}
            onToggleReminder={toggleReminder}
          />
        ))}
      </div>

      {/* ===== SETTINGS OVERLAY ===== */}
      <AnimatePresence>
        {showSettings && <TVSettings onClose={() => setShowSettings(false)} />}
      </AnimatePresence>

      {/* ===== REMINDER TOAST ===== */}
      <AnimatePresence>
        {showRemindToast && (
          <motion.div
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 50 }}
            className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50"
          >
            <div className="flex items-center gap-3 px-5 py-3 bg-[#1a1a2e]/95 backdrop-blur-xl rounded-2xl border border-amber-500/20 shadow-2xl">
              <Bell className="w-4 h-4 text-amber-400" />
              <span className="text-white/80 text-sm">Добавлено в «Мои передачи»</span>
              <span className="text-white/30 text-xs">Напомним перед началом</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}


// ===== CONTENT ROW =====

interface ContentRowProps {
  category: CinemaCategory;
  isFocusedRow: boolean;
  focusedCol: number;
  now: Date;
  reminders: Set<string>;
  onItemClick: (item: ContentOnAir) => void;
  onItemFocus: (item: ContentOnAir) => void;
  onToggleReminder: (id: string) => void;
}

function ContentRow({
  category, isFocusedRow, focusedCol, now, reminders,
  onItemClick, onItemFocus, onToggleReminder,
}: ContentRowProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  const scroll = (dir: 'left' | 'right') => {
    scrollRef.current?.scrollBy({ left: dir === 'left' ? -450 : 450, behavior: 'smooth' });
  };

  useEffect(() => {
    if (!isFocusedRow || focusedCol < 0 || !scrollRef.current) return;
    const cards = scrollRef.current.children;
    const card = cards[Math.min(focusedCol, cards.length - 1)] as HTMLElement;
    if (card) card.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  }, [isFocusedRow, focusedCol]);

  if (category.items.length === 0) return null;

  return (
    <div className={`mb-1 transition-colors ${isFocusedRow ? 'bg-white/[0.015]' : ''}`}>
      <div className="px-8 py-2.5 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className={`text-xs ${isFocusedRow ? 'text-white/80' : 'text-white/50'} transition-colors`}>
            {category.name}
          </span>
          <span className="text-[10px] text-white/15">{category.items.length}</span>
        </div>
        <div className="flex items-center gap-1">
          <button onClick={() => scroll('left')} className="w-7 h-7 rounded-lg bg-white/[0.04] flex items-center justify-center hover:bg-white/[0.08] border border-white/[0.04] transition-colors">
            <ChevronLeft className="w-3.5 h-3.5 text-white/25" />
          </button>
          <button onClick={() => scroll('right')} className="w-7 h-7 rounded-lg bg-white/[0.04] flex items-center justify-center hover:bg-white/[0.08] border border-white/[0.04] transition-colors">
            <ChevronRight className="w-3.5 h-3.5 text-white/25" />
          </button>
        </div>
      </div>

      <div ref={scrollRef} className="flex gap-4 px-8 pb-4 overflow-x-auto scrollbar-hide scroll-smooth">
        {category.items.map((item, colIdx) => {
          const isFocused = isFocusedRow && colIdx === Math.min(focusedCol, category.items.length - 1);
          return (
            <ContentCard
              key={item.program.id}
              item={item}
              isFocused={isFocused}
              now={now}
              hasReminder={reminders.has(item.program.id)}
              onClick={() => item.status === 'live' ? onItemClick(item) : onToggleReminder(item.program.id)}
              onFocus={() => onItemFocus(item)}
            />
          );
        })}
      </div>
    </div>
  );
}


// ===== CONTENT CARD =====

interface ContentCardProps {
  item: ContentOnAir;
  isFocused: boolean;
  now: Date;
  hasReminder: boolean;
  onClick: () => void;
  onFocus: () => void;
}

function ContentCard({ item, isFocused, now, hasReminder, onClick, onFocus }: ContentCardProps) {
  const { program, status, progress, remaining, elapsed } = item;
  const isWide = program.contentType === 'sport' || program.contentType === 'news' || program.contentType === 'show' || program.contentType === 'music';

  return (
    <motion.div
      onClick={onClick}
      onMouseEnter={onFocus}
      whileHover={{ scale: 1.04 }}
      whileTap={{ scale: 0.98 }}
      className={`shrink-0 rounded-2xl overflow-hidden cursor-pointer transition-all duration-200 group ${
        isWide ? 'w-72' : 'w-48'
      } ${
        isFocused ? 'ring-2 ring-[#6366f1] shadow-xl shadow-indigo-500/20 scale-105' : ''
      }`}
    >
      <div className={`relative ${isWide ? 'aspect-video' : 'aspect-[2/3]'} bg-[#12121e]`}>
        <img src={program.poster} alt="" className="w-full h-full object-cover" loading="lazy" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#08080f] via-transparent to-transparent opacity-90" />

        {/* Status */}
        <div className="absolute top-2 left-2 flex items-center gap-1.5">
          {status === 'live' && (
            <span className="flex items-center gap-1 px-2 py-0.5 bg-red-500/90 rounded-lg text-white text-[10px] shadow-md shadow-red-500/20">
              <span className="w-1 h-1 rounded-full bg-white animate-pulse" />
              LIVE
            </span>
          )}
          {status === 'starting_soon' && (
            <span className="px-2 py-0.5 bg-amber-500/90 rounded-lg text-white text-[10px]">СКОРО</span>
          )}
          {status === 'upcoming' && (
            <span className="px-2 py-0.5 bg-white/20 backdrop-blur-sm rounded-lg text-white/80 text-[10px]">
              {formatTime(program.startTime)}
            </span>
          )}
        </div>

        {/* Rating */}
        {program.rating && (
          <div
            className="absolute top-2 right-2 flex items-center gap-0.5 px-1.5 py-0.5 rounded-lg text-[10px] backdrop-blur-sm"
            style={{
              backgroundColor: getRatingColor(program.rating) + '20',
              color: getRatingColor(program.rating),
            }}
          >
            <Star className="w-2.5 h-2.5" />
            {program.rating.toFixed(1)}
          </div>
        )}

        {/* Reminder */}
        {hasReminder && (
          <div className="absolute top-8 right-2">
            <Bell className="w-3.5 h-3.5 text-amber-400 fill-amber-400/30 drop-shadow-lg" />
          </div>
        )}

        {/* Content type */}
        <div className="absolute bottom-[52px] right-2">
          <span className="text-[10px] px-1.5 py-0.5 bg-black/40 backdrop-blur-sm rounded text-white/40">
            {getContentTypeIcon(program.contentType)}
          </span>
        </div>

        {/* Age rating */}
        {program.ageRating && (
          <div
            className="absolute bottom-[52px] left-2 px-1.5 py-0.5 rounded text-[8px] border backdrop-blur-sm"
            style={{
              color: getAgeColor(program.ageRating),
              borderColor: getAgeColor(program.ageRating) + '30',
              backgroundColor: '#08080fcc',
            }}
          >
            {program.ageRating}
          </div>
        )}

        {/* Progress (live) */}
        {status === 'live' && (
          <div className="absolute bottom-[40px] left-2.5 right-2.5">
            <div className="h-1 bg-white/10 rounded-full overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#6366f1] to-[#a78bfa]"
                style={{ width: `${progress * 100}%` }}
              />
            </div>
            <div className="flex justify-between mt-0.5">
              <span className="text-white/25 text-[7px]">{formatDuration(elapsed)}</span>
              <span className="text-white/40 text-[7px]">−{formatDuration(remaining)}</span>
            </div>
          </div>
        )}

        {/* Info */}
        <div className="absolute bottom-0 left-0 right-0 p-2.5">
          <div className="text-white text-xs truncate drop-shadow-lg">{program.title}</div>
          <div className="flex items-center gap-1 mt-0.5">
            {program.seasonEpisode && <span className="text-indigo-300/50 text-[9px]">{program.seasonEpisode}</span>}
            {program.year && <span className="text-white/30 text-[9px]">{program.year}</span>}
            <span className="text-white/10">•</span>
            <span className="text-white/30 text-[9px]">{program.genre}</span>
          </div>
          <div className="text-white/15 text-[9px] truncate mt-0.5">
            {program.channelLogo} {program.channelName}
          </div>
        </div>

        {/* Hover */}
        <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-black/20">
          <div className="w-12 h-12 rounded-full bg-white/90 flex items-center justify-center shadow-2xl">
            {status === 'live' ? (
              <Play className="w-5 h-5 text-[#08080f] ml-0.5" />
            ) : (
              <Bell className="w-5 h-5 text-[#08080f]" />
            )}
          </div>
        </div>
      </div>
    </motion.div>
  );
}
