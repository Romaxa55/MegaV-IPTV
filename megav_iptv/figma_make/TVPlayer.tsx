import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useApp } from '../../context/AppContext';
import { motion, AnimatePresence } from 'motion/react';
import {
  ArrowLeft, Play, Pause, Volume2, VolumeX, SkipForward, SkipBack,
  Star, Clock, Info, List, Tv, ChevronUp, ChevronDown,
  Sparkles, Film, Calendar, X, Zap
} from 'lucide-react';

interface TVPlayerProps {
  onBack: () => void;
}

// Mock EPG data for design
const MOCK_EPG = [
  { time: '18:00', title: 'Новости', duration: 30, progress: 100 },
  { time: '18:30', title: 'Погода', duration: 15, progress: 100 },
  { time: '18:45', title: 'Документальный фильм', duration: 60, progress: 65 },
  { time: '19:45', title: 'Ток-шоу "Вечер"', duration: 90, progress: 0 },
  { time: '21:15', title: 'Премьера: Драма', duration: 120, progress: 0 },
  { time: '23:15', title: 'Ночные новости', duration: 30, progress: 0 },
  { time: '23:45', title: 'Кино ночью', duration: 120, progress: 0 },
];

type Overlay = 'none' | 'epg' | 'channels' | 'info' | 'similar';

export function TVPlayer({ onBack }: TVPlayerProps) {
  const {
    currentChannel, channels, playChannel, volume, setVolume,
    isMuted, toggleMute, isPlaying, togglePlay, favorites, toggleFavorite,
    channelUp, channelDown, categoryGroups,
  } = useApp();

  const [showControls, setShowControls] = useState(true);
  const [overlay, setOverlay] = useState<Overlay>('none');
  const [showChannelOSD, setShowChannelOSD] = useState(false);
  const [channelSwitchPreview, setChannelSwitchPreview] = useState<typeof currentChannel>(null);
  const hideTimer = useRef<ReturnType<typeof setTimeout>>();
  const osdTimer = useRef<ReturnType<typeof setTimeout>>();
  const switchTimer = useRef<ReturnType<typeof setTimeout>>();

  const resetHideTimer = useCallback(() => {
    setShowControls(true);
    clearTimeout(hideTimer.current);
    hideTimer.current = setTimeout(() => {
      if (overlay === 'none') {
        setShowControls(false);
      }
    }, 4000);
  }, [overlay]);

  const showBriefOSD = useCallback(() => {
    setShowChannelOSD(true);
    clearTimeout(osdTimer.current);
    osdTimer.current = setTimeout(() => setShowChannelOSD(false), 3000);
  }, []);

  useEffect(() => { showBriefOSD(); }, [currentChannel, showBriefOSD]);

  useEffect(() => {
    resetHideTimer();
    return () => {
      clearTimeout(hideTimer.current);
      clearTimeout(osdTimer.current);
      clearTimeout(switchTimer.current);
    };
  }, [resetHideTimer]);

  // Get similar channels (same category)
  const similarChannels = currentChannel
    ? channels.filter(c => c.id !== currentChannel.id && c.category === currentChannel.category)
    : [];

  // Get current group channels for quick switching
  const currentGroup = currentChannel
    ? categoryGroups.find(g => g.channels.some(c => c.id === currentChannel.id))
    : null;

  // Channel quick-switch with preview
  const quickSwitch = useCallback((direction: 'up' | 'down') => {
    if (!currentChannel) return;
    const idx = channels.findIndex(c => c.id === currentChannel.id);
    const nextIdx = direction === 'up'
      ? (idx > 0 ? idx - 1 : channels.length - 1)
      : (idx < channels.length - 1 ? idx + 1 : 0);
    const next = channels[nextIdx];
    setChannelSwitchPreview(next);

    clearTimeout(switchTimer.current);
    switchTimer.current = setTimeout(() => {
      playChannel(next);
      setChannelSwitchPreview(null);
    }, 1500);
  }, [currentChannel, channels, playChannel]);

  const toggleOverlay = useCallback((target: Overlay) => {
    setOverlay(prev => prev === target ? 'none' : target);
    resetHideTimer();
  }, [resetHideTimer]);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      resetHideTimer();
      switch (e.key) {
        case 'Escape':
        case 'Backspace':
          e.preventDefault();
          if (overlay !== 'none') setOverlay('none');
          else onBack();
          break;
        case ' ':
          e.preventDefault();
          togglePlay();
          break;
        case 'ArrowUp':
          e.preventDefault();
          if (overlay === 'none') quickSwitch('up');
          break;
        case 'ArrowDown':
          e.preventDefault();
          if (overlay === 'none') quickSwitch('down');
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (overlay === 'none') setVolume(Math.min(100, volume + 5));
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (overlay === 'none') setVolume(Math.max(0, volume - 5));
          break;
        case 'm': e.preventDefault(); toggleMute(); break;
        case 'e': e.preventDefault(); toggleOverlay('epg'); break;
        case 'i': e.preventDefault(); toggleOverlay('info'); break;
        case 'l': e.preventDefault(); toggleOverlay('channels'); break;
        case 'r': e.preventDefault(); toggleOverlay('similar'); break;
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [onBack, togglePlay, quickSwitch, volume, setVolume, toggleMute, resetHideTimer, overlay, toggleOverlay]);

  if (!currentChannel) return null;
  const isFavorite = favorites.includes(currentChannel.id);

  return (
    <div className="fixed inset-0 bg-black z-50" onMouseMove={resetHideTimer} onClick={() => { if (overlay === 'none') resetHideTimer(); }}>
      {/* ===== VIDEO BACKGROUND ===== */}
      <AnimatePresence mode="wait">
        <motion.img
          key={currentChannel.id}
          src={currentChannel.thumbnail}
          alt=""
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.5 }}
          className="w-full h-full object-cover"
        />
      </AnimatePresence>

      {/* ===== CHANNEL SWITCH PREVIEW (OSD on Up/Down) ===== */}
      <AnimatePresence>
        {channelSwitchPreview && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="absolute top-0 left-0 right-0 z-30"
          >
            <div className="bg-gradient-to-b from-black/80 via-black/50 to-transparent pt-6 pb-16 px-8">
              <div className="flex items-center gap-4">
                <div className="w-24 h-16 rounded-xl overflow-hidden bg-white/10 shrink-0">
                  {channelSwitchPreview.thumbnail ? (
                    <img src={channelSwitchPreview.thumbnail} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-2xl">{channelSwitchPreview.logo}</div>
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-white/40 text-xs font-mono">CH {channelSwitchPreview.number}</span>
                    <span className="text-white text-lg">{channelSwitchPreview.name}</span>
                    <span className="text-white/20">{channelSwitchPreview.country}</span>
                  </div>
                  <div className="flex items-center gap-3 text-xs">
                    <span className="text-indigo-300">{channelSwitchPreview.currentProgram}</span>
                    <span className="text-white/20">Далее: {channelSwitchPreview.nextProgram}</span>
                  </div>
                </div>
                <div className="ml-auto flex items-center gap-1 text-white/20 text-xs">
                  <div className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-pulse" />
                  переключение...
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ===== BRIEF OSD (auto hide after 3s) ===== */}
      <AnimatePresence>
        {showChannelOSD && !showControls && overlay === 'none' && !channelSwitchPreview && (
          <motion.div initial={{ opacity: 0, x: -30 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -30 }} className="absolute top-6 left-6 z-20">
            <div className="flex items-center gap-3 bg-black/60 backdrop-blur-xl rounded-2xl px-5 py-3 border border-white/10">
              <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center text-lg">{currentChannel.logo}</div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-white/40 text-xs font-mono">CH {currentChannel.number}</span>
                  <span className="text-white text-sm">{currentChannel.name}</span>
                </div>
                <p className="text-white/30 text-xs">{currentChannel.currentProgram}</p>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ===== CONTROLS OVERLAY ===== */}
      <AnimatePresence>
        {showControls && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.2 }} className="absolute inset-0 z-10">
            {/* Top gradient */}
            <div className="absolute top-0 left-0 right-0 h-28 bg-gradient-to-b from-black/60 to-transparent" />
            {/* Bottom gradient */}
            <div className="absolute bottom-0 left-0 right-0 h-36 bg-gradient-to-t from-black/70 to-transparent" />

            {/* Top bar */}
            <div className="absolute top-0 left-0 right-0 p-5 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <button onClick={onBack} className="w-10 h-10 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10">
                  <ArrowLeft className="w-5 h-5 text-white" />
                </button>
                <div className="flex items-center gap-2.5">
                  <span className="text-lg">{currentChannel.logo}</span>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-white">{currentChannel.name}</span>
                      <span className="px-1.5 py-0.5 bg-white/10 rounded text-white/30 text-[10px] font-mono">CH {currentChannel.number}</span>
                    </div>
                    <span className="text-white/40 text-xs">{currentChannel.currentProgram}</span>
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-1.5">
                <button onClick={() => toggleFavorite(currentChannel.id)} className={`w-10 h-10 rounded-xl backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 ${isFavorite ? 'bg-yellow-500/20' : 'bg-white/10'}`}>
                  <Star className={`w-4 h-4 ${isFavorite ? 'text-yellow-400 fill-yellow-400' : 'text-white/50'}`} />
                </button>
                <button onClick={() => toggleOverlay('info')} className={`w-10 h-10 rounded-xl backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 ${overlay === 'info' ? 'bg-indigo-500/30' : 'bg-white/10'}`}>
                  <Info className="w-4 h-4 text-white/50" />
                </button>
                <button onClick={() => toggleOverlay('epg')} className={`w-10 h-10 rounded-xl backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 ${overlay === 'epg' ? 'bg-indigo-500/30' : 'bg-white/10'}`}>
                  <Calendar className="w-4 h-4 text-white/50" />
                </button>
                <button onClick={() => toggleOverlay('channels')} className={`w-10 h-10 rounded-xl backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 ${overlay === 'channels' ? 'bg-indigo-500/30' : 'bg-white/10'}`}>
                  <List className="w-4 h-4 text-white/50" />
                </button>
                <button onClick={() => toggleOverlay('similar')} className={`w-10 h-10 rounded-xl backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 ${overlay === 'similar' ? 'bg-indigo-500/30' : 'bg-white/10'}`}>
                  <Sparkles className="w-4 h-4 text-white/50" />
                </button>
              </div>
            </div>

            {/* Bottom controls */}
            <div className="absolute bottom-0 left-0 right-0 p-5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <button onClick={channelDown} className="w-11 h-11 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10">
                    <SkipBack className="w-4 h-4 text-white" />
                  </button>
                  <button onClick={togglePlay} className="w-14 h-14 rounded-2xl bg-white flex items-center justify-center hover:scale-105 transition-transform">
                    {isPlaying ? <Pause className="w-5 h-5 text-[#0f0f1a]" /> : <Play className="w-5 h-5 text-[#0f0f1a] ml-0.5" />}
                  </button>
                  <button onClick={channelUp} className="w-11 h-11 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10">
                    <SkipForward className="w-4 h-4 text-white" />
                  </button>
                </div>

                <div className="flex items-center gap-2">
                  {/* Volume */}
                  <div className="flex items-center gap-2 bg-white/10 backdrop-blur-md rounded-xl px-3 py-2 border border-white/10">
                    <button onClick={toggleMute}>
                      {isMuted || volume === 0 ? <VolumeX className="w-4 h-4 text-white/40" /> : <Volume2 className="w-4 h-4 text-white/50" />}
                    </button>
                    <div className="w-20 h-1 bg-white/10 rounded-full overflow-hidden">
                      <div className="h-full bg-white/60 rounded-full transition-all" style={{ width: `${isMuted ? 0 : volume}%` }} />
                    </div>
                    <span className="text-white/30 text-[10px] w-5 text-right">{isMuted ? 0 : volume}</span>
                  </div>
                  {/* CH +/- */}
                  <div className="flex flex-col gap-px">
                    <button onClick={channelUp} className="w-9 h-5 rounded-t-lg bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 border-b-0">
                      <ChevronUp className="w-3 h-3 text-white/40" />
                    </button>
                    <button onClick={channelDown} className="w-9 h-5 rounded-b-lg bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition border border-white/10 border-t-0">
                      <ChevronDown className="w-3 h-3 text-white/40" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ===== EPG OVERLAY ===== */}
      <AnimatePresence>
        {overlay === 'epg' && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className="absolute bottom-0 left-0 right-0 z-20 bg-black/80 backdrop-blur-2xl border-t border-white/10 rounded-t-3xl"
            style={{ maxHeight: '55vh' }}
          >
            <div className="p-5">
              {/* Handle bar */}
              <div className="w-10 h-1 rounded-full bg-white/20 mx-auto mb-4" />

              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Calendar className="w-4 h-4 text-[#6366f1]" />
                  <h3 className="text-white text-sm">Программа передач</h3>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-white/30 text-xs">{currentChannel.name}</span>
                  <button onClick={() => setOverlay('none')} className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center">
                    <X className="w-3.5 h-3.5 text-white/40" />
                  </button>
                </div>
              </div>

              {/* Timeline */}
              <div className="space-y-0.5 max-h-64 overflow-y-auto pr-1" style={{ scrollbarWidth: 'thin' }}>
                {MOCK_EPG.map((prog, i) => (
                  <div key={i} className={`flex items-center gap-3 p-3 rounded-xl transition ${prog.progress > 0 && prog.progress < 100 ? 'bg-indigo-500/10 border border-indigo-500/20' : 'hover:bg-white/5'}`}>
                    <span className={`text-xs font-mono w-11 shrink-0 ${prog.progress > 0 && prog.progress < 100 ? 'text-indigo-300' : 'text-white/30'}`}>
                      {prog.time}
                    </span>
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm truncate ${prog.progress > 0 && prog.progress < 100 ? 'text-white' : prog.progress === 100 ? 'text-white/30' : 'text-white/60'}`}>
                        {prog.title}
                      </p>
                      {prog.progress > 0 && prog.progress < 100 && (
                        <div className="mt-1.5 h-1 bg-white/10 rounded-full overflow-hidden">
                          <div className="h-full bg-[#6366f1] rounded-full" style={{ width: `${prog.progress}%` }} />
                        </div>
                      )}
                    </div>
                    <span className="text-white/15 text-[10px] shrink-0">{prog.duration} мин</span>
                    {prog.progress > 0 && prog.progress < 100 && (
                      <span className="px-2 py-0.5 bg-red-500/80 rounded text-white text-[9px] shrink-0">LIVE</span>
                    )}
                  </div>
                ))}
              </div>

              {/* Hint */}
              <div className="mt-3 pt-3 border-t border-white/5 flex items-center justify-center gap-3 text-white/15 text-[10px]">
                <span>Будет доступна подписка на EPG сервис</span>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ===== CHANNELS SIDEBAR ===== */}
      <AnimatePresence>
        {overlay === 'channels' && (
          <motion.div
            initial={{ x: 340 }}
            animate={{ x: 0 }}
            exit={{ x: 340 }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className="absolute right-0 top-0 bottom-0 w-80 bg-black/80 backdrop-blur-2xl border-l border-white/10 z-20"
          >
            <div className="p-4 h-full flex flex-col">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <List className="w-4 h-4 text-[#6366f1]" />
                  <h3 className="text-white/80 text-sm">Каналы</h3>
                </div>
                <button onClick={() => setOverlay('none')} className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center">
                  <X className="w-3.5 h-3.5 text-white/40" />
                </button>
              </div>

              {/* Category filter chips */}
              <div className="flex gap-1.5 mb-3 overflow-x-auto pb-1 scrollbar-hide">
                {['Все', ...[...new Set(channels.map(c => c.category))]].map(cat => (
                  <button key={cat} className={`px-2.5 py-1 rounded-lg text-[10px] whitespace-nowrap shrink-0 ${cat === 'Все' ? 'bg-[#6366f1] text-white' : 'bg-white/5 text-white/30 hover:text-white/50'}`}>
                    {cat}
                  </button>
                ))}
              </div>

              <div className="flex-1 overflow-y-auto space-y-0.5" style={{ scrollbarWidth: 'thin' }}>
                {channels.map(ch => (
                  <button
                    key={ch.id}
                    onClick={() => { playChannel(ch); setOverlay('none'); }}
                    className={`w-full flex items-center gap-2.5 p-2 rounded-xl transition-all ${
                      ch.id === currentChannel.id ? 'bg-indigo-500/20 border border-indigo-500/30' : 'hover:bg-white/5'
                    }`}
                  >
                    <div className="w-11 h-7 rounded-lg overflow-hidden bg-white/10 shrink-0">
                      {ch.thumbnail ? (
                        <img src={ch.thumbnail} alt="" className="w-full h-full object-cover" loading="lazy" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-xs">{ch.logo}</div>
                      )}
                    </div>
                    <div className="text-left flex-1 min-w-0">
                      <p className="text-white text-xs truncate">{ch.name}</p>
                      <p className="text-white/20 text-[10px] truncate">{ch.currentProgram}</p>
                    </div>
                    <span className="text-white/10 text-[10px] font-mono shrink-0">{ch.number}</span>
                  </button>
                ))}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ===== INFO PANEL ===== */}
      <AnimatePresence>
        {overlay === 'info' && (
          <motion.div
            initial={{ y: 80, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 80, opacity: 0 }}
            className="absolute bottom-20 left-5 right-5 z-20"
          >
            <div className="bg-black/70 backdrop-blur-2xl rounded-2xl border border-white/10 p-5">
              <div className="flex items-start gap-4">
                <div className="w-16 h-16 rounded-xl bg-white/10 flex items-center justify-center text-3xl shrink-0">{currentChannel.logo}</div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="text-white text-xl">{currentChannel.name}</h3>
                    <span className="text-white/20 text-xs font-mono">CH {currentChannel.number}</span>
                  </div>
                  <p className="text-white/40 text-sm mb-3">{currentChannel.description || 'Нет описания'}</p>
                  <div className="flex items-center gap-2 flex-wrap mb-3">
                    <span className="px-2 py-0.5 bg-white/10 rounded text-white/50 text-xs">{currentChannel.country}</span>
                    <span className="px-2 py-0.5 bg-indigo-500/20 rounded text-indigo-300 text-xs">{currentChannel.category}</span>
                    <span className="px-2 py-0.5 bg-white/5 rounded text-white/25 text-xs">{currentChannel.group}</span>
                  </div>
                  <div className="flex items-center gap-5 text-xs">
                    <div className="flex items-center gap-1.5 text-indigo-300">
                      <Clock className="w-3 h-3" />
                      <span>Сейчас: {currentChannel.currentProgram}</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-white/20">
                      <Clock className="w-3 h-3" />
                      <span>Далее: {currentChannel.nextProgram}</span>
                    </div>
                  </div>
                </div>
                <button onClick={() => setOverlay('none')} className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center shrink-0">
                  <X className="w-3.5 h-3.5 text-white/40" />
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ===== SIMILAR / RECOMMENDATIONS OVERLAY ===== */}
      <AnimatePresence>
        {overlay === 'similar' && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 300 }}
            className="absolute bottom-0 left-0 right-0 z-20 bg-black/80 backdrop-blur-2xl border-t border-white/10 rounded-t-3xl"
            style={{ maxHeight: '50vh' }}
          >
            <div className="p-5">
              <div className="w-10 h-1 rounded-full bg-white/20 mx-auto mb-4" />

              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-amber-400" />
                  <h3 className="text-white text-sm">Похожее по жанру</h3>
                  <span className="px-2 py-0.5 bg-indigo-500/20 rounded text-indigo-300 text-xs">{currentChannel.category}</span>
                </div>
                <button onClick={() => setOverlay('none')} className="w-7 h-7 rounded-lg bg-white/10 flex items-center justify-center">
                  <X className="w-3.5 h-3.5 text-white/40" />
                </button>
              </div>

              {/* Recommendation hint */}
              <div className="bg-gradient-to-r from-amber-500/10 to-indigo-500/10 rounded-xl p-3 mb-4 border border-amber-500/10">
                <div className="flex items-center gap-2">
                  <Zap className="w-4 h-4 text-amber-400 shrink-0" />
                  <p className="text-white/40 text-xs">
                    Сейчас: <span className="text-white/70">{currentChannel.currentProgram}</span> на {currentChannel.name}.
                    {similarChannels.length > 0 ? ` Вот ещё ${similarChannels.length} каналов в категории "${currentChannel.category}":` : ' Похожих каналов не найдено.'}
                  </p>
                </div>
                <p className="text-amber-400/30 text-[10px] mt-1 ml-6">AI-рекомендации скоро — подключим бекенд</p>
              </div>

              {/* Similar channels grid */}
              {similarChannels.length > 0 ? (
                <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide">
                  {similarChannels.map(ch => (
                    <button
                      key={ch.id}
                      onClick={() => { playChannel(ch); setOverlay('none'); }}
                      className="shrink-0 w-40 group"
                    >
                      <div className="relative aspect-video rounded-xl overflow-hidden bg-white/10 mb-2">
                        {ch.thumbnail ? (
                          <img src={ch.thumbnail} alt="" className="w-full h-full object-cover group-hover:scale-105 transition-transform" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-2xl">{ch.logo}</div>
                        )}
                        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition flex items-center justify-center">
                          <div className="w-8 h-8 rounded-full bg-white/80 flex items-center justify-center opacity-0 group-hover:opacity-100 transition">
                            <Play className="w-3.5 h-3.5 text-black ml-0.5" />
                          </div>
                        </div>
                        <div className="absolute bottom-1 left-1 px-1.5 py-0.5 bg-black/50 backdrop-blur rounded text-white text-[9px]">CH {ch.number}</div>
                      </div>
                      <p className="text-white text-xs truncate">{ch.name}</p>
                      <p className="text-white/25 text-[10px] truncate">{ch.currentProgram}</p>
                    </button>
                  ))}
                </div>
              ) : (
                <div className="text-center py-6">
                  <Film className="w-8 h-8 text-white/10 mx-auto mb-2" />
                  <p className="text-white/20 text-sm">Нет похожих каналов</p>
                  <p className="text-white/10 text-xs">Добавьте больше каналов для рекомендаций</p>
                </div>
              )}

              {/* Future: other category suggestions */}
              <div className="mt-3 pt-3 border-t border-white/5">
                <p className="text-white/10 text-[10px] text-center">
                  Скоро: «Если вам понравился Терминатор — вот фантастика на других каналах» (AI + EPG)
                </p>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
