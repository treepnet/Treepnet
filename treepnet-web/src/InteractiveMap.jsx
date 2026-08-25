import { useRef, useState, useCallback } from "react";
import { PROVINCES, MAP_W, MAP_H } from "./provinces";
import "./InteractiveMap.css";

const TIERS = [1, 2, 3, 4, 5];
const TIER_COLOR = { 1: "#5bb8e8", 2: "#1e7fe0", 3: "#a020c7", 4: "#ed2a93", 5: "#e01b24" };
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const MIN_S = 1, MAX_S = 8;

// A pan/zoom-able world map where the 16 famous provinces are clickable.
export default function InteractiveMap({ t }) {
  const vpRef = useRef(null);
  const drag = useRef(null);
  const [view, setView] = useState({ s: 1, x: 0, y: 0 });
  const [sel, setSel] = useState(null);

  const clampPan = (v, w, h) => {
    const lw = w * v.s, lh = h * v.s;
    return { s: v.s, x: clamp(v.x, w - lw, 0), y: clamp(v.y, h - lh, 0) };
  };

  const zoomAt = useCallback((cx, cy, factor) => {
    const vp = vpRef.current?.getBoundingClientRect();
    if (!vp) return;
    const px = cx - vp.left, py = cy - vp.top;
    setView((v) => {
      const ns = clamp(v.s * factor, MIN_S, MAX_S);
      const k = ns / v.s;
      return clampPan({ s: ns, x: px - (px - v.x) * k, y: py - (py - v.y) * k }, vp.width, vp.height);
    });
  }, []);

  const onWheel = (e) => {
    e.preventDefault();
    zoomAt(e.clientX, e.clientY, e.deltaY < 0 ? 1.18 : 1 / 1.18);
  };

  const onPointerDown = (e) => {
    vpRef.current.setPointerCapture(e.pointerId);
    drag.current = { x: e.clientX, y: e.clientY, sx: view.x, sy: view.y, moved: 0 };
  };
  const onPointerMove = (e) => {
    if (!drag.current) return;
    const dx = e.clientX - drag.current.x, dy = e.clientY - drag.current.y;
    drag.current.moved = Math.max(drag.current.moved, Math.abs(dx) + Math.abs(dy));
    const vp = vpRef.current.getBoundingClientRect();
    setView((v) => clampPan({ s: v.s, x: drag.current.sx + dx, y: drag.current.sy + dy }, vp.width, vp.height));
  };
  const onPointerUp = (e) => {
    if (vpRef.current.hasPointerCapture?.(e.pointerId)) vpRef.current.releasePointerCapture(e.pointerId);
    // treat as a click only if the pointer barely moved
    setTimeout(() => (drag.current = null), 0);
  };

  const pickProvince = (p) => {
    if (drag.current && drag.current.moved > 6) return; // was a pan, not a tap
    setSel(p);
  };

  const btnZoom = (factor) => {
    const vp = vpRef.current.getBoundingClientRect();
    zoomAt(vp.left + vp.width / 2, vp.top + vp.height / 2, factor);
  };
  const reset = () => { setView({ s: 1, x: 0, y: 0 }); setSel(null); };

  return (
    <div className="imap">
      <div
        className="imap-vp"
        ref={vpRef}
        onWheel={onWheel}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerLeave={onPointerUp}
        style={{ cursor: drag.current ? "grabbing" : "grab" }}
      >
        <div className="imap-layer" style={{ transform: `translate(${view.x}px, ${view.y}px) scale(${view.s})` }}>
          <img className="imap-base" src="/world-map-base.svg" alt="" draggable={false} />
          <svg className="imap-ov" viewBox={`0 0 ${MAP_W} ${MAP_H}`} preserveAspectRatio="xMidYMid meet">
            <defs>
              {TIERS.map((n) => (
                <radialGradient id={`ig${n}`} key={n}>
                  <stop offset="0" stopColor={TIER_COLOR[n]} stopOpacity="0.75" />
                  <stop offset="100%" stopColor={TIER_COLOR[n]} stopOpacity="0" />
                </radialGradient>
              ))}
            </defs>
            {PROVINCES.map((p) => (
              <g key={p.id} className={"imap-prov" + (sel?.id === p.id ? " sel" : "")} onClick={() => pickProvince(p)}>
                <circle cx={p.cx} cy={p.cy} r={sel?.id === p.id ? 34 : 26} fill={`url(#ig${p.tier})`} />
                <path d={p.d} fill={p.color} fillOpacity="0.95" stroke="#fff" strokeWidth={sel?.id === p.id ? 2.4 : 0.9} vectorEffect="non-scaling-stroke" />
              </g>
            ))}
          </svg>
        </div>

        <div className="imap-ctrl">
          <button onClick={() => btnZoom(1.4)} aria-label="zoom in">+</button>
          <button onClick={() => btnZoom(1 / 1.4)} aria-label="zoom out">−</button>
          <button onClick={reset} aria-label="reset" className="imap-reset">⟳</button>
        </div>

        <div className="imap-hint">🖱️ {t?.map_hint || "Sichqoncha g'ildiragi bilan kattalashtiring · viloyatni bosing"}</div>

        {sel && (
          <div className="imap-info">
            <button className="imap-close" onClick={() => setSel(null)}>×</button>
            <span className="imap-info-eye" style={{ color: sel.color }}>● {t?.map_selected || "Tanlangan viloyat"}</span>
            <b>{sel.name}</b>
            <span className="imap-info-admin">{sel.admin}</span>
            <div className="imap-info-count"><b style={{ color: sel.color }}>{sel.count}</b> {t?.m_here || "post"}</div>
          </div>
        )}
      </div>
    </div>
  );
}
