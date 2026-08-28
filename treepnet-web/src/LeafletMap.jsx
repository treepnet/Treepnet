import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import "./LeafletMap.css";

// A real Leaflet map — the web twin of the app's flutter_map travel map.
// No external tiles: just the ocean colour + our admin-1 province polygons,
// shaded by post density exactly like the app's _colorForCount. Any province
// is clickable/selectable.
const DENS = { 1: "#5bb8e8", 2: "#1e7fe0", 3: "#a020c7", 4: "#ed2a93", 5: "#e01b24" };
const COUNT = { 1: 14, 2: 33, 3: 51, 4: 72, 5: 96 };
// The famous "visited" provinces, by ISO 3166-2 code → density tier. All of
// Uzbekistan lights up (home turf), plus major cities/regions worldwide.
const CHOSEN = {
  // Uzbekistan — every region
  "UZ-SA": 5, "UZ-TO": 5, "UZ-TK": 3, "UZ-BU": 4, "UZ-XO": 3, "UZ-FA": 3,
  "UZ-AN": 3, "UZ-NG": 2, "UZ-QA": 2, "UZ-SU": 2, "UZ-NW": 2, "UZ-JI": 1,
  "UZ-SI": 1, "UZ-QR": 2,
  // World
  "FR-75": 5, "IT-RM": 3, "ES-B": 2, "JP-13": 4, "TR-34": 3, "US-NY": 4,
  "RU-MOS": 2, "BR-RJ": 2, "EG-C": 1, "CN-BJ": 3, "TH-10": 1, "IN-DL": 2,
  "AE-AZ": 1, "AE-SH": 1, "DE-BE": 3, "ES-M": 3, "KR-11": 4, "AU-NSW": 3,
  "ID-BA": 4, "NL-NH": 2, "AT-9": 2, "CZ-PR": 2, "GR-A1": 2, "PT-11": 1,
  "ZA-WC": 2, "IT-VE": 3, "AZ-BA": 1, "KZ-ALA": 1, "GE-TB": 1,
  "US-CA": 4, "CN-SH": 3, "IN-MH": 3, "ID-JK": 2, "MX-DIF": 3, "AR-C": 2,
  "DE-BY": 2, "MA-11": 2,
};
export default function LeafletMap({ t }) {
  const elRef = useRef(null);
  const mapRef = useRef(null);
  const layerRef = useRef(null);
  const selLyr = useRef(null);
  const [sel, setSel] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (mapRef.current || !elRef.current) return;
    const map = L.map(elRef.current, {
      center: [30, 26],
      zoom: 2.6,
      minZoom: 2,
      maxZoom: 8,
      zoomSnap: 0.25,
      zoomControl: false,
      attributionControl: false,
      worldCopyJump: false,
      maxBounds: [[-82, -195], [84, 195]],
      maxBoundsViscosity: 0.85,
      dragging: !L.Browser.mobile,
      tap: !L.Browser.mobile,
    });
    mapRef.current = map;
    L.control.zoom({ position: "topright" }).addTo(map);

    const canvas = L.canvas({ padding: 0.5 });   // fast base land (thousands of shapes)
    const borderCanvas = L.canvas({ padding: 0.5 }); // country outlines
    const svg = L.svg({ padding: 0.5 });          // the 31 famous provinces — so they can glow
    let cancelled = false;

    Promise.all([
      fetch("/world_admin1.min.json").then((r) => r.json()),
      fetch("/world-countries.geo.json").then((r) => r.json()),
    ])
      .then(([gj, countries]) => {
        if (cancelled) return;

        // Base: every non-famous province, drawn dark and NOT clickable. Province
        // borders are visible thin lines so you can see the whole grid of regions.
        L.geoJSON(gj, {
          renderer: canvas,
          interactive: false,
          filter: (f) => !CHOSEN[f.properties.iso],
          style: () => ({ color: "rgba(255,255,255,0.20)", weight: 0.5, fillColor: "#242a31", fillOpacity: 1 }),
        }).addTo(map);

        // Country outlines — white and thick, so nations clearly stand out above
        // the finer province grid.
        L.geoJSON(countries, {
          renderer: borderCanvas,
          interactive: false,
          style: () => ({ color: "rgba(255,255,255,0.82)", weight: 1.9, fill: false, lineJoin: "round" }),
        }).addTo(map);

        // Famous provinces: colored, glowing (SVG so CSS drop-shadow applies), clickable.
        const layer = L.geoJSON(gj, {
          renderer: svg,
          filter: (f) => !!CHOSEN[f.properties.iso],
          style: (f) => {
            const tier = CHOSEN[f.properties.iso];
            return { className: `lmap-prov lmap-t${tier}`, color: "#ffffff", weight: 1, opacity: 0.9, fillColor: DENS[tier], fillOpacity: 0.92 };
          },
          onEachFeature: (f, lyr) => {
            lyr.on("click", () => {
              if (selLyr.current) layer.resetStyle(selLyr.current);
              selLyr.current = lyr;
              const tier = CHOSEN[f.properties.iso];
              lyr.setStyle({ className: `lmap-prov lmap-t${tier} sel`, color: "#ffffff", weight: 2.6, opacity: 1, fillOpacity: 1 });
              lyr.bringToFront();
              setSel({ name: f.properties.name, admin: f.properties.admin, tier, count: COUNT[tier], color: DENS[tier] });
            });
          },
        }).addTo(map);
        layerRef.current = layer;
        setLoading(false);
        // The container is laid out at a fixed size, but recompute anyway so the
        // click→coordinate mapping is always exact.
        map.invalidateSize();
        setTimeout(() => map.invalidateSize(), 350);
      })
      .catch(() => setLoading(false));

    return () => {
      cancelled = true;
      map.remove();
      mapRef.current = null;
    };
  }, []);

  return (
    <div className="lmap">
      <div className="lmap-canvas" ref={elRef} />
      {loading && <div className="lmap-loading"><span className="lmap-spin" />{t?.map_loading || "Xarita yuklanmoqda…"}</div>}

      <div className="lmap-legend">
        <span className="lmap-legend-h">{t?.map_density || "Post zichligi"}</span>
        {[["1–20", DENS[1]], ["21–40", DENS[2]], ["41–60", DENS[3]], ["61–80", DENS[4]], ["80+", DENS[5]]].map(([lbl, c]) => (
          <span key={lbl}><i style={{ background: c }} />{lbl}</span>
        ))}
      </div>

      <div className="lmap-hint">🖱️ {t?.map_hint || "Kattalashtiring · viloyatni bosing"}</div>

      {sel && (
        <div className="lmap-info">
          <button className="lmap-close" onClick={() => { if (selLyr.current && layerRef.current) layerRef.current.resetStyle(selLyr.current); selLyr.current = null; setSel(null); }}>×</button>
          <span className="lmap-info-eye" style={{ color: sel.color }}>● {t?.map_selected || "Tanlangan viloyat"}</span>
          <b>{sel.name}</b>
          <span className="lmap-info-admin">{sel.admin}</span>
          <div className="lmap-info-count"><b style={{ color: sel.color }}>{sel.count}</b> {t?.map_posts || "post"}</div>
        </div>
      )}
    </div>
  );
}
