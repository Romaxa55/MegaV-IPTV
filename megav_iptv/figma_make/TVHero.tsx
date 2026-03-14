import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  Tv, Settings, QrCode, Star, Clock, Search,
  Wifi, Play, MapPin, Droplets, Wind,
  ChevronDown, Thermometer
} from 'lucide-react';
import { detectGeoLocation, AVAILABLE_COUNTRIES, type GeoData } from './GeoService';
import type { Channel } from '../../store';

interface TVHeroProps {
  previewChannel: Channel | null;
  isPaired: boolean;
  favorites: string[];
  currentTime: Date;
  onSearch: () => void;
  onPairing: () => void;
  onSettings: () => void;
  onPlay: (ch: Channel) => void;
  onToggleFavorite: (id: string) => void;
}

export function TVHero({
  previewChannel, isPaired, favorites, currentTime,
  onSearch, onPairing, onSettings, onPlay, onToggleFavorite,
}: TVHeroProps) {
  const [geoData, setGeoData] = useState<GeoData>(() => detectGeoLocation('UG'));
  const [showCountryPicker, setShowCountryPicker] = useState(false);
  const [geoWallpaperIdx, setGeoWallpaperIdx] = useState(0);

  // Rotate geo wallpapers every 30s
  useEffect(() => {
    if (geoData.wallpapers.length <= 1) return;
    const timer = setInterval(() => {
      setGeoWallpaperIdx(p => (p + 1) % geoData.wallpapers.length);
    }, 30000);
    return () => clearInterval(timer);
  }, [geoData.wallpapers.length]);

  const switchCountry = (code: string) => {
    setGeoData(detectGeoLocation(code));
    setGeoWallpaperIdx(0);
    setShowCountryPicker(false);
  };

  const formatTime = (d: Date) => d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
  const currentWallpaper = geoData.wallpapers[geoWallpaperIdx];

  return (
    <div className="relative h-[42vh] min-h-[280px] shrink-0 overflow-hidden">
      {/* Layer 1: Geo wallpaper (base — always visible) */}
      <AnimatePresence mode="wait">
        <motion.img
          key={`geo-${geoData.location.countryCode}-${geoWallpaperIdx}`}
          src={currentWallpaper?.url}
          alt=""
          initial={{ opacity: 0, scale: 1.08 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 1.5 }}
          className="absolute inset-0 w-full h-full object-cover"
        />
      </AnimatePresence>

      {/* Layer 2: Channel preview (on top when navigating) */}
      <AnimatePresence mode="wait">
        {previewChannel?.thumbnail && (
          <motion.img
            key={`ch-${previewChannel.id}`}
            src={previewChannel.thumbnail}
            alt=""
            initial={{ opacity: 0, scale: 1.05 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.5 }}
            className="absolute inset-0 w-full h-full object-cover"
          />
        )}
      </AnimatePresence>

      {/* Gradients */}
      <div className="absolute inset-0 bg-gradient-to-r from-[#0f0f1a]/90 via-[#0f0f1a]/50 to-transparent" />
      <div className="absolute inset-0 bg-gradient-to-t from-[#f5f6f8] via-transparent to-[#0f0f1a]/30" />

      {/* ===== TOP BAR ===== */}
      <div className="absolute top-0 left-0 right-0 px-8 py-4 flex items-center justify-between z-10">
        {/* Left: Logo + Geo/Weather */}
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center border border-white/10">
            <Tv className="w-4 h-4 text-white" />
          </div>
          <span className="text-white/90 text-sm tracking-wide">StreamFlow</span>

          {/* Geo location picker */}
          <div className="relative ml-2">
            <button
              onClick={() => setShowCountryPicker(p => !p)}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-white/10 backdrop-blur-md rounded-xl border border-white/10 hover:bg-white/15 transition-colors"
            >
              <span className="text-sm">{geoData.location.flag}</span>
              <span className="text-white/70 text-xs">{geoData.location.city}</span>
              <ChevronDown className="w-3 h-3 text-white/30" />
            </button>

            {/* Country dropdown */}
            <AnimatePresence>
              {showCountryPicker && (
                <motion.div
                  initial={{ opacity: 0, y: -5 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -5 }}
                  className="absolute top-full mt-1 left-0 bg-[#1a1a2e]/95 backdrop-blur-xl rounded-xl border border-white/10 overflow-hidden z-50 w-52 shadow-2xl"
                >
                  <div className="p-1.5">
                    <div className="text-white/20 text-[9px] px-2 py-1 mb-0.5">GEO-IP ДЕМО: СМЕНИТЬ ЛОКАЦИЮ</div>
                    {AVAILABLE_COUNTRIES.map(c => (
                      <button
                        key={c.code}
                        onClick={() => switchCountry(c.code)}
                        className={`w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-xs transition-colors ${
                          c.code === geoData.location.countryCode
                            ? 'bg-[#6366f1]/20 text-white'
                            : 'text-white/50 hover:bg-white/5 hover:text-white/70'
                        }`}
                      >
                        <span className="text-sm">{c.flag}</span>
                        <span>{c.city}, {c.name}</span>
                      </button>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          {/* Weather chip */}
          <div className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white/10 backdrop-blur-md rounded-xl border border-white/10">
            <span className="text-sm">{geoData.weather.icon}</span>
            <span className="text-white/80 text-xs">{geoData.weather.temp}°</span>
          </div>

          {/* Extended weather info */}
          <div className="hidden lg:flex items-center gap-3 px-3 py-1.5 bg-white/[0.06] backdrop-blur-md rounded-xl border border-white/[0.06]">
            <div className="flex items-center gap-1 text-white/30 text-[10px]">
              <Thermometer className="w-3 h-3" />
              <span>Ощущ. {geoData.weather.feelsLike}°</span>
            </div>
            <div className="flex items-center gap-1 text-white/30 text-[10px]">
              <Droplets className="w-3 h-3" />
              <span>{geoData.weather.humidity}%</span>
            </div>
            <div className="flex items-center gap-1 text-white/30 text-[10px]">
              <Wind className="w-3 h-3" />
              <span>{geoData.weather.windSpeed} км/ч</span>
            </div>
          </div>
        </div>

        {/* Right: Status + Actions */}
        <div className="flex items-center gap-2">
          {isPaired && (
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-500/20 backdrop-blur-md rounded-full border border-emerald-400/20">
              <Wifi className="w-3 h-3 text-emerald-400" />
              <span className="text-emerald-300 text-xs">Пульт</span>
            </div>
          )}
          <span className="text-white/60 text-sm mr-1">{formatTime(currentTime)}</span>
          <button onClick={onSearch} className="w-9 h-9 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition-colors border border-white/10">
            <Search className="w-4 h-4 text-white/70" />
          </button>
          <button onClick={onPairing} className="w-9 h-9 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition-colors border border-white/10">
            <QrCode className="w-4 h-4 text-white/70" />
          </button>
          <button onClick={onSettings} className="w-9 h-9 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition-colors border border-white/10">
            <Settings className="w-4 h-4 text-white/70" />
          </button>
        </div>
      </div>

      {/* ===== GEO GREETING (right side, under top bar) ===== */}
      <div className="absolute top-16 right-8 z-10">
        <div className="bg-black/20 backdrop-blur-md rounded-xl px-4 py-2.5 border border-white/[0.06]">
          <p className="text-white/70 text-sm">{geoData.greeting}</p>
          <div className="flex items-center gap-1.5 mt-0.5">
            <MapPin className="w-3 h-3 text-white/20" />
            <span className="text-white/25 text-[10px]">{geoData.weather.description} · {geoData.localChannelsHint}</span>
          </div>
        </div>
      </div>

      {/* Wallpaper location credit */}
      {currentWallpaper && (
        <div className="absolute bottom-2 right-8 z-10">
          <span className="text-white/10 text-[9px]">{currentWallpaper.location}</span>
        </div>
      )}

      {/* ===== CHANNEL INFO OVERLAY ===== */}
      <AnimatePresence mode="wait">
        {previewChannel && (
          <motion.div
            key={previewChannel.id}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            transition={{ duration: 0.3 }}
            className="absolute bottom-10 left-8 z-10 max-w-lg"
          >
            <div className="flex items-center gap-2 mb-3">
              <span className="px-2.5 py-1 bg-red-500/90 rounded-md text-white text-xs tracking-wide">LIVE</span>
              <span className="px-2.5 py-1 bg-white/15 backdrop-blur-md rounded-md text-white/80 text-xs">{previewChannel.country} {previewChannel.category}</span>
              <span className="px-2.5 py-1 bg-white/10 backdrop-blur-md rounded-md text-white/50 text-xs">CH {previewChannel.number}</span>
            </div>

            <h1 className="text-white text-3xl mb-1 drop-shadow-lg">{previewChannel.name}</h1>
            <p className="text-white/60 text-sm mb-3">{previewChannel.description || previewChannel.currentProgram}</p>

            <div className="flex items-center gap-4 mb-4">
              <div className="flex items-center gap-1.5 text-indigo-300 text-xs">
                <Clock className="w-3 h-3" />
                <span>{previewChannel.currentProgram}</span>
              </div>
              <div className="flex items-center gap-1.5 text-white/30 text-xs">
                <Clock className="w-3 h-3" />
                <span>Далее: {previewChannel.nextProgram}</span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => onPlay(previewChannel)}
                className="flex items-center gap-2 px-5 py-2.5 bg-white text-[#1a1a2e] rounded-xl hover:scale-[1.03] transition-transform text-sm"
              >
                <Play className="w-4 h-4" />
                Смотреть
              </button>
              <button
                onClick={() => onToggleFavorite(previewChannel.id)}
                className="w-10 h-10 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center hover:bg-white/20 transition-colors border border-white/10"
              >
                <Star className={`w-4 h-4 ${favorites.includes(previewChannel.id) ? 'text-yellow-400 fill-yellow-400' : 'text-white/60'}`} />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
