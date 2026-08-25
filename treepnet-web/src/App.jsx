import { useEffect, useRef, useState } from "react";
import { I18N, LANGS } from "./i18n";
import { Phone, FeedScreen, ProfileScreen, MapScreen, ChatScreen } from "./Mockups";
import LeafletMap from "./LeafletMap";
import "./App.css";

/* Reveal-on-scroll wrapper. */
function Reveal({ children, className = "", delay = 0, tag: Tag = "div" }) {
  const ref = useRef(null);
  const [seen, setSeen] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([e]) => { if (e.isIntersecting) { setSeen(true); io.disconnect(); } },
      { threshold: 0.12 }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return (
    <Tag ref={ref} className={`reveal ${seen ? "in" : ""} ${className}`} style={{ transitionDelay: `${delay}ms` }}>
      {children}
    </Tag>
  );
}

function AutoSlider({ slides }) {
  const [idx, setIdx] = useState(0);
  const timerRef = useRef(null);

  const resetTimer = () => {
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = setInterval(() => {
      setIdx((i) => (i + 1) % slides.length);
    }, 5000);
  };

  useEffect(() => {
    resetTimer();
    return () => clearInterval(timerRef.current);
  }, [slides.length]);

  const nextSlide = () => { setIdx((i) => (i + 1) % slides.length); resetTimer(); };
  const prevSlide = () => { setIdx((i) => (i === 0 ? slides.length - 1 : i - 1)); resetTimer(); };

  const [startX, setStartX] = useState(null);

  const handleStart = (e) => {
    setStartX(e.type.includes('touch') ? e.touches[0].clientX : e.clientX);
  };

  const handleEnd = (e) => {
    if (startX === null) return;
    const endX = e.type.includes('touch') ? e.changedTouches[0].clientX : e.clientX;
    const diff = startX - endX;
    setStartX(null);

    if (diff > 40) nextSlide();
    else if (diff < -40) prevSlide();
    else {
      const rect = e.currentTarget.getBoundingClientRect();
      const clickX = endX - rect.left;
      if (clickX < rect.width / 2) prevSlide();
      else nextSlide();
    }
  };

  return (
    <div className="hero-slider-wrapper">
      <div 
        className="hero-slider"
        onTouchStart={handleStart}
        onTouchEnd={handleEnd}
        onMouseDown={handleStart}
        onMouseUp={handleEnd}
        onMouseLeave={(e) => { if (e.buttons > 0) handleEnd(e); }}
      >
        {slides.map((s, i) => (
          <img 
            key={s.src} 
            src={s.src} 
            className={i === idx ? "active" : ""} 
            alt="" 
            draggable="false"
            style={{ objectFit: "contain", background: "#000" }}
          />
        ))}
      </div>
      <div className="slider-text">
        {slides.map((s, i) => (
          <p key={i} className={i === idx ? "active" : ""}>{s.text}</p>
        ))}
      </div>
      <div className="slider-dots">
        {slides.map((s, i) => (
          <span 
            key={i} 
            className={i === idx ? "active" : ""} 
            onClick={() => { setIdx(i); resetTimer(); }} 
          />
        ))}
      </div>
    </div>
  );
}

/* -------------------------------------------------------------------------- */
export default function App() {
  const [lang, setLang] = useState(() => {
    const saved = localStorage.getItem("tn_lang");
    return I18N[saved] ? saved : "en";
  });
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const t = I18N[lang];

  useEffect(() => {
    localStorage.setItem("tn_lang", lang);
    document.documentElement.lang = lang;
    
    // Update SEO tags dynamically
    document.title = t.seo_title;
    
    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) metaDesc.setAttribute("content", t.seo_desc);
    
    const ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle) ogTitle.setAttribute("content", t.seo_title);
    
    const ogDesc = document.querySelector('meta[property="og:description"]');
    if (ogDesc) ogDesc.setAttribute("content", t.seo_desc);
  }, [lang, t]);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const nav = [];

  return (
    <>
      {/* ---------------------------------------------------------- NAV --- */}
      <header className={"nav " + (scrolled ? "scrolled" : "")}>
        <div className="wrap nav-in">
          <a href="#top" className="brand">
            <img src="/logo.jpg" alt="Treepnet" />
            <span>Treepnet</span>
          </a>

          <div className="nav-right">
            <div className="lang">
              {LANGS.map((l) => (
                <button key={l} className={lang === l ? "on" : ""} onClick={() => setLang(l)}>{l.toUpperCase()}</button>
              ))}
            </div>
            <a href="#get" className="btn btn-primary nav-cta">{t.nav_get}</a>

          </div>
        </div>
      </header>

      {/* --------------------------------------------------------- HERO --- */}
      <section className="hero" id="top">
        <div className="wrap hero-in">
          <div className="hero-copy">

            <Reveal delay={60}><h1>{t.hero_title} <br/> <span className="gradient-text">{t.hero_title_hl}</span></h1></Reveal>
            <Reveal delay={120}><p className="lead">{t.hero_lead}</p></Reveal>
            <Reveal delay={180} className="hero-cta desktop-cta">
              <a href="#get" className="btn btn-primary">{t.hero_cta1}</a>
              <a href="#how" className="btn btn-ghost">{t.hero_cta2}</a>
            </Reveal>

          </div>
          <Reveal delay={140} className="hero-phone">
            <div className="phone-glow" />
            <AutoSlider slides={[
              { src: "/slider/1-rasm.jpg", text: t.slider_1 },
              { src: "/slider/2-rasm.jpg", text: t.slider_2 },
              { src: "/slider/3-rasm.jpg", text: t.slider_3 },
              { src: "/slider/5-rasm.jpg", text: t.slider_4 },
              { src: "/slider/6-rasm.jpg", text: t.slider_5 }
            ]} />
          </Reveal>
          <Reveal delay={180} className="hero-cta mobile-cta">
            <a href="#get" className="btn btn-primary">{t.hero_cta1}</a>
            <a href="#how" className="btn btn-ghost">{t.hero_cta2}</a>
          </Reveal>
        </div>
      </section>



      {/* --------------------------------------------------------- HOW --- */}
      <section id="how">
        <div className="wrap">
          <Reveal className="section-head">
            <span className="eyebrow">{t.how_eye}</span>
            <h2>{t.how_title}</h2>
            <p>{t.how_sub}</p>
          </Reveal>
          <div className="steps">
            {[[t.st1_t, t.st1_d], [t.st2_t, t.st2_d], [t.st3_t, t.st3_d], [t.st4_t, t.st4_d]].map(([tt, dd], i) => (
              <Reveal className="step" delay={i * 70} key={i}>
                <span className="step-n">{i + 1}</span>
                <h3>{tt}</h3>
                <p>{dd}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>









      {/* --------------------------------------------------------- GET --- */}
      <section id="get" className="get">
        <div className="wrap">
          <Reveal className="get-card">
            <h2>{t.cta_download_for}</h2>
            <div className="stores">
              <a className="store" href="https://play.google.com/store/apps/details?id=com.treepnet.application" target="_blank" rel="noopener noreferrer">
                <span className="store-ico" style={{ display: 'flex', alignItems: 'center' }}>
                  <svg viewBox="0 0 512 512" width="24" height="24" fill="currentColor"><path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6l-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z"/></svg>
                </span>
                <span className="store-txt" style={{ justifyContent: 'center' }}><b>Google Play</b></span>
              </a>
              <a className="store" href="#get">
                <span className="store-ico" style={{ display: 'flex', alignItems: 'center' }}>
                  <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.68.78-1.3 2.22-.11 3.597 1.35.1 2.662-.806 3.497-1.818z"/></svg>
                </span>
                <span className="store-txt" style={{ justifyContent: 'center' }}><b>App Store</b></span>
              </a>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ------------------------------------------------------ FOOTER --- */}
      <footer>
        <div className="wrap footer-in">
          <div className="footer-brand">
            <a href="#top" className="brand"><img src="/logo.jpg" alt="" /><span>Treepnet</span></a>
            <p>{t.foot_about}</p>
          </div>
          <div className="footer-col">
            <h4>{t.foot_contacts}</h4>
            <a href="mailto:treepnetofficial@gmail.com">treepnetofficial@gmail.com</a>
            <a href="tel:+998977907557">+998 97 790 75 57</a>
          </div>
        </div>
        <div className="wrap footer-bottom">
          <span>&copy; 2026 Treepnet</span>
          <span>{t.foot_slogan}</span>
        </div>
      </footer>
    </>
  );
}

