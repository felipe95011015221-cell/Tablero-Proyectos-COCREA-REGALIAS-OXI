/*
 * dash.js: capa mínima que reemplaza al tipo Dashboard de Claude para que el tablero
 * funcione como página independiente (por ejemplo en GitHub Pages).
 *
 * Implementa lo que usa tablero/index.html:
 *   dash.data(id)            -> { status, data, message, refreshing, meta }
 *   dash.calc(id, {inputs, fn})
 *   dash.draw(name, fn)      registra un dibujo; dash.draw(name) lo vuelve a correr
 *   dash.colors              ocho colores de serie (siguen el tema claro/oscuro)
 *
 * Los datos se leen de datos/<id>.json, relativo a la página.
 */
(function () {
  'use strict';

  const SCRIPT = document.currentScript;
  const BASE = (SCRIPT && SCRIPT.dataset.base) || 'datos/';
  // Fuentes de datos: data-datasets="a b c" en la etiqueta <script>; por omisión, las del tablero de OxI.
  // Una fuente se descarga la primera vez que la pide un dibujo visible (las pestañas ocultas no cargan).
  const DATASETS = ((SCRIPT && SCRIPT.dataset.datasets) ||
    'ministerios cupos indicadores educacion_componentes educacion_departamentos proyectos tramite cruce_municipios ejecucion vencidos').split(/\s+/).filter(Boolean);
  const ARCHIVOS = {};  // id -> archivo, desde data-files="id:archivo.json ..."
  ((SCRIPT && SCRIPT.dataset.files) || '').split(/\s+/).filter(Boolean).forEach((p) => { const [id, f] = p.split(':'); ARCHIVOS[id] = f; });

  const sources = new Map();   // id -> { status, data, message }
  const calcs = new Map();     // id -> { inputs, fn, cache, key }
  const draws = new Map();     // name -> fn
  let started = false;
  let pending = false;

  function asRows(json) {
    if (Array.isArray(json)) return json;
    if (json && typeof json === 'object') return json.rows || json.data || json.results || [];
    return [];
  }

  function load(id) {
    sources.set(id, { status: 'loading', data: [] });
    fetch(BASE + (ARCHIVOS[id] || id + '.json'), { cache: 'no-cache' })
      .then((r) => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .then((json) => { sources.set(id, { status: 'ok', data: asRows(json) }); schedule(); })
      .catch((e) => { sources.set(id, { status: 'error', data: [], message: String(e.message || e) }); schedule(); });
  }

  function result(status, data, message) {
    const rows = Array.isArray(data) ? data : [];
    return {
      status, data: data == null ? [] : data, message: message || '', refreshing: false, meta: [],
      rows, columns: rows.length && typeof rows[0] === 'object' ? Object.keys(rows[0]) : [],
    };
  }

  function data(id) {
    if (calcs.has(id)) {
      const c = calcs.get(id);
      const ins = c.inputs.map((i) => data(i));
      if (ins.some((d) => d.status === 'error')) return result('error', [], 'Falló una fuente de este cálculo');
      if (ins.some((d) => d.status !== 'ok')) return result('loading', []);
      const key = ins.map((d) => d.data);
      if (!c.key || c.key.some((k, i) => k !== key[i])) {
        try { c.cache = c.fn(...key); c.error = null; } catch (e) { c.cache = []; c.error = e; console.error('Cálculo ' + id, e); }
        c.key = key;
      }
      return c.error ? result('error', [], String(c.error)) : result('ok', c.cache);
    }
    if (!sources.has(id)) {
      if (DATASETS.includes(id)) load(id);
      else return result('missing', [], 'Fuente desconocida: ' + id);
    }
    const s = sources.get(id);
    return result(s.status, s.data, s.message);
  }

  function runDraw(name) {
    const fn = draws.get(name);
    if (!fn) return;
    document.querySelectorAll('[data-draw="' + name + '"]').forEach((el) => {
      if (el.closest('[hidden]')) return;
      try { fn(el); } catch (e) { console.error('Dibujo ' + name, e); }
    });
  }

  function runAll() {
    pending = false;
    draws.forEach((_, name) => runDraw(name));
  }

  function schedule() {
    if (!started || pending) return;
    pending = true;
    setTimeout(runAll, 16);
  }

  function draw(name, fn) {
    if (typeof fn === 'function') { draws.set(name, fn); return; }
    if (started) runDraw(name);
  }

  function calc(id, spec) {
    calcs.set(id, { inputs: spec.inputs || [], fn: spec.fn, title: spec.title, description: spec.description });
  }

  // Colores de serie: variables CSS, así siguen el tema claro u oscuro.
  const colors = [1, 2, 3, 4, 5, 6, 7, 8].map((n) => 'var(--ox-serie-' + n + ')');

  window.dash = {
    data, calc, draw, colors,
    onData(fn) { draws.set('__onData' + draws.size, () => fn()); },
    refresh(id) { if (DATASETS.includes(id)) { load(id); } },
    params() { return {}; }, setParams() { schedule(); }, resetParams() { schedule(); },
    setLink(name) { try { history.replaceState(null, '', name ? '#' + name : location.pathname + location.search); } catch (e) { /* sin historial */ } },
  };

  // Arranque: después de que corren los scripts de la página.
  function start() {
    started = true;
    if (SCRIPT && SCRIPT.dataset.preload !== 'no') DATASETS.forEach((id) => { if (!sources.has(id)) load(id); });
    runAll();
    // Al mostrar u ocultar una sección (pestañas), redibuja: los dibujos ocultos no corren.
    new MutationObserver(schedule).observe(document.body, { subtree: true, attributes: true, attributeFilter: ['hidden'] });
    // Redibuja cuando cambia el ancho de la página (también si cargó oculta o en segundo plano).
    let lastW = document.documentElement.clientWidth;
    let t = null;
    const alCambiar = () => {
      const w = document.documentElement.clientWidth;
      if (w === lastW) return;
      lastW = w;
      clearTimeout(t);
      t = setTimeout(schedule, 120);
    };
    window.addEventListener('resize', alCambiar);
    if (window.ResizeObserver) new ResizeObserver(alCambiar).observe(document.documentElement);
    document.addEventListener('visibilitychange', alCambiar);
    // Los colores de los gráficos se leen al dibujar: redibuja si cambia el tema.
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    if (mq.addEventListener) mq.addEventListener('change', schedule);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else setTimeout(start, 0);
})();
