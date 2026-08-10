#!/usr/bin/env node

/*
 * raffle.fun whitepaper figure generator.
 *
 * Produces 21 bespoke, self-contained SVG diagrams. Every figure is drawn for
 * its specific content -- state machine, sequence diagram, timeline, money
 * flow, architecture map -- rather than from a generic box-grid template.
 *
 * Constraints the drawings honor:
 * - Economic and timing labels come from the compiled protocol facts.
 * - Every <defs> id is namespaced per figure because build.py inlines all 21
 *   SVGs into one HTML document; duplicate ids would resolve to the first.
 * - Text is measured with a conservative width model and asserted to fit its
 *   container, so an overflowing label fails the build instead of clipping.
 * - Glyphs stay inside the embedded latin font subsets (no arrow or check
 *   glyphs; arrows, checks, and crosses are drawn as paths).
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildFacts } from "./protocol-facts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const output = resolve(here, "../assets/diagrams");
const facts = buildFacts();
const E = facts.examples;
const C = facts.display;
const K = facts.constants;

/* ------------------------------------------------------------- palette -- */

const pal = {
  ink: "#10143a",
  ink2: "#454b78",
  ink3: "#676c94",
  ink4: "#9aa0c0",
  indigo: "#1e2a9b",
  indigoDeep: "#131f77",
  violet: "#7b3fe4",
  violetWash: "#f1eafc",
  pink: "#d31d8b",
  pinkWash: "#fce9f5",
  yellow: "#eab308",
  yellowBright: "#ffd84d",
  yellowWash: "#fff5d6",
  amberInk: "#7a4f00",
  sky: "#5aa9ff",
  skyDeep: "#1f6fd0",
  skyWash: "#e8f2ff",
  green: "#22b573",
  greenDeep: "#0d6b45",
  greenWash: "#e3f7ee",
  danger: "#c8213f",
  dangerWash: "#fdeaee",
  slate: "#676c94",
  slateWash: "#eeeef8",
  paper: "#fcfcff",
  sunk: "#f4f4fb",
  white: "#ffffff",
  line: "#dcdded",
  lineStrong: "#c3c5dd",
};

const F_BODY = "Inter,'Helvetica Neue',Arial,sans-serif";
const F_DISP = "Nunito,Inter,'Helvetica Neue',Arial,sans-serif";
const F_MONO = "'SF Mono',Menlo,Consolas,monospace";

const W = 720; // canvas width for every figure

/* -------------------------------------------------------- text metrics -- */

const NARROW = new Set("ijltf.,:;!|'()[]{}· ");
const WIDE = new Set("mwMW@%");

function charW(ch) {
  if (ch === " ") return 0.3;
  if (ch === "·") return 0.34;
  if (NARROW.has(ch)) return 0.35;
  if (WIDE.has(ch)) return 0.92;
  if (/[A-Z]/.test(ch)) return 0.7;
  if (/[0-9]/.test(ch)) return 0.63;
  if (/[a-z]/.test(ch)) return 0.55;
  return 0.6;
}

function estW(text, size, weight = 500, mono = false) {
  if (mono) return String(text).length * size * 0.63;
  let units = 0;
  for (const ch of String(text)) units += charW(ch);
  const weightFactor = 1 + (Math.max(weight, 400) - 400) * 0.00012;
  return units * size * weightFactor * 1.04;
}

function wrapW(text, maxPx, size, weight = 500) {
  const words = String(text).split(/\s+/).filter(Boolean);
  const lines = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (estW(candidate, size, weight) > maxPx && line) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) lines.push(line);
  return lines;
}

function assertFits(ctx, text, px, maxPx, what) {
  if (px > maxPx + 1) {
    throw new Error(
      `figure ${ctx.uid}: ${what} overflows (${Math.round(px)}px > ${Math.round(maxPx)}px): "${text}"`,
    );
  }
}

function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/* ------------------------------------------------------------- context -- */

function makeCtx(uid) {
  return { uid, parts: [], defs: [], markers: new Map() };
}

function put(ctx, svg) {
  ctx.parts.push(svg);
}

function markerId(ctx, color) {
  const id = `${ctx.uid}m${color.replace("#", "")}`;
  if (!ctx.markers.has(id)) ctx.markers.set(id, color);
  return id;
}

function finish(ctx, { title, desc, height }) {
  const markerDefs = [...ctx.markers.entries()]
    .map(
      ([id, color]) =>
        `<marker id="${id}" viewBox="0 0 10 10" refX="8.4" refY="5" markerWidth="6.4" markerHeight="6.4" orient="auto-start-reverse"><path d="M 0 0.6 L 9.4 5 L 0 9.4 z" fill="${color}"/></marker>`,
    )
    .join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="${ctx.uid}-title ${ctx.uid}-desc" viewBox="0 0 ${W} ${height}" font-family="${esc(F_BODY)}">
  <title id="${ctx.uid}-title">${esc(title)}</title>
  <desc id="${ctx.uid}-desc">${esc(desc)}</desc>
  <defs>${markerDefs}${ctx.defs.join("")}</defs>
  <rect x="0.75" y="0.75" width="${W - 1.5}" height="${height - 1.5}" rx="17" fill="${pal.paper}" stroke="${pal.line}" stroke-width="1.5"/>
  ${ctx.parts.join("\n  ")}
</svg>`;
}

/* ---------------------------------------------------------- primitives -- */

function txt(x, y, str, o = {}) {
  const {
    size = 12,
    weight = 600,
    color = pal.ink,
    anchor = "start",
    family = F_BODY,
    mono = false,
    spacing,
    opacity,
  } = o;
  const fam = mono ? F_MONO : family;
  const extra =
    (spacing ? ` letter-spacing="${spacing}"` : "") +
    (opacity ? ` opacity="${opacity}"` : "");
  return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${esc(fam)}" font-size="${size}" font-weight="${weight}" fill="${color}"${extra}>${esc(str)}</text>`;
}

function linesTxt(x, y, arr, lh, o = {}) {
  const {
    size = 12,
    weight = 500,
    color = pal.ink3,
    anchor = "start",
    mono = false,
  } = o;
  const fam = mono ? F_MONO : F_BODY;
  const spans = arr
    .map(
      (line, i) => `<tspan x="${x}" dy="${i === 0 ? 0 : lh}">${esc(line)}</tspan>`,
    )
    .join("");
  return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${esc(fam)}" font-size="${size}" font-weight="${weight}" fill="${color}">${spans}</text>`;
}

/* Small-caps section label. */
function tag(x, y, str, color = pal.ink3, anchor = "start", size = 9) {
  return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${esc(F_BODY)}" font-size="${size}" font-weight="750" letter-spacing="1.4" fill="${color}">${esc(String(str).toUpperCase())}</text>`;
}

/* Rounded pill with centered text; x is the left edge unless anchor=middle. */
function pill(ctx, o) {
  const {
    x,
    y,
    text,
    size = 10.5,
    weight = 700,
    fg = pal.ink2,
    bg = pal.white,
    stroke = pal.line,
    h = 22,
    padX = 10,
    anchor = "start",
    mono = false,
    dashed = false,
  } = o;
  const tw = estW(text, size, weight, mono);
  const w = tw + padX * 2;
  const left = anchor === "middle" ? x - w / 2 : x;
  const dash = dashed ? ' stroke-dasharray="4 3.2"' : "";
  const svg =
    `<g><rect x="${left.toFixed(1)}" y="${y}" width="${w.toFixed(1)}" height="${h}" rx="${h / 2}" fill="${bg}" stroke="${stroke}" stroke-width="1.3"${dash}/>` +
    txt(left + w / 2, y + h / 2 + size * 0.36, text, {
      size,
      weight,
      color: fg,
      anchor: "middle",
      mono,
    }) +
    "</g>";
  return { svg, w, left };
}

/* Straight arrow with optional label. */
function arrow(ctx, x1, y1, x2, y2, o = {}) {
  const {
    color = pal.ink3,
    width = 2,
    dashed = false,
    label,
    labelSize = 10,
    labelColor,
    labelDx = 0,
    labelDy = -6,
    labelAnchor = "middle",
    head = true,
    weight = 700,
  } = o;
  const dash = dashed ? ' stroke-dasharray="5 4"' : "";
  const marker = head ? ` marker-end="url(#${markerId(ctx, color)})"` : "";
  let svg = `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${width}" stroke-linecap="round"${dash}${marker}/>`;
  if (label) {
    const mx = (x1 + x2) / 2 + labelDx;
    const my = (y1 + y2) / 2 + labelDy;
    svg += txt(mx, my, label, {
      size: labelSize,
      weight,
      color: labelColor || color,
      anchor: labelAnchor,
    });
  }
  return svg;
}

/* Orthogonal connector through the given points. */
function elbow(ctx, pts, o = {}) {
  const { color = pal.ink3, width = 2, dashed = false, head = true, round = 7 } = o;
  let d = `M ${pts[0][0]} ${pts[0][1]}`;
  for (let i = 1; i < pts.length; i += 1) {
    const [x, y] = pts[i];
    if (round && i < pts.length - 1) {
      const [px, py] = pts[i - 1];
      const [nx, ny] = pts[i + 1];
      const inV = [Math.sign(x - px), Math.sign(y - py)];
      const outV = [Math.sign(nx - x), Math.sign(ny - y)];
      const bx = x - inV[0] * round;
      const by = y - inV[1] * round;
      const cx = x + outV[0] * round;
      const cy = y + outV[1] * round;
      d += ` L ${bx} ${by} Q ${x} ${y} ${cx} ${cy}`;
    } else {
      d += ` L ${x} ${y}`;
    }
  }
  const dash = dashed ? ' stroke-dasharray="5 4"' : "";
  const marker = head ? ` marker-end="url(#${markerId(ctx, color)})"` : "";
  return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round"${dash}${marker}/>`;
}

/* Smooth cubic connector between two points (horizontal tangents). */
function curve(ctx, x1, y1, x2, y2, o = {}) {
  const { color = pal.ink3, width = 2, dashed = false, head = true, bend = 0.5 } = o;
  const mx = x1 + (x2 - x1) * bend;
  const dash = dashed ? ' stroke-dasharray="5 4"' : "";
  const marker = head ? ` marker-end="url(#${markerId(ctx, color)})"` : "";
  return `<path d="M ${x1} ${y1} C ${mx} ${y1} ${mx} ${y2} ${x2} ${y2}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round"${dash}${marker}/>`;
}

/* Sankey-style ribbon between vertical segments. */
function ribbon(x1, y1a, y1b, x2, y2a, y2b, fill, opacity = 0.5) {
  const mx = (x1 + x2) / 2;
  return `<path d="M ${x1} ${y1a} C ${mx} ${y1a} ${mx} ${y2a} ${x2} ${y2a} L ${x2} ${y2b} C ${mx} ${y2b} ${mx} ${y1b} ${x1} ${y1b} Z" fill="${fill}" opacity="${opacity}"/>`;
}

/* Numbered circular badge. */
function badge(x, y, n, color = pal.indigo, r = 11) {
  return (
    `<circle cx="${x}" cy="${y}" r="${r}" fill="${color}"/>` +
    txt(x, y + 4, String(n), {
      size: 11.5,
      weight: 800,
      color: pal.white,
      anchor: "middle",
    })
  );
}

/* --------------------------------------------------------------- icons -- */

const ICONS = {
  ticket:
    '<path d="M3.5 7.5h17v3.1a1.9 1.9 0 0 0 0 2.8v3.1h-17v-3.1a1.9 1.9 0 0 0 0-2.8z"/><line x1="14.6" y1="8.8" x2="14.6" y2="15.2" stroke-dasharray="1.8 2"/>',
  gem: '<path d="M12 3.4 18.8 9 12 20.6 5.2 9 Z"/><path d="M5.2 9h13.6M12 3.4 9.6 9l2.4 11.6M12 3.4 14.4 9"/>',
  dice: '<rect x="4" y="4" width="16" height="16" rx="3.4"/><circle cx="9" cy="9" r="1.35" fill="currentColor" stroke="none"/><circle cx="15" cy="9" r="1.35" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.35" fill="currentColor" stroke="none"/><circle cx="9" cy="15" r="1.35" fill="currentColor" stroke="none"/><circle cx="15" cy="15" r="1.35" fill="currentColor" stroke="none"/>',
  coin: '<circle cx="12" cy="12" r="8.2"/><path d="M14.6 9.3c-.55-.95-1.5-1.35-2.5-1.35-1.3 0-2.35.7-2.35 1.85 0 2.5 4.9 1.35 4.9 3.9 0 1.25-1.15 1.95-2.55 1.95-1.1 0-2.1-.5-2.65-1.45M12 6.3v11.4"/>',
  trophy:
    '<path d="M8.2 4.2h7.6v4.4a3.8 3.8 0 0 1-7.6 0z"/><path d="M8.2 5.2H5.9a2.55 2.55 0 0 0 2.5 3.3M15.8 5.2h2.3a2.55 2.55 0 0 1-2.5 3.3M12 12.4v3.4M9.2 19.4h5.6M12 15.8c-1.7 0-2.6 1.1-2.8 3.6M12 15.8c1.7 0 2.6 1.1 2.8 3.6"/>',
  shield:
    '<path d="M12 3.2 18.8 6v5.1c0 4.3-2.8 7.2-6.8 8.7-4-1.5-6.8-4.4-6.8-8.7V6Z"/><path d="m9.1 11.7 2.1 2.1 3.9-4"/>',
  flame:
    '<path d="M12 3.4c.9 4.6 4.6 6 4.6 9.8a4.6 4.6 0 0 1-9.2 0c0-4 4-5.4 4.6-9.8Z"/><path d="M12 12.9c-1.1.75-1.7 1.6-1.7 2.55a1.7 1.7 0 0 0 3.4 0c0-.95-.6-1.8-1.7-2.55Z"/>',
  clock:
    '<circle cx="12" cy="12" r="8.3"/><path d="M12 7.4V12l3.1 2.1"/>',
  user: '<circle cx="12" cy="8.1" r="3.4"/><path d="M5.4 19.6a6.8 5.9 0 0 1 13.2 0"/>',
  factory:
    '<path d="M4.2 19.8V9.4l4.4 2.9V9.4l4.4 2.9V5.2h6.8v14.6Z"/><path d="M16.4 9h2m-2 3.4h2m-2 3.4h2"/>',
  doc: '<path d="M7 3.4h7.2l3.8 3.8v13.4H7Z"/><path d="M14.2 3.4v3.8H18M9.7 12h4.6M9.7 15.2h4.6"/>',
  check: '<path d="m5.4 12.6 4.3 4.3 8.9-9.6"/>',
  cross: '<path d="m6.6 6.6 10.8 10.8M17.4 6.6 6.6 17.4"/>',
  undo: '<path d="M6.6 5.4v4.4H11"/><path d="M6.9 9.6a6.9 6.9 0 1 1-1 4.9"/>',
  key: '<circle cx="8" cy="12" r="3.2"/><path d="M11.2 12h8m-3.4 0v3.1m3.4-3.1v2.3"/>',
  eye: '<path d="M2.9 12C5.1 7.8 8.4 5.6 12 5.6s6.9 2.2 9.1 6.4c-2.2 4.2-5.5 6.4-9.1 6.4S5.1 16.2 2.9 12Z"/><circle cx="12" cy="12" r="2.6"/>',
  scale:
    '<path d="M12 4.2v15M8.4 19.2h7.2M12 6.4 6.2 8.1m5.8-1.7 5.8 1.7"/><path d="M3.6 12.8h5.2L6.2 8.4Zm11.6 0h5.2l-2.6-4.4Z"/>',
  wallet:
    '<rect x="3.6" y="6.4" width="16.8" height="12" rx="2.6"/><path d="M15.6 12.4h4.8"/><circle cx="16.3" cy="12.4" r="0.9" fill="currentColor" stroke="none"/>',
  cube: '<path d="M12 3.2 19.8 7.6v8.8L12 20.8 4.2 16.4V7.6Z"/><path d="M4.2 7.6 12 12l7.8-4.4M12 12v8.8"/>',
  bolt: '<path d="M13.4 3.4 5.8 13.6h4.8l-1.4 7 7.6-10.2H12Z"/>',
  gate: '<path d="M5 20V6.8L12 3.4 19 6.8V20"/><path d="M9.4 20v-6.4a2.6 2.6 0 0 1 5.2 0V20"/>',
  bell: '<path d="M6.4 17h11.2c-1.4-1.2-1.9-2.7-1.9-4.6 0-3.2-1.5-5.5-3.7-5.5s-3.7 2.3-3.7 5.5c0 1.9-.5 3.4-1.9 4.6Z"/><path d="M10.4 19.4a1.7 1.7 0 0 0 3.2 0"/>',
  pause: '<circle cx="12" cy="12" r="8.3"/><path d="M9.7 8.8v6.4m4.6-6.4v6.4"/>',
  globe:
    '<circle cx="12" cy="12" r="8.3"/><path d="M3.7 12h16.6M12 3.7c-2.3 2.3-3.4 5.1-3.4 8.3s1.1 6 3.4 8.3c2.3-2.3 3.4-5.1 3.4-8.3S14.3 6 12 3.7Z"/>',
};

function icon(name, x, y, size = 20, color = pal.ink2, strokeWidth = 1.9) {
  const s = (size / 24).toFixed(3);
  return `<g transform="translate(${x} ${y}) scale(${s})" stroke="${color}" fill="none" stroke-width="${strokeWidth}" stroke-linecap="round" stroke-linejoin="round" color="${color}">${ICONS[name]}</g>`;
}

/* ------------------------------------------------------------ legend --- */

function legend(ctx, height, entries) {
  let x = 26;
  const y = height - 21;
  let svg = "";
  for (const entry of entries) {
    if (entry.swatch === "solid" || entry.swatch === "dashed") {
      const dash = entry.swatch === "dashed" ? ' stroke-dasharray="4.5 3.5"' : "";
      svg += `<line x1="${x}" y1="${y - 3.5}" x2="${x + 20}" y2="${y - 3.5}" stroke="${entry.color || pal.ink3}" stroke-width="2" stroke-linecap="round"${dash}/>`;
      x += 26;
    } else if (entry.swatch) {
      svg += `<rect x="${x}" y="${y - 9}" width="11" height="11" rx="3" fill="${entry.swatch}"/>`;
      x += 17;
    }
    svg += txt(x, y, entry.text, { size: 9.5, weight: 550, color: pal.ink3 });
    x += estW(entry.text, 9.5, 550) + 18;
  }
  put(ctx, svg);
}

/* Standard card: accent-tinted border, optional icon row, centered stack.  */
function card(ctx, o) {
  const {
    x,
    y,
    w,
    h,
    title,
    body = "",
    accent = pal.indigo,
    fill = pal.white,
    iconName,
    iconColor,
    num,
    titleSize = 12.5,
    bodySize = 10.5,
    bodyColor = pal.ink3,
    dashed = false,
    radius = 12,
    titleFamily = F_BODY,
    align = "center",
    strokeWidth = 1.6,
  } = o;
  const dash = dashed ? ' stroke-dasharray="5 4"' : "";
  let svg = `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="${fill}" stroke="${accent}" stroke-width="${strokeWidth}"${dash}/>`;
  const padX = 10;
  const innerW = w - padX * 2;
  const titleLines = wrapW(title, innerW, titleSize, 750);
  for (const line of titleLines)
    assertFits(ctx, line, estW(line, titleSize, 750), innerW, "card title");
  const bodyLines = body ? wrapW(body, innerW, bodySize, 500) : [];
  for (const line of bodyLines)
    assertFits(ctx, line, estW(line, bodySize, 500), innerW, "card body");
  const iconH = iconName ? 24 : 0;
  const titleH = titleLines.length * (titleSize + 3.5);
  const bodyH = bodyLines.length * (bodySize + 3.5);
  const gap1 = iconName ? 6 : 0;
  const gap2 = bodyLines.length ? 5 : 0;
  const contentH = iconH + gap1 + titleH + gap2 + bodyH;
  if (contentH > h - 12) {
    throw new Error(
      `figure ${ctx.uid}: card "${title}" content ${Math.round(contentH)}px exceeds height ${h - 12}px`,
    );
  }
  let cy = y + (h - contentH) / 2;
  const cx = x + w / 2;
  if (iconName) {
    svg += icon(iconName, cx - 11, cy, 22, iconColor || accent);
    cy += iconH + gap1;
  }
  cy += titleSize * 0.82;
  svg += linesTxt(align === "center" ? cx : x + padX, cy, titleLines, titleSize + 3.5, {
    size: titleSize,
    weight: 750,
    color: pal.ink,
    anchor: align === "center" ? "middle" : "start",
  });
  cy += (titleLines.length - 1) * (titleSize + 3.5);
  if (bodyLines.length) {
    cy += gap2 + bodySize * 0.9;
    svg += linesTxt(align === "center" ? cx : x + padX, cy, bodyLines, bodySize + 3.5, {
      size: bodySize,
      weight: 500,
      color: bodyColor,
      anchor: align === "center" ? "middle" : "start",
    });
  }
  if (num !== undefined) svg += badge(x + 1, y + 1, num, accent);
  put(ctx, svg);
}

/* Row-layout card: icon left, title beside it, body below full width. */
function rowCard(ctx, o) {
  const {
    x,
    y,
    w,
    h,
    title,
    body = "",
    accent = pal.indigo,
    fill = pal.white,
    iconName,
    titleSize = 12,
    bodySize = 10.3,
  } = o;
  let svg = `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="12" fill="${fill}" stroke="${pal.line}" stroke-width="1.2"/>`;
  svg += `<rect x="${x}" y="${y}" width="4.5" height="${h}" rx="2.25" fill="${accent}"/>`;
  const padL = 14;
  const iconSize = 19;
  let tx = x + padL;
  const titleY = y + 22;
  if (iconName) {
    svg += icon(iconName, tx, titleY - 15, iconSize, accent);
    tx += iconSize + 8;
  }
  assertFits(ctx, title, estW(title, titleSize, 760), x + w - 10 - tx, "rowCard title");
  svg += txt(tx, titleY, title, { size: titleSize, weight: 760, color: pal.ink });
  const innerW = w - padL - 12;
  const bodyLines = body ? wrapW(body, innerW, bodySize, 500) : [];
  for (const line of bodyLines)
    assertFits(ctx, line, estW(line, bodySize, 500), innerW, "rowCard body");
  const bodyH = bodyLines.length * (bodySize + 3.6);
  if (34 + bodyH > h) {
    throw new Error(
      `figure ${ctx.uid}: rowCard "${title}" body does not fit (${34 + bodyH} > ${h})`,
    );
  }
  if (bodyLines.length) {
    svg += linesTxt(x + padL, titleY + 16.5, bodyLines, bodySize + 3.6, {
      size: bodySize,
      weight: 500,
      color: pal.ink3,
    });
  }
  put(ctx, svg);
}

/* ===================================================================== */
/* Figures                                                                */
/* ===================================================================== */

const figures = {};

/* ------------------------------------------------ 01 at a glance ------- */

figures["01-at-a-glance.svg"] = (() => {
  const ctx = makeCtx("f01");
  const H = 336;
  const steps = [
    {
      t: "Create",
      b: "Sponsor fixes price, threshold, dates",
      icon: "doc",
      accent: pal.pink,
      fill: pal.pinkWash,
    },
    {
      t: "Escrow",
      b: "Factory locks the exact prize NFT",
      icon: "gem",
      accent: pal.indigo,
      fill: pal.skyWash,
    },
    {
      t: "Sell",
      b: "USDC in, bearer ticket NFTs out",
      icon: "ticket",
      accent: pal.skyDeep,
      fill: pal.white,
    },
    {
      t: "Draw",
      b: "One Pyth Entropy random callback",
      icon: "dice",
      accent: pal.violet,
      fill: pal.violetWash,
    },
    {
      t: "Redeem",
      b: "Burn tickets, pull USDC claims",
      icon: "trophy",
      accent: pal.green,
      fill: pal.greenWash,
    },
  ];
  const cw = 124;
  const gap = (W - 52 - cw * 5) / 4;
  const y = 40;
  const h = 118;
  steps.forEach((s, i) => {
    const x = 26 + i * (cw + gap);
    card(ctx, {
      x,
      y,
      w: cw,
      h,
      title: s.t,
      body: s.b,
      accent: s.accent,
      fill: s.fill,
      iconName: s.icon,
      num: i + 1,
      titleSize: 13.5,
    });
    if (i < steps.length - 1) {
      put(
        ctx,
        arrow(ctx, x + cw + 2.5, y + h / 2, x + cw + gap - 3, y + h / 2, {
          color: pal.ink3,
          width: 2.2,
        }),
      );
    }
  });
  // Failure branch from the Draw stage down to a refund strip.
  const drawX = 26 + 3 * (cw + gap) + cw / 2;
  const stripY = 218;
  put(
    ctx,
    elbow(
      ctx,
      [
        [drawX, y + h],
        [drawX, stripY + 27],
        [26 + 470, stripY + 27],
      ],
      { color: pal.danger, width: 2, dashed: true },
    ),
  );
  put(
    ctx,
    `<rect x="26" y="${stripY}" width="466" height="54" rx="12" fill="${pal.dangerWash}" stroke="${pal.danger}" stroke-width="1.3" stroke-dasharray="6 4"/>`,
  );
  put(ctx, icon("undo", 40, stripY + 17, 20, pal.danger));
  put(
    ctx,
    txt(70, stripY + 23, "If no draw request or callback lands in time", {
      size: 11.5,
      weight: 750,
      color: pal.danger,
    }),
  );
  put(
    ctx,
    txt(
      70,
      stripY + 39,
      "anyone enables refunds; owners burn tickets for the exact price paid",
      { size: 10.5, weight: 500, color: pal.ink2 },
    ),
  );
  legend(ctx, H, [
    { swatch: "solid", color: pal.ink3, text: "happy path" },
    { swatch: "dashed", color: pal.danger, text: "oracle-liveness failure path" },
  ]);
  return finish(ctx, {
    title: "raffle.fun at a glance",
    desc: "A sponsor escrows one NFT, buyers receive bearer tickets, one Pyth Entropy request resolves the raffle, and claimants redeem assets. Liveness failure leads to exact bearer refunds.",
    height: H,
  });
})();

/* ------------------------------------- 02 participant role map --------- */

figures["02-participant-role-map.svg"] = (() => {
  const ctx = makeCtx("f02");
  const H = 486;
  const cw = 210;
  const ch = 82;
  const roles = [
    {
      x: 26,
      y: 34,
      t: "Sponsor",
      b: "Deposits the prize; fixes price, threshold, dates, recovery recipient",
      icon: "gem",
      accent: pal.pink,
    },
    {
      x: 255,
      y: 34,
      t: "Buyer / ticket holder",
      b: "Pays USDC; owns a transferable bearer claim until it burns",
      icon: "ticket",
      accent: pal.skyDeep,
    },
    {
      x: 484,
      y: 34,
      t: "Draw requester",
      b: "Anyone; pays the current Pyth fee to start the draw",
      icon: "dice",
      accent: pal.violet,
    },
    {
      x: 26,
      y: 196,
      t: "Factory owner",
      b: "Future creation pause and future treasury only",
      icon: "key",
      accent: pal.indigo,
    },
    {
      x: 484,
      y: 196,
      t: "Pyth Entropy",
      b: "External randomness; delivers the authenticated callback",
      icon: "bolt",
      accent: pal.violet,
    },
    {
      x: 26,
      y: 358,
      t: "Recovery recipient",
      b: "Fixed at creation; claims the NFT in cash, refund, or empty outcomes",
      icon: "wallet",
      accent: pal.yellow,
    },
    {
      x: 255,
      y: 358,
      t: "Protocol treasury",
      b: "Receives the fee as a pull claim on successful settlement",
      icon: "coin",
      accent: pal.green,
    },
    {
      x: 484,
      y: 358,
      t: "Read layer",
      b: "Lens, SDK, subgraph, frontend; helpful but never authoritative",
      icon: "eye",
      accent: pal.slate,
    },
  ];
  // Hub.
  const hub = { x: 262, y: 187, w: 196, h: 100 };
  // Spokes first (under cards).
  const hubCx = hub.x + hub.w / 2;
  const hubCy = hub.y + hub.h / 2;
  for (const r of roles) {
    const cx = r.x + cw / 2;
    const cy = r.y + ch / 2;
    const dashed = r.t === "Read layer" || r.t === "Pyth Entropy";
    put(
      ctx,
      `<line x1="${cx}" y1="${cy}" x2="${hubCx}" y2="${hubCy}" stroke="${pal.lineStrong}" stroke-width="1.6"${dashed ? ' stroke-dasharray="5 4"' : ""}/>`,
    );
  }
  put(
    ctx,
    `<rect x="${hub.x}" y="${hub.y}" width="${hub.w}" height="${hub.h}" rx="16" fill="${pal.indigo}" stroke="${pal.indigoDeep}" stroke-width="2"/>`,
  );
  put(ctx, icon("cube", hubCx - 11, hub.y + 14, 22, pal.white));
  put(
    ctx,
    txt(hubCx, hub.y + 56, "Raffle contract", {
      size: 14.5,
      weight: 800,
      color: pal.white,
      anchor: "middle",
      family: F_DISP,
    }),
  );
  put(
    ctx,
    txt(hubCx, hub.y + 74, "fixed rules · no owner · no operator", {
      size: 10,
      weight: 550,
      color: "#c9d1ff",
      anchor: "middle",
    }),
  );
  for (const r of roles) {
    rowCard(ctx, {
      x: r.x,
      y: r.y,
      w: cw,
      h: ch,
      title: r.t,
      body: r.b,
      accent: r.accent,
      iconName: r.icon,
    });
  }
  legend(ctx, H, [
    { swatch: "solid", color: pal.lineStrong, text: "holds a contract permission" },
    { swatch: "dashed", color: pal.lineStrong, text: "external service or read-only" },
  ]);
  return finish(ctx, {
    title: "Participant role map",
    desc: "Eight separate roles surround one raffle contract. One address may hold several roles, but each permission is defined separately.",
    height: H,
  });
})();

/* -------------------------------------- 03 atomic creation ------------- */

figures["03-atomic-creation.svg"] = (() => {
  const ctx = makeCtx("f03");
  const H = 330;
  // Transaction envelope.
  const env = { x: 26, y: 56, w: 548, h: 196 };
  put(
    ctx,
    `<rect x="${env.x}" y="${env.y}" width="${env.w}" height="${env.h}" rx="16" fill="${pal.sunk}" stroke="${pal.indigo}" stroke-width="1.6" stroke-dasharray="7 5"/>`,
  );
  const capsule = pill(ctx, {
    x: env.x + 18,
    y: env.y - 11,
    text: "one transaction · createRaffle()",
    size: 10.5,
    weight: 750,
    fg: pal.indigo,
    bg: pal.white,
    stroke: pal.indigo,
    mono: false,
  });
  put(ctx, capsule.svg);
  const steps = [
    { t: "Validate", b: "terms, dates, addresses", icon: "doc" },
    { t: "Deploy", b: "constructor CREATE", icon: "factory" },
    { t: "Register", b: "ID + canonical address", icon: "cube" },
    { t: "Deposit", b: "safe NFT transfer in", icon: "gem" },
    { t: "Verify", b: "ownerOf == raffle", icon: "shield" },
  ];
  const cw2 = 97;
  const gap = (env.w - 36 - cw2 * 5) / 4;
  steps.forEach((s, i) => {
    const x = env.x + 18 + i * (cw2 + gap);
    card(ctx, {
      x,
      y: env.y + 26,
      w: cw2,
      h: 96,
      title: s.t,
      body: s.b,
      accent: pal.indigo,
      fill: pal.white,
      iconName: s.icon,
      num: i + 1,
      titleSize: 11.5,
      bodySize: 9.3,
    });
    if (i < 4)
      put(
        ctx,
        arrow(ctx, x + cw2 + 1.5, env.y + 74, x + cw2 + gap - 2, env.y + 74, {
          color: pal.indigo,
          width: 2,
        }),
      );
  });
  // Rollback ribbon inside the envelope.
  const rbY = env.y + 152;
  put(
    ctx,
    elbow(
      ctx,
      [
        [env.x + 500, env.y + 122 + 4],
        [env.x + 500, rbY],
        [env.x + 46, rbY],
      ],
      { color: pal.danger, width: 1.8, dashed: true },
    ),
  );
  put(ctx, icon("undo", env.x + 54, rbY + 6, 16, pal.danger));
  put(
    ctx,
    txt(
      env.x + 76,
      rbY + 18,
      "any failure reverts every step: deployment, registry, event, NFT",
      { size: 10, weight: 650, color: pal.danger },
    ),
  );
  // Result card.
  put(
    ctx,
    arrow(ctx, env.x + env.w + 2, env.y + 98, 610, env.y + 98, {
      color: pal.green,
      width: 2.4,
    }),
  );
  card(ctx, {
    x: 612,
    y: env.y + 40,
    w: 84,
    h: 116,
    title: "Active",
    body: "prize escrowed, sale live",
    accent: pal.green,
    fill: pal.greenWash,
    iconName: "shield",
    titleSize: 12.5,
    bodySize: 9.5,
  });
  put(
    ctx,
    txt(
      26,
      292,
      "There is no partially created raffle: registration, escrow, and verification are one atomic unit.",
      { size: 10.5, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Atomic creation and prize escrow",
    desc: "The factory validates, deploys, registers, deposits, and verifies in one transaction; any failure rolls back every step.",
    height: H,
  });
})();

/* ----------------------------------------- 04 lifecycle state machine -- */

figures["04-lifecycle.svg"] = (() => {
  const ctx = makeCtx("f04");
  const H = 420;
  const nw = 160;
  const nh = 58;
  const row1Y = 64;
  const row2Y = 250;
  const nodes = {
    awaiting: { x: 28, y: row1Y, t: "AwaitingPrize", sub: "inside creation tx", accent: pal.ink4, dashed: true, fill: pal.white },
    active: { x: 240, y: row1Y, t: "Active", sub: "sale + request grace", accent: pal.skyDeep, fill: pal.skyWash },
    drawing: { x: 452, y: row1Y, t: "Drawing", sub: "one sequence pending", accent: pal.violet, fill: pal.violetWash },
    closed: { x: 24, y: row2Y, t: "Closed", sub: "zero sales", accent: pal.slate, fill: pal.slateWash, terminal: true },
    refunding: { x: 198, y: row2Y, t: "Refunding", sub: "exact bearer refunds", accent: pal.danger, fill: pal.dangerWash, terminal: true },
    cashwon: { x: 372, y: row2Y, t: "CashWon", sub: "cash winner", accent: pal.pink, fill: pal.pinkWash, terminal: true },
    nftwon: { x: 546, y: row2Y, t: "NftWon", sub: "NFT winner", accent: pal.green, fill: pal.greenWash, terminal: true },
  };
  const nodeW = (n) => (n === nodes.closed || n === nodes.refunding || n === nodes.cashwon || n === nodes.nftwon ? 150 : nw);
  // Edges beneath nodes.
  const e = (svg) => put(ctx, svg);
  // AwaitingPrize -> Active
  e(
    arrow(ctx, nodes.awaiting.x + nw + 2, row1Y + nh / 2, nodes.active.x - 4, row1Y + nh / 2, {
      color: pal.ink3,
      width: 2,
    }),
  );
  e(
    txt((nodes.awaiting.x + nw + nodes.active.x) / 2, row1Y - 10, "deposit verified", {
      size: 9.3,
      weight: 650,
      color: pal.ink3,
      anchor: "middle",
    }),
  );
  // Active -> Drawing
  e(
    arrow(ctx, nodes.active.x + nw + 2, row1Y + nh / 2, nodes.drawing.x - 4, row1Y + nh / 2, {
      color: pal.ink3,
      width: 2,
    }),
  );
  e(
    txt((nodes.active.x + nw + nodes.drawing.x) / 2, row1Y - 10, "requestDraw", {
      size: 9.3,
      weight: 650,
      color: pal.ink3,
      anchor: "middle",
    }),
  );
  // Active -> Closed
  e(
    elbow(
      ctx,
      [
        [nodes.active.x + 26, row1Y + nh],
        [nodes.active.x + 26, row1Y + nh + 62],
        [nodes.closed.x + 75, row1Y + nh + 62],
        [nodes.closed.x + 75, row2Y - 4],
      ],
      { color: pal.slate, width: 1.8 },
    ),
  );
  e(
    txt(nodes.closed.x + 84, row1Y + nh + 57, "0 sold · closeEmptyRaffle", {
      size: 9.5,
      weight: 650,
      color: pal.slate,
    }),
  );
  // Active -> Refunding (straight vertical drop).
  e(
    arrow(ctx, nodes.active.x + 60, row1Y + nh + 2, nodes.active.x + 60, row2Y - 4, {
      color: pal.danger,
      width: 1.8,
    }),
  );
  e(
    txt(nodes.active.x + 52, row2Y - 30, `no request · ${C.requestGraceDays}d`, {
      size: 9.5,
      weight: 650,
      color: pal.danger,
      anchor: "end",
    }),
  );
  // Drawing -> Refunding
  e(
    elbow(
      ctx,
      [
        [nodes.drawing.x + 22, row1Y + nh],
        [nodes.drawing.x + 22, row2Y - 50],
        [nodes.refunding.x + 118, row2Y - 50],
        [nodes.refunding.x + 118, row2Y - 4],
      ],
      { color: pal.danger, width: 1.8 },
    ),
  );
  e(
    txt(388, row2Y - 56, `no callback · ${C.callbackTimeoutDays}d`, {
      size: 9.5,
      weight: 650,
      color: pal.danger,
      anchor: "middle",
    }),
  );
  // Drawing -> CashWon
  e(
    elbow(
      ctx,
      [
        [nodes.drawing.x + 80, row1Y + nh],
        [nodes.drawing.x + 80, row2Y - 78],
        [nodes.cashwon.x + 75, row2Y - 78],
        [nodes.cashwon.x + 75, row2Y - 4],
      ],
      { color: pal.pink, width: 1.8 },
    ),
  );
  e(
    txt(406, row2Y - 84, "threshold missed", {
      size: 9.5,
      weight: 650,
      color: pal.pink,
      anchor: "middle",
    }),
  );
  // Drawing -> NftWon
  e(
    elbow(
      ctx,
      [
        [nodes.drawing.x + 128, row1Y + nh],
        [nodes.drawing.x + 128, row2Y - 104],
        [nodes.nftwon.x + 75, row2Y - 104],
        [nodes.nftwon.x + 75, row2Y - 4],
      ],
      { color: pal.green, width: 1.8 },
    ),
  );
  e(
    txt(694, row2Y - 110, "threshold met", {
      size: 9.5,
      weight: 650,
      color: pal.greenDeep,
      anchor: "end",
    }),
  );
  e(
    txt(694, row1Y - 10, "callback settles the draw", {
      size: 9.3,
      weight: 650,
      color: pal.ink3,
      anchor: "end",
    }),
  );
  // Nodes on top.
  for (const n of Object.values(nodes)) {
    const w = nodeW(n);
    const dash = n.dashed ? ' stroke-dasharray="5 4"' : "";
    put(
      ctx,
      `<rect x="${n.x}" y="${n.y}" width="${w}" height="${nh}" rx="14" fill="${n.fill}" stroke="${n.accent}" stroke-width="1.8"${dash}/>`,
    );
    if (n.terminal) {
      put(
        ctx,
        `<rect x="${n.x + 3.5}" y="${n.y + 3.5}" width="${w - 7}" height="${nh - 7}" rx="10.5" fill="none" stroke="${n.accent}" stroke-width="1" opacity="0.55"/>`,
      );
    }
    put(
      ctx,
      txt(n.x + w / 2, n.y + 25, n.t, {
        size: 13,
        weight: 800,
        anchor: "middle",
        mono: true,
        color: pal.ink,
      }),
    );
    put(
      ctx,
      txt(n.x + w / 2, n.y + 42, n.sub, {
        size: 9.3,
        weight: 550,
        anchor: "middle",
        color: pal.ink3,
      }),
    );
  }
  put(
    ctx,
    txt(
      26,
      row2Y + nh + 34,
      "Terminal states are absorbing: redemptions and claims change balances, never the status.",
      { size: 10.5, weight: 550, color: pal.ink3 },
    ),
  );
  legend(ctx, H, [
    { swatch: "dashed", color: pal.ink4, text: "transient (never observable between transactions)" },
    { swatch: pal.greenWash, text: "double border = terminal" },
  ]);
  return finish(ctx, {
    title: "Complete raffle lifecycle",
    desc: "The seven status values and every allowed forward transition, from AwaitingPrize through Active and Drawing to the four terminal outcomes.",
    height: H,
  });
})();

/* ------------------------------------ 05 sale and deadline timeline ---- */

figures["05-sale-deadline-timeline.svg"] = (() => {
  const ctx = makeCtx("f05");
  const H = 330;
  const axisY = 150;
  const x0 = 44;
  const x1 = 688;
  // Segment boundaries.
  const tCreate = 58;
  const tStart = 180;
  const tEnd = 428;
  const tGrace = 588;
  const bands = [
    {
      a: tCreate,
      b: tStart,
      fill: pal.slateWash,
      label: "pre-sale wait",
      sub: `up to ${C.maxStartDelayDays} days`,
      color: pal.ink3,
    },
    {
      a: tStart,
      b: tEnd,
      fill: pal.skyWash,
      label: "ticket sale",
      sub: `at most ${C.maxSaleDurationDays} days`,
      color: pal.skyDeep,
    },
    {
      a: tEnd,
      b: tGrace,
      fill: pal.violetWash,
      label: "request window",
      sub: `${C.requestGraceDays} days · deadline excluded`,
      color: pal.violet,
    },
  ];
  for (const band of bands) {
    put(
      ctx,
      `<rect x="${band.a}" y="${axisY - 30}" width="${band.b - band.a}" height="60" rx="10" fill="${band.fill}"/>`,
    );
    put(
      ctx,
      txt((band.a + band.b) / 2, axisY - 8, band.label, {
        size: 11.5,
        weight: 750,
        color: band.color,
        anchor: "middle",
      }),
    );
    put(
      ctx,
      txt((band.a + band.b) / 2, axisY + 10, band.sub, {
        size: 9.3,
        weight: 550,
        color: pal.ink3,
        anchor: "middle",
      }),
    );
  }
  put(
    ctx,
    arrow(ctx, x0 - 6, axisY + 44, x1, axisY + 44, { color: pal.ink4, width: 1.6 }),
  );
  put(ctx, txt(x1 - 2, axisY + 60, "time", { size: 9, weight: 600, color: pal.ink4, anchor: "end" }));
  // Tick markers.
  const ticks = [
    { x: tCreate, top: "creation", bottom: "", color: pal.ink3 },
    { x: tStart, top: "startTime", bottom: "inclusive: buying opens exactly here", color: pal.skyDeep },
    { x: tEnd, top: "endTime", bottom: "exclusive: no purchase here", color: pal.violet },
    { x: tGrace, top: `endTime + ${C.requestGraceDays}d`, bottom: "request-grace deadline", color: pal.danger },
  ];
  for (const t of ticks) {
    put(
      ctx,
      `<line x1="${t.x}" y1="${axisY - 42}" x2="${t.x}" y2="${axisY + 44}" stroke="${t.color}" stroke-width="1.6"${t.x === tGrace ? ' stroke-dasharray="4 3"' : ""}/>`,
    );
    put(
      ctx,
      `<circle cx="${t.x}" cy="${axisY + 44}" r="3.4" fill="${t.color}"/>`,
    );
    put(
      ctx,
      txt(t.x, axisY - 50, t.top, {
        size: 10.5,
        weight: 750,
        color: t.color,
        anchor: "middle",
        mono: t.top.includes("Time") || t.top.includes("+"),
      }),
    );
    if (t.bottom)
      put(
        ctx,
        txt(t.x, axisY + 62, t.bottom, {
          size: 8.8,
          weight: 550,
          color: pal.ink3,
          anchor: "middle",
        }),
      );
  }
  // Callback lane anchored at an example request moment.
  const reqX = 470;
  const cbEnd = reqX + 150;
  const laneY = axisY + 96;
  put(
    ctx,
    `<line x1="${reqX}" y1="${axisY + 66}" x2="${reqX}" y2="${laneY - 8}" stroke="${pal.violet}" stroke-width="1.4" stroke-dasharray="3.5 3"/>`,
  );
  put(ctx, `<circle cx="${reqX}" cy="${axisY + 44}" r="3.4" fill="${pal.violet}"/>`);
  put(
    ctx,
    `<rect x="${reqX}" y="${laneY - 8}" width="${cbEnd - reqX}" height="26" rx="9" fill="${pal.yellowWash}" stroke="${pal.yellow}" stroke-width="1.2"/>`,
  );
  put(
    ctx,
    txt(reqX + (cbEnd - reqX) / 2, laneY + 9, `callback wait · ${C.callbackTimeoutDays} days`, {
      size: 9.5,
      weight: 700,
      color: pal.amberInk,
      anchor: "middle",
    }),
  );
  put(
    ctx,
    txt(reqX - 8, laneY + 9, "requestDraw accepted", {
      size: 9.3,
      weight: 650,
      color: pal.violet,
      anchor: "end",
    }),
  );
  put(
    ctx,
    `<line x1="${cbEnd}" y1="${laneY - 14}" x2="${cbEnd}" y2="${laneY + 24}" stroke="${pal.danger}" stroke-width="1.6" stroke-dasharray="4 3"/>`,
  );
  put(
    ctx,
    txt(694, laneY + 36, "at timeout, refunds become enabled", {
      size: 9.3,
      weight: 700,
      color: pal.danger,
      anchor: "end",
    }),
  );
  put(
    ctx,
    txt(
      26,
      H - 32,
      "At either red deadline, enableRefunds becomes valid for anyone. At the exact callback boundary, the callback and the",
      { size: 9.8, weight: 550, color: pal.ink3 },
    ),
  );
  put(
    ctx,
    txt(26, H - 18, "timeout transaction may race; the first one included in a block wins.", {
      size: 9.8,
      weight: 550,
      color: pal.ink3,
    }),
  );
  return finish(ctx, {
    title: "Sale and deadline timeline",
    desc: "The inclusive sale start and exclusive sale end are followed by a strict request window and an exact callback timeout measured from the accepted request.",
    height: H,
  });
})();

/* ----------------------------------- 06 bearer ticket through time ----- */

figures["06-ticket-ownership.svg"] = (() => {
  const ctx = makeCtx("f06");
  const H = 350;
  // Phase bands.
  const bands = [
    { a: 26, b: 300, t: "Active", fill: pal.skyWash, color: pal.skyDeep },
    { a: 308, b: 486, t: "Drawing", fill: pal.violetWash, color: pal.violet },
    { a: 494, b: 694, t: "terminal status", fill: pal.greenWash, color: pal.greenDeep },
  ];
  for (const b of bands) {
    put(
      ctx,
      `<rect x="${b.a}" y="40" width="${b.b - b.a}" height="216" rx="14" fill="${b.fill}"/>`,
    );
    put(ctx, tag(b.a + 14, 62, b.t, b.color));
  }
  // People.
  const people = [
    { x: 96, y: 130, name: "Maya", note: "buys ticket #12" },
    { x: 240, y: 190, name: "Leo", note: "receives it" },
    { x: 400, y: 130, name: "Noor", note: "receives it mid-draw" },
  ];
  const r = 21;
  const avatarFills = [pal.skyDeep, pal.indigo, pal.violet];
  people.forEach((p, i) => {
    put(
      ctx,
      `<circle cx="${p.x}" cy="${p.y}" r="${r}" fill="${pal.white}" stroke="${avatarFills[i]}" stroke-width="1.8"/>`,
    );
    put(ctx, icon("user", p.x - 10, p.y - 10, 20, avatarFills[i]));
    put(
      ctx,
      txt(p.x, p.y + r + 15, p.name, {
        size: 11,
        weight: 750,
        anchor: "middle",
        color: pal.ink,
      }),
    );
    put(
      ctx,
      txt(p.x, p.y + r + 29, p.note, {
        size: 9,
        weight: 550,
        anchor: "middle",
        color: pal.ink3,
      }),
    );
  });
  // Burn node.
  const burn = { x: 590, y: 150 };
  put(
    ctx,
    `<circle cx="${burn.x}" cy="${burn.y}" r="${r + 2}" fill="${pal.white}" stroke="${pal.green}" stroke-width="2"/>`,
  );
  put(ctx, icon("flame", burn.x - 10, burn.y - 11, 21, pal.green));
  put(
    ctx,
    txt(burn.x, burn.y + r + 17, "current owner burns", {
      size: 10,
      weight: 750,
      anchor: "middle",
      color: pal.greenDeep,
    }),
  );
  put(
    ctx,
    txt(burn.x, burn.y + r + 31, "collects award or refund", {
      size: 9,
      weight: 550,
      anchor: "middle",
      color: pal.ink3,
    }),
  );
  // Transfers.
  const t1 = arrow(ctx, people[0].x + r + 4, people[0].y + 10, people[1].x - r - 5, people[1].y - 8, {
    color: pal.ink3,
    width: 2,
    label: "transfer",
    labelSize: 9.3,
    labelDy: -8,
    labelDx: -4,
  });
  const t2 = arrow(ctx, people[1].x + r + 4, people[1].y - 8, people[2].x - r - 5, people[2].y + 10, {
    color: pal.ink3,
    width: 2,
    label: "transfer",
    labelSize: 9.3,
    labelDy: 22,
    labelDx: 0,
  });
  const t3 = arrow(ctx, people[2].x + r + 5, people[2].y + 6, burn.x - r - 6, burn.y - 2, {
    color: pal.green,
    width: 2.2,
    label: "burn to redeem",
    labelSize: 9.3,
    labelDy: -8,
  });
  put(ctx, t1);
  put(ctx, t2);
  put(ctx, t3);
  // Ticket chip following the path.
  const chip = pill(ctx, {
    x: 96 - 34,
    y: 74,
    text: "ticket #12 · bearer right",
    size: 9.5,
    weight: 700,
    fg: pal.skyDeep,
    bg: pal.white,
    stroke: pal.skyDeep,
  });
  put(ctx, chip.svg);
  put(
    ctx,
    txt(
      26,
      H - 54,
      "Tickets never freeze: transfers stay open in every status until the moment a ticket burns. Whoever owns the",
      { size: 10.3, weight: 550, color: pal.ink3 },
    ),
  );
  put(
    ctx,
    txt(
      26,
      H - 40,
      "unburned ticket at redemption time collects; approvals allow transfers, never redemptions.",
      { size: 10.3, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Bearer ticket ownership through time",
    desc: "Ticket 12 moves from Maya to Leo to Noor across sale, drawing, and terminal phases; the current owner at burn time collects the award or refund.",
    height: H,
  });
})();

/* --------------------------------- 07 randomness sequence diagram ------ */

figures["07-randomness-sequence.svg"] = (() => {
  const ctx = makeCtx("f07");
  const H = 470;
  const lanes = [
    { x: 120, t: "Requester", sub: "anyone", accent: pal.skyDeep },
    { x: 360, t: "Raffle", sub: "contract", accent: pal.indigo },
    { x: 600, t: "Pyth Entropy v2", sub: "external", accent: pal.violet },
  ];
  const headY = 24;
  const headH = 44;
  const footY = H - 58;
  for (const lane of lanes) {
    put(
      ctx,
      `<line x1="${lane.x}" y1="${headY + headH}" x2="${lane.x}" y2="${footY}" stroke="${pal.lineStrong}" stroke-width="1.4" stroke-dasharray="3.5 3.5"/>`,
    );
    put(
      ctx,
      `<rect x="${lane.x - 78}" y="${headY}" width="156" height="${headH}" rx="11" fill="${pal.white}" stroke="${lane.accent}" stroke-width="1.6"/>`,
    );
    put(
      ctx,
      txt(lane.x, headY + 19, lane.t, {
        size: 12,
        weight: 780,
        anchor: "middle",
        color: pal.ink,
      }),
    );
    put(
      ctx,
      txt(lane.x, headY + 34, lane.sub, {
        size: 9,
        weight: 550,
        anchor: "middle",
        color: pal.ink3,
      }),
    );
  }
  const act = (x, y1, y2, color) =>
    put(
      ctx,
      `<rect x="${x - 5}" y="${y1}" width="10" height="${y2 - y1}" rx="4" fill="${color}" opacity="0.16" stroke="${color}" stroke-width="1.1"/>`,
    );
  act(120, 96, 120, pal.skyDeep);
  act(360, 96, 268, pal.indigo);
  act(600, 176, 232, pal.violet);
  act(600, 330, 356, pal.violet);
  act(360, 330, 406, pal.indigo);
  const msg = (x1, x2, y, label, o = {}) => {
    put(
      ctx,
      arrow(ctx, x1 + (x1 < x2 ? 6 : -6), y, x2 + (x1 < x2 ? -8 : 8), y, {
        color: o.color || pal.ink2,
        width: 2,
        dashed: o.dashed,
      }),
    );
    put(
      ctx,
      txt((x1 + x2) / 2, y - 8, label, {
        size: 10,
        weight: 700,
        anchor: "middle",
        color: o.color || pal.ink2,
        mono: o.mono,
      }),
    );
  };
  const selfNote = (x, y, w, textStr, color = pal.indigo) => {
    const lines = wrapW(textStr, w - 18, 9.3, 550);
    const h = 14 + lines.length * 12.6;
    put(
      ctx,
      `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="8" fill="${pal.sunk}" stroke="${pal.line}" stroke-width="1"/>`,
    );
    put(
      ctx,
      linesTxt(x + 9, y + 14.5, lines, 12.6, {
        size: 9.3,
        weight: 550,
        color: pal.ink2,
      }),
    );
  };
  msg(120, 360, 104, "requestDraw() + native Pyth fee", { color: pal.skyDeep });
  selfNote(374, 118, 210, "checks: Active · tickets sold · sale ended · inside request grace · sets in-flight guard");
  msg(360, 600, 184, "requestV2(callbackGasLimit) · exact fee", { color: pal.indigo });
  msg(600, 360, 222, "sequenceNumber", { color: pal.violet, dashed: true, mono: true });
  selfNote(374, 236, 196, "stores the sequence · status = Drawing · clears guard");
  // Transaction separator.
  const sepY = 296;
  put(
    ctx,
    `<line x1="30" y1="${sepY}" x2="${W - 30}" y2="${sepY}" stroke="${pal.ink4}" stroke-width="1.2" stroke-dasharray="7 5"/>`,
  );
  const sep = pill(ctx, {
    x: W / 2,
    y: sepY - 11,
    text: "later · a separate transaction",
    size: 9.5,
    weight: 700,
    fg: pal.ink3,
    bg: pal.paper,
    stroke: pal.ink4,
    anchor: "middle",
  });
  put(ctx, sep.svg);
  msg(600, 360, 338, "entropyCallback(sequence, randomNumber)", { color: pal.violet });
  selfNote(374, 352, 254, "authenticates wrapper + stored sequence, selects the winner, records fee and liabilities, sets terminal status");
  put(
    ctx,
    txt(
      26,
      footY + 24,
      "Wrong-sequence, duplicate, stale, in-flight, or post-refund callbacks emit CallbackIgnored and change nothing.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  legend(ctx, H, [
    { swatch: "solid", color: pal.ink2, text: "call" },
    { swatch: "dashed", color: pal.violet, text: "return value" },
    { swatch: pal.slateWash, text: "contract-internal step" },
  ]);
  return finish(ctx, {
    title: "Randomness request and callback sequence",
    desc: "A requester pays Pyth through the raffle, the raffle stores one sequence number, and a later authenticated callback settles the raffle in a separate transaction.",
    height: H,
  });
})();

/* -------------------------------------------- 08 winner selection ------ */

figures["08-winner-selection.svg"] = (() => {
  const ctx = makeCtx("f08");
  const H = 312;
  const y = 56;
  const boxH = 64;
  // Pipeline.
  const stops = [
    { x: 26, w: 172, title: "randomNumber", sub: "authenticated uint256", mono: true, accent: pal.violet, fill: pal.violetWash },
    { x: 240, w: 160, title: "mod totalTickets", sub: "uniform 0 .. N-1", mono: true, accent: pal.indigo, fill: pal.white },
    { x: 442, w: 64, title: "+ 1", sub: "", mono: true, accent: pal.indigo, fill: pal.white },
    { x: 548, w: 146, title: "winning ID", sub: "1 .. N inclusive", accent: pal.green, fill: pal.greenWash },
  ];
  for (const s of stops) {
    put(
      ctx,
      `<rect x="${s.x}" y="${y}" width="${s.w}" height="${boxH}" rx="12" fill="${s.fill}" stroke="${s.accent}" stroke-width="1.6"/>`,
    );
    put(
      ctx,
      txt(s.x + s.w / 2, y + (s.sub ? 28 : 38), s.title, {
        size: 12.5,
        weight: 760,
        anchor: "middle",
        mono: s.mono,
        color: pal.ink,
      }),
    );
    if (s.sub)
      put(
        ctx,
        txt(s.x + s.w / 2, y + 46, s.sub, {
          size: 9.3,
          weight: 550,
          anchor: "middle",
          color: pal.ink3,
        }),
      );
  }
  put(ctx, arrow(ctx, 200, y + boxH / 2, 236, y + boxH / 2, { color: pal.ink3, width: 2.2 }));
  put(ctx, arrow(ctx, 402, y + boxH / 2, 438, y + boxH / 2, { color: pal.ink3, width: 2.2 }));
  put(ctx, arrow(ctx, 508, y + boxH / 2, 544, y + boxH / 2, { color: pal.ink3, width: 2.2 }));
  // Ticket strip.
  const stripY = 178;
  const cells = ["1", "2", "3", "···", "41", "42", "43", "···", "118", "119", "120"];
  const winnerIdx = 5;
  const cellW = 52;
  const gap = 6;
  const stripW = cells.length * cellW + (cells.length - 1) * gap;
  const x0 = (W - stripW) / 2;
  put(
    ctx,
    txt(x0, stripY - 14, "every sold ticket 1 .. totalTickets · nothing excluded, nothing weighted", {
      size: 9.5,
      weight: 650,
      color: pal.ink3,
    }),
  );
  cells.forEach((c, i) => {
    const x = x0 + i * (cellW + gap);
    const isWin = i === winnerIdx;
    const isGap = c.includes("·");
    put(
      ctx,
      `<rect x="${x}" y="${stripY}" width="${cellW}" height="50" rx="9" fill="${isWin ? pal.green : isGap ? pal.paper : pal.white}" stroke="${isWin ? pal.greenDeep : pal.line}" stroke-width="${isWin ? 2 : 1.2}"/>`,
    );
    if (isWin) {
      put(ctx, icon("trophy", x + cellW / 2 - 8, stripY + 7, 16, pal.white));
      put(
        ctx,
        txt(x + cellW / 2, stripY + 40, `#${c}`, {
          size: 11.5,
          weight: 800,
          anchor: "middle",
          color: pal.white,
          mono: true,
        }),
      );
    } else {
      put(
        ctx,
        txt(x + cellW / 2, stripY + 30, c, {
          size: 11,
          weight: 650,
          anchor: "middle",
          color: isGap ? pal.ink4 : pal.ink2,
          mono: true,
        }),
      );
    }
  });
  put(
    ctx,
    txt(
      26,
      H - 32,
      "One sold ticket always selects #1; the final ticket is reachable. Residual modulo bias is astronomically small",
      { size: 9.8, weight: 550, color: pal.ink3 },
    ),
  );
  put(
    ctx,
    txt(26, H - 18, "for realistic ticket counts against a 256-bit value, but it is not exactly zero.", {
      size: 9.8,
      weight: 550,
      color: pal.ink3,
    }),
  );
  return finish(ctx, {
    title: "Winner selection",
    desc: "The authenticated 256-bit random value is reduced modulo the sold ticket count and shifted by one, selecting a winning ID in the complete range.",
    height: H,
  });
})();

/* ---------------------------------------- 09 outcome comparison -------- */

figures["09-outcome-comparison.svg"] = (() => {
  const ctx = makeCtx("f09");
  const H = 448;
  const cols = [
    {
      key: "NftWon",
      sub: "threshold met",
      accent: pal.green,
      fill: pal.greenWash,
      icon: "trophy",
      fee: `${C.protocolFeePercent} of gross`,
      winner: "one ticket wins the NFT",
      nft: "winning bearer",
      usdc: "sponsor, post-fee",
    },
    {
      key: "CashWon",
      sub: "threshold missed",
      accent: pal.pink,
      fill: pal.pinkWash,
      icon: "coin",
      fee: `${C.protocolFeePercent} of gross`,
      winner: `one ticket wins ${C.cashWinnerPercent} of the post-fee pot`,
      nft: "recovery recipient",
      usdc: `winner ${C.cashWinnerPercent} · sponsor the rest`,
    },
    {
      key: "Refunding",
      sub: "draw never resolved",
      accent: pal.danger,
      fill: pal.dangerWash,
      icon: "undo",
      fee: "no fee",
      winner: "no winner selected",
      nft: "recovery recipient",
      usdc: "exact refunds to burning owners",
    },
    {
      key: "Closed",
      sub: "zero tickets sold",
      accent: pal.slate,
      fill: pal.slateWash,
      icon: "pause",
      fee: "no fee",
      winner: "no winner exists",
      nft: "recovery recipient",
      usdc: "no pot exists",
    },
  ];
  const labelW = 96;
  const colW = 138;
  const gap = 8;
  const x0 = 26;
  const headY = 34;
  const headH = 66;
  const rows = [
    { key: "fee", label: "protocol fee" },
    { key: "winner", label: "winner" },
    { key: "nft", label: "prize NFT to" },
    { key: "usdc", label: "USDC to" },
  ];
  const rowH = 66;
  const rowGap = 8;
  cols.forEach((c, i) => {
    const x = x0 + labelW + 10 + i * (colW + gap);
    put(
      ctx,
      `<rect x="${x}" y="${headY}" width="${colW}" height="${headH}" rx="12" fill="${c.fill}" stroke="${c.accent}" stroke-width="1.6"/>`,
    );
    put(ctx, icon(c.icon, x + 12, headY + 12, 18, c.accent));
    put(
      ctx,
      txt(x + 38, headY + 26, c.key, {
        size: 12.5,
        weight: 800,
        mono: true,
        color: pal.ink,
      }),
    );
    put(
      ctx,
      txt(x + 12, headY + 50, c.sub, {
        size: 9.3,
        weight: 650,
        color: c.accent === pal.slate ? pal.ink3 : c.accent,
      }),
    );
    rows.forEach((r, j) => {
      const y = headY + headH + 10 + j * (rowH + rowGap);
      put(
        ctx,
        `<rect x="${x}" y="${y}" width="${colW}" height="${rowH}" rx="10" fill="${pal.white}" stroke="${pal.line}" stroke-width="1.1"/>`,
      );
      const lines = wrapW(c[r.key], colW - 20, 9.8, 600);
      for (const line of lines)
        assertFits(ctx, line, estW(line, 9.8, 600), colW - 18, "matrix cell");
      const startY = y + rowH / 2 - ((lines.length - 1) * 13) / 2 + 3.5;
      put(
        ctx,
        linesTxt(x + colW / 2, startY, lines, 13, {
          size: 9.8,
          weight: 600,
          color: pal.ink2,
          anchor: "middle",
        }),
      );
    });
  });
  rows.forEach((r, j) => {
    const y = headY + headH + 10 + j * (rowH + rowGap);
    put(ctx, tag(x0, y + rowH / 2 + 3, r.label, pal.ink3, "start", 8.6));
  });
  put(
    ctx,
    txt(
      26,
      H - 22,
      "Success is defined by randomness delivery, not by the threshold: the threshold only decides NFT versus cash.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Outcome comparison",
    desc: "The four terminal outcomes compared by protocol fee, winner, prize NFT destination, and USDC destination.",
    height: H,
  });
})();

/* --------------------------------------- 10 NFT-awarded money flow ----- */

function moneyDestCard(ctx, o) {
  const { x, y, w, h, title, amount, sub, accent, iconName } = o;
  put(
    ctx,
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="12" fill="${pal.white}" stroke="${pal.line}" stroke-width="1.2"/>`,
  );
  put(ctx, `<rect x="${x}" y="${y}" width="4.5" height="${h}" rx="2.25" fill="${accent}"/>`);
  put(ctx, icon(iconName, x + 14, y + 12, 18, accent));
  put(ctx, txt(x + 40, y + 26, title, { size: 11.5, weight: 760, color: pal.ink }));
  put(
    ctx,
    txt(x + w - 12, y + 27, amount, {
      size: 13,
      weight: 800,
      color: pal.ink,
      anchor: "end",
      mono: true,
    }),
  );
  const lines = wrapW(sub, w - 26, 9.3, 550);
  put(
    ctx,
    linesTxt(x + 14, y + 45, lines, 12.4, { size: 9.3, weight: 550, color: pal.ink3 }),
  );
}

figures["10-nft-awarded-flow.svg"] = (() => {
  const ctx = makeCtx("f10");
  const H = 356;
  const srcX = 96;
  const barW = 30;
  const potY = 62;
  const potH = 150;
  // Source: USDC pot.
  put(
    ctx,
    `<rect x="${srcX}" y="${potY}" width="${barW}" height="${potH}" rx="7" fill="${pal.sky}" opacity="0.9"/>`,
  );
  put(ctx, tag(26, potY - 16, "sources", pal.ink3));
  put(
    ctx,
    linesTxt(srcX - 10, potY + 18, ["Gross sales", `${E.thresholdMet.gross}`, `${E.thresholdMet.tickets} tickets`, `x ${E.thresholdMet.ticketPrice}`], 15, {
      size: 10.2,
      weight: 650,
      color: pal.ink2,
      anchor: "end",
    }),
  );
  // Prize NFT source.
  const nftY = 246;
  put(
    ctx,
    `<rect x="${srcX}" y="${nftY}" width="${barW}" height="34" rx="7" fill="${pal.pink}" opacity="0.9"/>`,
  );
  put(
    ctx,
    linesTxt(srcX - 10, nftY + 12, ["Escrowed", "prize NFT"], 13, {
      size: 10.2,
      weight: 650,
      color: pal.ink2,
      anchor: "end",
    }),
  );
  // Destinations.
  const dx = 452;
  const dw = 242;
  moneyDestCard(ctx, {
    x: dx,
    y: 46,
    w: dw,
    h: 62,
    title: "Protocol treasury",
    amount: E.thresholdMet.fee,
    sub: `${C.protocolFeePercent} fee · recorded as a pull claim`,
    accent: pal.indigo,
    iconName: "factory",
  });
  moneyDestCard(ctx, {
    x: dx,
    y: 128,
    w: dw,
    h: 62,
    title: "Sponsor",
    amount: E.thresholdMet.distributable,
    sub: "post-fee proceeds · pull claim",
    accent: pal.yellow,
    iconName: "wallet",
  });
  moneyDestCard(ctx, {
    x: dx,
    y: 232,
    w: dw,
    h: 62,
    title: "Winning bearer",
    amount: "the NFT",
    sub: "burns the winning ticket to collect",
    accent: pal.green,
    iconName: "trophy",
  });
  // Ribbons: pot split proportional to 60 / 1140.
  const feeH = Math.max(12, (potH * 60) / 1200);
  put(ctx, ribbon(srcX + barW, potY, potY + feeH, dx, 62, 62 + 14, pal.indigo, 0.3));
  put(
    ctx,
    ribbon(srcX + barW, potY + feeH, potY + potH, dx, 138, 138 + 44, "#f2c94c", 0.42),
  );
  put(ctx, ribbon(srcX + barW, nftY, nftY + 34, dx, 246, 246 + 34, pal.pink, 0.32));
  put(
    ctx,
    txt(280, 100, `fee ${E.thresholdMet.fee}`, { size: 9.8, weight: 700, color: pal.indigo }),
  );
  put(
    ctx,
    txt(280, 176, `sponsor ${E.thresholdMet.distributable}`, {
      size: 9.8,
      weight: 700,
      color: pal.amberInk,
    }),
  );
  put(
    ctx,
    txt(280, 258, "prize to the winner", { size: 9.8, weight: 700, color: pal.pink }),
  );
  put(
    ctx,
    txt(
      26,
      H - 26,
      "Band heights are proportional to USDC amounts. Every USDC payout is a pull claim; nothing is pushed automatically.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "NFT-awarded money flow",
    desc: "With 120 tickets sold at 10.00 USDC, the treasury records the fee, the sponsor records post-fee proceeds, and the winning bearer burns the ticket for the NFT.",
    height: H,
  });
})();

/* -------------------------------------- 11 cash-fallback money flow ---- */

figures["11-cash-fallback-flow.svg"] = (() => {
  const ctx = makeCtx("f11");
  const H = 420;
  const srcX = 96;
  const barW = 30;
  const potY = 64;
  const potH = 160; // 800 USDC
  const unit = potH / 800;
  put(ctx, tag(26, potY - 16, "sources", pal.ink3));
  put(
    ctx,
    `<rect x="${srcX}" y="${potY}" width="${barW}" height="${potH}" rx="7" fill="${pal.sky}" opacity="0.9"/>`,
  );
  put(
    ctx,
    linesTxt(srcX - 10, potY + 18, ["Gross sales", `${E.cashFallback.gross}`, `${E.cashFallback.tickets} tickets`, `x ${E.cashFallback.ticketPrice}`], 15, {
      size: 10.2,
      weight: 650,
      color: pal.ink2,
      anchor: "end",
    }),
  );
  const nftY = 268;
  put(
    ctx,
    `<rect x="${srcX}" y="${nftY}" width="${barW}" height="34" rx="7" fill="${pal.pink}" opacity="0.9"/>`,
  );
  put(
    ctx,
    linesTxt(srcX - 10, nftY + 12, ["Escrowed", "prize NFT"], 13, {
      size: 10.2,
      weight: 650,
      color: pal.ink2,
      anchor: "end",
    }),
  );
  // Intermediate bar: post-fee pot.
  const midX = 322;
  const midY = potY + 40;
  const midH = 760 * unit;
  put(
    ctx,
    `<rect x="${midX}" y="${midY}" width="${barW}" height="${midH}" rx="7" fill="${pal.skyDeep}" opacity="0.85"/>`,
  );
  put(
    ctx,
    linesTxt(midX - 6, midY + midH + 18, [`post-fee pot ${E.cashFallback.distributable}`], 13, {
      size: 9.8,
      weight: 700,
      color: pal.skyDeep,
    }),
  );
  // Destinations.
  const dx = 452;
  const dw = 242;
  moneyDestCard(ctx, {
    x: dx,
    y: 40,
    w: dw,
    h: 58,
    title: "Protocol treasury",
    amount: E.cashFallback.fee,
    sub: `${C.protocolFeePercent} fee · pull claim`,
    accent: pal.indigo,
    iconName: "factory",
  });
  moneyDestCard(ctx, {
    x: dx,
    y: 118,
    w: dw,
    h: 62,
    title: "Cash winner",
    amount: E.cashFallback.winnerCash,
    sub: `${C.cashWinnerPercent} of the post-fee pot · burns the winning ticket`,
    accent: pal.green,
    iconName: "trophy",
  });
  moneyDestCard(ctx, {
    x: dx,
    y: 202,
    w: dw,
    h: 58,
    title: "Sponsor",
    amount: E.cashFallback.sponsorCash,
    sub: "remaining pot · pull claim",
    accent: pal.yellow,
    iconName: "wallet",
  });
  moneyDestCard(ctx, {
    x: dx,
    y: 284,
    w: dw,
    h: 58,
    title: "Recovery recipient",
    amount: "the NFT",
    sub: "fixed at creation · claims the prize",
    accent: pal.pink,
    iconName: "gem",
  });
  // Ribbons: gross -> fee (top) and gross -> post-fee pot.
  const feeH = Math.max(11, 40 * unit);
  put(ctx, ribbon(srcX + barW, potY, potY + feeH, dx, 54, 54 + 13, pal.indigo, 0.3));
  put(
    ctx,
    ribbon(srcX + barW, potY + feeH, potY + potH, midX, midY, midY + midH, pal.sky, 0.35),
  );
  // Post-fee pot -> winner and sponsor.
  const winH = 608 * unit;
  put(ctx, ribbon(midX + barW, midY, midY + winH, dx, 128, 128 + 44, pal.green, 0.3));
  put(
    ctx,
    ribbon(midX + barW, midY + winH, midY + midH, dx, 212, 212 + 38, "#f2c94c", 0.42),
  );
  put(ctx, ribbon(srcX + barW, nftY, nftY + 34, dx, 292, 292 + 34, pal.pink, 0.3));
  put(ctx, txt(238, 96, `fee ${E.cashFallback.fee}`, { size: 9.8, weight: 700, color: pal.indigo }));
  put(
    ctx,
    txt(388, 136, `winner ${E.cashFallback.winnerCash}`, {
      size: 9.8,
      weight: 700,
      color: pal.greenDeep,
    }),
  );
  put(
    ctx,
    txt(388, 232, `sponsor ${E.cashFallback.sponsorCash}`, {
      size: 9.8,
      weight: 700,
      color: pal.amberInk,
    }),
  );
  put(
    ctx,
    txt(240, 300, "prize leaves the raffle", { size: 9.8, weight: 700, color: pal.pink }),
  );
  put(
    ctx,
    txt(
      26,
      H - 26,
      `${C.cashWinnerPercent} applies to the post-fee pot of ${E.cashFallback.distributable} USDC, not to gross sales. No general refunds exist in this branch.`,
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Cash-fallback money flow",
    desc: "With 80 tickets sold, successful randomness yields a cash winner: the fee comes off gross, the winner takes 80% of the post-fee pot, and the recovery recipient claims the NFT.",
    height: H,
  });
})();

/* ----------------------------------- 12 missing-request refund flow ---- */

figures["12-missing-request-refund.svg"] = (() => {
  const ctx = makeCtx("f12");
  const H = 356;
  // Mini timeline.
  const axisY = 66;
  put(
    ctx,
    `<rect x="26" y="${axisY - 16}" width="250" height="32" rx="9" fill="${pal.skyWash}"/>`,
  );
  put(
    ctx,
    txt(151, axisY + 4, "sale ended · 80 tickets · 800.00 USDC", {
      size: 9.8,
      weight: 700,
      color: pal.skyDeep,
      anchor: "middle",
    }),
  );
  put(
    ctx,
    `<rect x="284" y="${axisY - 16}" width="230" height="32" rx="9" fill="${pal.violetWash}"/>`,
  );
  put(
    ctx,
    txt(399, axisY + 4, `request grace · ${C.requestGraceDays} days · nobody requests`, {
      size: 9.8,
      weight: 700,
      color: pal.violet,
      anchor: "middle",
    }),
  );
  put(
    ctx,
    `<line x1="522" y1="${axisY - 22}" x2="522" y2="${axisY + 22}" stroke="${pal.danger}" stroke-width="1.8" stroke-dasharray="4 3"/>`,
  );
  put(
    ctx,
    txt(534, axisY - 2, "deadline passes:", { size: 9.8, weight: 750, color: pal.danger }),
  );
  put(
    ctx,
    txt(534, axisY + 11, "no draw can ever start", { size: 9.4, weight: 550, color: pal.ink3 }),
  );
  // Flow.
  const y = 130;
  const cards = [
    {
      t: "enableRefunds",
      b: "anyone calls; no admin needed",
      accent: pal.indigo,
      icon: "bell",
      mono: true,
    },
    {
      t: "Pot becomes liability",
      b: "800.00 reserved for refunds",
      accent: pal.skyDeep,
      icon: "coin",
    },
    {
      t: "Owners burn tickets",
      b: `exactly ${E.failedDraw.refundPerTicket} per ticket`,
      accent: pal.green,
      icon: "flame",
    },
  ];
  const cw = 200;
  const gap = (W - 52 - cw * 3) / 2;
  cards.forEach((c, i) => {
    const x = 26 + i * (cw + gap);
    card(ctx, {
      x,
      y,
      w: cw,
      h: 96,
      title: c.t,
      body: c.b,
      accent: c.accent,
      fill: pal.white,
      iconName: c.icon,
      titleSize: 12,
      bodySize: 10,
    });
    if (i < 2)
      put(
        ctx,
        arrow(ctx, x + cw + 2, y + 48, x + cw + gap - 3, y + 48, {
          color: pal.ink3,
          width: 2.2,
        }),
      );
  });
  put(
    ctx,
    elbow(
      ctx,
      [
        [522, axisY + 22],
        [522, y - 22],
        [126, y - 22],
        [126, y - 3],
      ],
      { color: pal.danger, width: 1.8, dashed: true },
    ),
  );
  // NFT side strip.
  const stripY = 258;
  put(
    ctx,
    `<rect x="26" y="${stripY}" width="668" height="46" rx="11" fill="${pal.pinkWash}" stroke="${pal.pink}" stroke-width="1.2"/>`,
  );
  put(ctx, icon("gem", 42, stripY + 13, 19, pal.pink));
  put(
    ctx,
    txt(
      70,
      stripY + 28,
      "The prize NFT was never won: the fixed recovery recipient claims it. No fee, no sponsor proceeds, no winner.",
      { size: 10.3, weight: 600, color: pal.ink2 },
    ),
  );
  put(
    ctx,
    txt(
      26,
      H - 26,
      "Refunds are bearer rights: whoever owns a ticket when refunds are enabled can burn it, whenever they choose.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Missing-request refund flow",
    desc: "If no draw request is accepted before the grace deadline, anyone enables refunds, the pot becomes refund liability, and each owner burns tickets for the exact price.",
    height: H,
  });
})();

/* ------------------------------------------ 13 callback vs timeout ---- */

figures["13-timeout-refund.svg"] = (() => {
  const ctx = makeCtx("f13");
  const H = 360;
  // Deadline header.
  put(ctx, icon("clock", 26, 34, 20, pal.amberInk));
  put(
    ctx,
    txt(54, 49, `the exact moment drawRequestedAt + ${C.callbackTimeoutDays} days arrives`, {
      size: 12,
      weight: 750,
      color: pal.ink,
    }),
  );
  put(
    ctx,
    txt(54, 66, "two different transactions are simultaneously valid in the mempool", {
      size: 10,
      weight: 550,
      color: pal.ink3,
    }),
  );
  // Contenders.
  const contW = 216;
  card(ctx, {
    x: 26,
    y: 96,
    w: contW,
    h: 84,
    title: "entropyCallback",
    body: "Pyth delivers the random value",
    accent: pal.violet,
    fill: pal.violetWash,
    iconName: "bolt",
    titleSize: 12,
    bodySize: 10,
  });
  card(ctx, {
    x: 26,
    y: 208,
    w: contW,
    h: 84,
    title: "enableRefunds",
    body: "anyone finalizes the timeout",
    accent: pal.danger,
    fill: pal.dangerWash,
    iconName: "undo",
    titleSize: 12,
    bodySize: 10,
  });
  // Gate.
  const gate = { x: 322, y: 148, w: 156, h: 92 };
  put(
    ctx,
    `<rect x="${gate.x}" y="${gate.y}" width="${gate.w}" height="${gate.h}" rx="14" fill="${pal.sunk}" stroke="${pal.indigo}" stroke-width="1.7"/>`,
  );
  put(ctx, icon("cube", gate.x + gate.w / 2 - 10, gate.y + 12, 20, pal.indigo));
  put(
    ctx,
    txt(gate.x + gate.w / 2, gate.y + 52, "Base block", {
      size: 12,
      weight: 780,
      anchor: "middle",
      color: pal.ink,
    }),
  );
  put(
    ctx,
    txt(gate.x + gate.w / 2, gate.y + 68, "first included wins", {
      size: 9.6,
      weight: 600,
      anchor: "middle",
      color: pal.ink3,
    }),
  );
  put(ctx, curve(ctx, 26 + contW + 3, 138, gate.x - 4, 176, { color: pal.violet, width: 2.2 }));
  put(ctx, curve(ctx, 26 + contW + 3, 250, gate.x - 4, 212, { color: pal.danger, width: 2.2 }));
  // Outcomes.
  const outX = 540;
  card(ctx, {
    x: outX,
    y: 92,
    w: 154,
    h: 92,
    title: "Draw settles",
    body: "NftWon or CashWon; late timeout reverts",
    accent: pal.green,
    fill: pal.greenWash,
    iconName: "trophy",
    titleSize: 11.5,
    bodySize: 9.5,
  });
  card(ctx, {
    x: outX,
    y: 204,
    w: 154,
    h: 92,
    title: "Refunding",
    body: "late callback emits CallbackIgnored",
    accent: pal.danger,
    fill: pal.dangerWash,
    iconName: "flame",
    titleSize: 11.5,
    bodySize: 9.5,
  });
  put(ctx, curve(ctx, gate.x + gate.w + 3, 176, outX - 5, 138, { color: pal.green, width: 2.2 }));
  put(ctx, curve(ctx, gate.x + gate.w + 3, 212, outX - 5, 250, { color: pal.danger, width: 2.2 }));
  put(
    ctx,
    txt(
      26,
      H - 40,
      "Both orderings are safe: each terminal transition is valid when executed, and the loser is rejected by status checks.",
      { size: 10.3, weight: 550, color: pal.ink3 },
    ),
  );
  put(
    ctx,
    txt(26, H - 25, "Ticket holders keep exactly one right either way: the winning award or the exact refund.", {
      size: 10.3,
      weight: 550,
      color: pal.ink3,
    }),
  );
  return finish(ctx, {
    title: "Callback versus timeout race",
    desc: "At the callback deadline the oracle callback and the refund finalization can race; block inclusion decides which terminal transition executes and the other is safely rejected.",
    height: H,
  });
})();

/* ------------------------------------------ 14 refund redemption ------- */

figures["14-refund-redemption.svg"] = (() => {
  const ctx = makeCtx("f14");
  const H = 344;
  const steps = [
    { t: "Choose tickets", b: `1 to ${K.MAX_REFUND_REDEMPTION_BATCH_SIZE} owned IDs`, icon: "ticket", accent: pal.skyDeep },
    { t: "Validate", b: "Refunding status; caller owns every unique ID", icon: "shield", accent: pal.indigo },
    { t: "Burn", b: "bearer rights are consumed", icon: "flame", accent: pal.pink },
    { t: "Reduce liability", b: "price x quantity comes off the books", icon: "doc", accent: pal.yellow },
    { t: "Exact transfer", b: "USDC to any chosen destination", icon: "coin", accent: pal.green },
  ];
  const cw = 124;
  const gap = (W - 52 - cw * 5) / 4;
  const y = 44;
  const h = 126;
  steps.forEach((s, i) => {
    const x = 26 + i * (cw + gap);
    card(ctx, {
      x,
      y,
      w: cw,
      h,
      title: s.t,
      body: s.b,
      accent: s.accent,
      fill: pal.white,
      iconName: s.icon,
      num: i + 1,
      titleSize: 11.8,
      bodySize: 9.6,
    });
    if (i < 4)
      put(
        ctx,
        arrow(ctx, x + cw + 2, y + h / 2, x + cw + gap - 3, y + h / 2, {
          color: pal.ink3,
          width: 2.2,
        }),
      );
  });
  // Revert loop.
  const loopY = 214;
  put(
    ctx,
    elbow(
      ctx,
      [
        [26 + 4 * (cw + gap) + cw / 2, y + h + 2],
        [26 + 4 * (cw + gap) + cw / 2, loopY + 24],
        [26 + cw / 2 + 12, loopY + 24],
        [26 + cw / 2 + 12, y + h + 6],
      ],
      { color: pal.danger, width: 1.8, dashed: true },
    ),
  );
  put(
    ctx,
    `<rect x="196" y="${loopY}" width="330" height="48" rx="11" fill="${pal.dangerWash}" stroke="${pal.danger}" stroke-width="1.2"/>`,
  );
  put(ctx, icon("undo", 210, loopY + 14, 18, pal.danger));
  put(
    ctx,
    txt(236, loopY + 21, "any invalid ID or failed USDC transfer", {
      size: 10.3,
      weight: 750,
      color: pal.danger,
    }),
  );
  put(
    ctx,
    txt(236, loopY + 36, "reverts the whole batch: burns and liability restored", {
      size: 9.8,
      weight: 550,
      color: pal.ink2,
    }),
  );
  put(
    ctx,
    txt(
      26,
      H - 44,
      "Refunds are bounded bearer burns, not a batch payout to a frozen snapshot: each owner redeems on their own",
      { size: 10.3, weight: 550, color: pal.ink3 },
    ),
  );
  put(
    ctx,
    txt(26, H - 30, "schedule, and an unredeemed ticket simply remains a live claim.", {
      size: 10.3,
      weight: 550,
      color: pal.ink3,
    }),
  );
  return finish(ctx, {
    title: "Refund redemption sequence",
    desc: "A current owner chooses up to 100 tickets, the contract validates and burns them, reduces the refund liability, and transfers exact USDC; any failure reverts the whole batch.",
    height: H,
  });
})();

/* ----------------------------------- 15 claims and redemptions --------- */

figures["15-pull-claim-architecture.svg"] = (() => {
  const ctx = makeCtx("f15");
  const H = 460;
  const items = [
    {
      sig: "claimQuote(to)",
      who: "sponsor / treasury",
      rule: "claimant chooses any nonzero destination",
      accent: pal.indigo,
      icon: "wallet",
    },
    {
      sig: "claimQuoteFor(account)",
      who: "anyone",
      rule: "helper pays the claim only to the account itself",
      accent: pal.skyDeep,
      icon: "user",
    },
    {
      sig: "redeemWinningTicket(to)",
      who: "winning-ticket owner",
      rule: "burns the ticket; NFT or cash to a chosen destination",
      accent: pal.green,
      icon: "trophy",
    },
    {
      sig: "redeemRefundTickets(ids,to)",
      who: "ticket owner",
      rule: `burns up to ${K.MAX_REFUND_REDEMPTION_BATCH_SIZE} tickets for exact refunds`,
      accent: pal.pink,
      icon: "flame",
    },
    {
      sig: "claimSponsorPrize(to)",
      who: "recovery recipient",
      rule: "safe-transfers the NFT after cash, refund, or empty outcomes",
      accent: pal.yellow,
      icon: "gem",
    },
    {
      sig: "recoverProtocolOwnedClaim()",
      who: "anyone",
      rule: "sweeps only expired protocol-owned claims to the treasury",
      accent: pal.slate,
      icon: "clock",
    },
  ];
  const colW = 326;
  const rowH = 104;
  const gapX = 16;
  const gapY = 14;
  items.forEach((it, i) => {
    const x = 26 + (i % 2) * (colW + gapX);
    const y = 36 + Math.floor(i / 2) * (rowH + gapY);
    put(
      ctx,
      `<rect x="${x}" y="${y}" width="${colW}" height="${rowH}" rx="13" fill="${pal.white}" stroke="${pal.line}" stroke-width="1.2"/>`,
    );
    put(ctx, `<rect x="${x}" y="${y}" width="${colW}" height="30" rx="13" fill="${it.accent}" opacity="0.1"/>`);
    put(ctx, `<rect x="${x}" y="${y + 15}" width="${colW}" height="15" fill="${it.accent}" opacity="0.1"/>`);
    put(ctx, icon(it.icon, x + 12, y + 6, 17, it.accent));
    put(
      ctx,
      txt(x + 36, y + 20, it.sig, { size: 11.3, weight: 700, mono: true, color: pal.ink }),
    );
    const whoPill = pill(ctx, {
      x: x + 12,
      y: y + 42,
      text: it.who,
      size: 9.3,
      weight: 750,
      fg: it.accent === pal.yellow ? pal.amberInk : it.accent,
      bg: pal.paper,
      stroke: it.accent,
      h: 20,
    });
    put(ctx, whoPill.svg);
    const lines = wrapW(it.rule, colW - 26, 10, 550);
    put(
      ctx,
      linesTxt(x + 13, y + 80, lines, 13.5, { size: 10, weight: 550, color: pal.ink2 }),
    );
  });
  const stripY = 36 + 3 * (rowH + gapY) + 4;
  put(
    ctx,
    `<rect x="26" y="${stripY}" width="668" height="44" rx="11" fill="${pal.greenWash}" stroke="${pal.green}" stroke-width="1.2"/>`,
  );
  put(ctx, icon("shield", 42, stripY + 12, 19, pal.greenDeep));
  put(
    ctx,
    txt(
      70,
      stripY + 27,
      "A failed transfer reverts the call: ticket, claim, liability, and prize state are preserved for retry.",
      { size: 10.5, weight: 650, color: pal.greenDeep },
    ),
  );
  return finish(ctx, {
    title: "Claims and bearer redemptions",
    desc: "The six asset-moving entry points, each with its own claimant and destination rule; failed transfers revert without consuming any right.",
    height: H,
  });
})();

/* -------------------------------------- 16 contract architecture ------- */

figures["16-contract-architecture.svg"] = (() => {
  const ctx = makeCtx("f16");
  const H = 500;
  // Factory.
  const fac = { x: 210, y: 30, w: 300, h: 78 };
  put(
    ctx,
    `<rect x="${fac.x}" y="${fac.y}" width="${fac.w}" height="${fac.h}" rx="14" fill="${pal.indigo}"/>`,
  );
  put(ctx, icon("factory", fac.x + 16, fac.y + 14, 20, pal.white));
  put(
    ctx,
    txt(fac.x + 44, fac.y + 29, "RaffleFactory", {
      size: 13.5,
      weight: 800,
      color: pal.white,
      family: F_DISP,
    }),
  );
  put(
    ctx,
    txt(fac.x + 16, fac.y + 50, "immutable: USDC · Entropy · callback gas limit", {
      size: 9.4,
      weight: 550,
      color: "#c9d1ff",
    }),
  );
  put(
    ctx,
    txt(fac.x + 16, fac.y + 64, "registry · owner sets future policy only", {
      size: 9.4,
      weight: 550,
      color: "#c9d1ff",
    }),
  );
  // Raffle instances.
  const rafY = 168;
  const rafH = 104;
  const rafDefs = [
    { x: 40, w: 176, main: false },
    { x: 262, w: 196, main: true },
    { x: 504, w: 176, main: false },
  ];
  rafDefs.forEach((rd, i) => {
    put(
      ctx,
      `<rect x="${rd.x}" y="${rafY}" width="${rd.w}" height="${rafH}" rx="13" fill="${rd.main ? pal.pinkWash : pal.white}" stroke="${pal.pink}" stroke-width="${rd.main ? 1.8 : 1.3}"/>`,
    );
    put(ctx, icon("cube", rd.x + 12, rafY + 10, 17, pal.pink));
    put(
      ctx,
      txt(rd.x + 34, rafY + 24, `Raffle #${i + 1}`, {
        size: 12,
        weight: 780,
        color: pal.ink,
      }),
    );
    if (rd.main) {
      put(
        ctx,
        linesTxt(
          rd.x + 13,
          rafY + 46,
          ["own storage and prize escrow", "own deadlines and liabilities", "no owner · no upgrade path"],
          15,
          { size: 9.6, weight: 550, color: pal.ink2 },
        ),
      );
    } else {
      put(
        ctx,
        linesTxt(rd.x + 13, rafY + 46, ["independent instance;", "one compromised raffle", "cannot touch another"], 15, {
          size: 9.6,
          weight: 550,
          color: pal.ink3,
        }),
      );
    }
    put(
      ctx,
      arrow(ctx, fac.x + 60 + i * 90, fac.y + fac.h + 2, rd.x + rd.w / 2, rafY - 4, {
        color: pal.indigo,
        width: 1.9,
      }),
    );
  });
  put(
    ctx,
    `<rect x="230" y="128" width="260" height="17" rx="8" fill="${pal.paper}" opacity="0.94"/>`,
  );
  put(
    ctx,
    txt(360, 140, "constructor CREATE · no proxies, no clones", {
      size: 9.6,
      weight: 700,
      color: pal.indigo,
      anchor: "middle",
    }),
  );
  // Bottom row: Pyth, Lens, tokens.
  const botY = 322;
  const botH = 74;
  put(
    ctx,
    `<rect x="28" y="${botY}" width="200" height="${botH}" rx="12" fill="${pal.violetWash}" stroke="${pal.violet}" stroke-width="1.5"/>`,
  );
  put(ctx, icon("bolt", 42, botY + 12, 18, pal.violet));
  put(ctx, txt(68, botY + 26, "Pyth Entropy v2", { size: 11.5, weight: 780, color: pal.ink }));
  put(
    ctx,
    linesTxt(42, botY + 46, ["dynamic fee · sequence numbers", "authenticated callbacks"], 13.5, {
      size: 9.3,
      weight: 550,
      color: pal.ink3,
    }),
  );
  put(
    ctx,
    `<rect x="260" y="${botY}" width="200" height="${botH}" rx="12" fill="${pal.white}" stroke="${pal.skyDeep}" stroke-width="1.5"/>`,
  );
  put(ctx, icon("eye", 274, botY + 12, 18, pal.skyDeep));
  put(ctx, txt(300, botY + 26, "RaffleLens", { size: 11.5, weight: 780, color: pal.ink }));
  put(
    ctx,
    linesTxt(274, botY + 46, [`read-only · batches up to ${facts.architecture.lensBatchSize}`, "authenticates registered raffles"], 13.5, {
      size: 9.3,
      weight: 550,
      color: pal.ink3,
    }),
  );
  put(
    ctx,
    `<rect x="492" y="${botY}" width="200" height="${botH}" rx="12" fill="${pal.white}" stroke="${pal.yellow}" stroke-width="1.5" stroke-dasharray="6 4"/>`,
  );
  put(ctx, icon("coin", 506, botY + 12, 18, pal.yellow));
  put(ctx, txt(532, botY + 26, "USDC + prize NFTs", { size: 11.5, weight: 780, color: pal.ink }));
  put(
    ctx,
    linesTxt(506, botY + 46, ["external token contracts;", "issuer behavior stays a dependency"], 13.5, {
      size: 9.3,
      weight: 550,
      color: pal.ink3,
    }),
  );
  // Connectors bottom row to raffles.
  put(ctx, arrow(ctx, 128, botY - 4, 262 + 30, rafY + rafH + 3, { color: pal.violet, width: 1.8, head: true }));
  put(
    ctx,
    txt(150, botY - 22, "request / callback", { size: 9.2, weight: 650, color: pal.violet }),
  );
  put(ctx, arrow(ctx, 360, botY - 4, 360, rafY + rafH + 4, { color: pal.skyDeep, width: 1.8, dashed: true }));
  put(ctx, txt(372, botY - 22, "reads", { size: 9.2, weight: 650, color: pal.skyDeep }));
  put(ctx, arrow(ctx, 592, botY - 4, 458 + 2, rafY + rafH + 3, { color: pal.yellow, width: 1.8, dashed: true }));
  put(
    ctx,
    txt(560, botY - 22, "balances / ownership", { size: 9.2, weight: 650, color: pal.amberInk, anchor: "middle" }),
  );
  // Offchain boundary.
  const boundY = 424;
  put(
    ctx,
    `<line x1="26" y1="${boundY}" x2="${W - 26}" y2="${boundY}" stroke="${pal.ink4}" stroke-width="1.3" stroke-dasharray="8 5"/>`,
  );
  put(
    ctx,
    txt(W - 26, boundY - 8, "settlement authority ends here", {
      size: 9,
      weight: 700,
      color: pal.ink4,
      anchor: "end",
    }),
  );
  let chipX = 26;
  for (const label of ["SDK simulates writes", "subgraph indexes events", "web app presents", "notifications remind"]) {
    const p = pill(ctx, {
      x: chipX,
      y: boundY + 14,
      text: label,
      size: 9.5,
      weight: 650,
      fg: pal.ink3,
      bg: pal.white,
      stroke: pal.line,
      h: 22,
    });
    put(ctx, p.svg);
    chipX += p.w + 10;
  }
  put(
    ctx,
    txt(chipX + 8, boundY + 29, "none can settle or override", {
      size: 9.5,
      weight: 650,
      color: pal.ink4,
    }),
  );
  return finish(ctx, {
    title: "Contract architecture",
    desc: "One factory constructor-deploys independent raffles; the Lens reads, Pyth and token contracts remain external, and offchain layers have no settlement authority.",
    height: H,
  });
})();

/* --------------------------------------- 17 onchain vs offchain -------- */

figures["17-onchain-offchain.svg"] = (() => {
  const ctx = makeCtx("f17");
  const H = 452;
  const bands = [
    {
      t: "Onchain authority",
      sub: "the raffle contracts decide",
      accent: pal.indigo,
      fill: pal.skyWash,
      chips: ["status", "prize escrow", "ticket owners", "deadlines", "winner", "liabilities", "claims"],
      solid: true,
    },
    {
      t: "Access layer",
      sub: "helps users see and act",
      accent: pal.skyDeep,
      fill: pal.white,
      chips: ["web app", "wallet", "RPC", "SDK", "subgraph", "notifications"],
    },
    {
      t: "External services",
      sub: "independent operators",
      accent: pal.violet,
      fill: pal.white,
      chips: ["Pyth provider + keeper", "Base sequencer", "USDC issuer", "prize NFT issuer"],
    },
    {
      t: "External meaning",
      sub: "outside any contract",
      accent: pal.pink,
      fill: pal.white,
      chips: ["metadata + IP", "gambling law", "tax", "sanctions", "age rules"],
    },
  ];
  const bandH = 76;
  const gapY = 14;
  const boundaryGap = 24;
  let y = 34;
  bands.forEach((b, i) => {
    put(
      ctx,
      `<rect x="26" y="${y}" width="668" height="${bandH}" rx="13" fill="${b.fill}" stroke="${b.accent}" stroke-width="${b.solid ? 1.8 : 1.2}"/>`,
    );
    put(ctx, txt(44, y + 26, b.t, { size: 12.5, weight: 800, color: b.accent, family: F_DISP }));
    put(ctx, txt(44, y + 42, b.sub, { size: 9.3, weight: 550, color: pal.ink3 }));
    // Chips flow with wrapping inside the band.
    const chipX0 = 232;
    const chipMax = 680;
    const rows = [];
    let row = [];
    let cx = chipX0;
    for (const chipText of b.chips) {
      const w = estW(chipText, 9.6, 650) + 24;
      if (cx + w > chipMax && row.length) {
        rows.push(row);
        row = [];
        cx = chipX0;
      }
      row.push({ text: chipText, w });
      cx += w + 8;
    }
    if (row.length) rows.push(row);
    const rowsH = rows.length * 24 + (rows.length - 1) * 7;
    let ry = y + bandH / 2 - rowsH / 2;
    for (const rw of rows) {
      let cxx = chipX0;
      for (const c of rw) {
        const p = pill(ctx, {
          x: cxx,
          y: ry,
          text: c.text,
          size: 9.6,
          weight: 650,
          fg: pal.ink2,
          bg: b.solid ? pal.white : pal.sunk,
          stroke: b.solid ? b.accent : pal.line,
          h: 24,
          padX: 12,
        });
        put(ctx, p.svg);
        cxx += c.w + 8;
      }
      ry += 31;
    }
    if (i === 0) {
      const by = y + bandH + boundaryGap / 2 + 7;
      put(
        ctx,
        `<line x1="26" y1="${by}" x2="694" y2="${by}" stroke="${pal.danger}" stroke-width="1.6" stroke-dasharray="8 5"/>`,
      );
      put(
        ctx,
        `<rect x="120" y="${by - 9}" width="480" height="18" rx="9" fill="${pal.paper}"/>`,
      );
      put(
        ctx,
        txt(360, by + 4, "authority boundary · nothing below this line can settle assets or change raffle state", {
          size: 9.3,
          weight: 750,
          color: pal.danger,
          anchor: "middle",
        }),
      );
      y += boundaryGap;
    }
    y += bandH + gapY;
  });
  put(
    ctx,
    txt(
      26,
      H - 24,
      "Layers below the boundary can censor their own service, present stale data, or disappear; they cannot move assets.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Onchain versus offchain",
    desc: "Settlement state lives in the contracts; access layers, external services, and legal meaning sit below the authority boundary and cannot settle assets.",
    height: H,
  });
})();

/* -------------------------------------------- 18 owner matrix ---------- */

figures["18-owner-matrix.svg"] = (() => {
  const ctx = makeCtx("f18");
  const H = 430;
  const colW = 326;
  const canItems = [
    "pause or resume future raffle creation",
    "set the treasury captured by future raffles",
    "transfer ownership with a two-step handshake",
  ];
  const cannotItems = [
    "change any existing raffle's price, dates, or threshold",
    "pause, upgrade, settle, or rescue a deployed raffle",
    "move the escrowed prize or the USDC pot",
    "choose, reroll, or veto a winner",
    "redirect anyone's claim or refund",
  ];
  const drawCol = (x, title, accent, wash, items, iconName) => {
    const headH = 40;
    put(
      ctx,
      `<rect x="${x}" y="36" width="${colW}" height="${headH}" rx="12" fill="${accent}"/>`,
    );
    put(ctx, icon(iconName, x + 14, 46, 20, pal.white));
    put(
      ctx,
      txt(x + 44, 62, title, { size: 13, weight: 800, color: pal.white, family: F_DISP }),
    );
    let y = 88;
    for (const item of items) {
      const lines = wrapW(item, colW - 62, 10.3, 600);
      const h = Math.max(40, 18 + lines.length * 14);
      put(
        ctx,
        `<rect x="${x}" y="${y}" width="${colW}" height="${h}" rx="10" fill="${wash}" stroke="${accent}" stroke-width="1" opacity="0.95"/>`,
      );
      put(ctx, icon(iconName === "check" ? "check" : "cross", x + 14, y + h / 2 - 9, 18, accent));
      put(
        ctx,
        linesTxt(x + 42, y + h / 2 - ((lines.length - 1) * 14) / 2 + 3.8, lines, 14, {
          size: 10.3,
          weight: 600,
          color: pal.ink2,
        }),
      );
      y += h + 8;
    }
    return y;
  };
  drawCol(26, "The factory owner can", pal.green, pal.greenWash, canItems, "check");
  drawCol(368, "The owner cannot", pal.danger, pal.dangerWash, cannotItems, "cross");
  const stripY = 348;
  put(
    ctx,
    `<rect x="26" y="${stripY}" width="668" height="48" rx="11" fill="${pal.skyWash}" stroke="${pal.indigo}" stroke-width="1.2"/>`,
  );
  put(ctx, icon("bell", 42, stripY + 14, 19, pal.indigo));
  put(
    ctx,
    txt(70, stripY + 21, "Incident response without an admin key:", {
      size: 10.5,
      weight: 750,
      color: pal.indigo,
    }),
  );
  put(
    ctx,
    txt(70, stripY + 37, "warn users · hide writes in the frontend · pause new creation · deploy a reviewed replacement factory", {
      size: 10,
      weight: 550,
      color: pal.ink2,
    }),
  );
  put(
    ctx,
    txt(26, H - 16, "Every deployed raffle runs to completion under its original fixed rules.", {
      size: 10,
      weight: 550,
      color: pal.ink3,
    }),
  );
  return finish(ctx, {
    title: "Factory owner: can and cannot",
    desc: "Factory ownership only shapes future creation policy; it grants no emergency control over any deployed raffle.",
    height: H,
  });
})();

/* ---------------------------------------- 19 recovery envelope --------- */

figures["19-recovery-envelope.svg"] = (() => {
  const ctx = makeCtx("f19");
  const H = 412;
  // Envelope region.
  const env = { x: 26, y: 40, w: 420, h: 290 };
  put(
    ctx,
    `<rect x="${env.x}" y="${env.y}" width="${env.w}" height="${env.h}" rx="18" fill="${pal.greenWash}" stroke="${pal.greenDeep}" stroke-width="1.8" stroke-dasharray="9 6"/>`,
  );
  put(ctx, icon("shield", env.x + 16, env.y + 14, 20, pal.greenDeep));
  put(
    ctx,
    txt(env.x + 44, env.y + 29, "Inside the supported envelope", {
      size: 13,
      weight: 800,
      color: pal.greenDeep,
      family: F_DISP,
    }),
  );
  put(
    ctx,
    txt(env.x + 16, env.y + 52, "every asset has exactly one bounded exit path", {
      size: 9.8,
      weight: 600,
      color: pal.ink2,
    }),
  );
  // Assumption chips.
  put(ctx, tag(env.x + 16, env.y + 80, "assumptions", pal.greenDeep));
  const assumptions = ["honest ERC-721 ownership + safe transfer", "exact-transfer, non-rebasing USDC", "Base includes transactions"];
  let ay = env.y + 92;
  for (const a of assumptions) {
    const p = pill(ctx, {
      x: env.x + 16,
      y: ay,
      text: a,
      size: 9.6,
      weight: 650,
      fg: pal.greenDeep,
      bg: pal.white,
      stroke: pal.green,
      h: 23,
    });
    put(ctx, p.svg);
    ay += 29;
  }
  // Path cards.
  put(ctx, tag(env.x + 16, ay + 18, "bounded exit paths", pal.greenDeep));
  const paths = [
    ["winner burn", "trophy"],
    ["refund burns", "flame"],
    ["quote pull claims", "coin"],
    ["sponsor prize claim", "gem"],
    ["expired-claim sweep", "clock"],
  ];
  let px = env.x + 16;
  let py = ay + 30;
  for (const [label, ic] of paths) {
    const w = estW(label, 9.8, 700) + 40;
    if (px + w > env.x + env.w - 14) {
      px = env.x + 16;
      py += 34;
    }
    put(
      ctx,
      `<rect x="${px}" y="${py}" width="${w}" height="26" rx="8" fill="${pal.white}" stroke="${pal.line}" stroke-width="1.1"/>`,
    );
    put(ctx, icon(ic, px + 8, py + 4, 15, pal.greenDeep));
    put(ctx, txt(px + 28, py + 17.5, label, { size: 9.8, weight: 700, color: pal.ink2 }));
    px += w + 9;
  }
  // Outside column.
  const ox = 470;
  put(ctx, icon("cross", ox + 2, 48, 18, pal.danger));
  put(
    ctx,
    txt(ox + 28, 62, "Outside: no rescue path", {
      size: 13,
      weight: 800,
      color: pal.danger,
      family: F_DISP,
    }),
  );
  put(
    ctx,
    txt(ox, 82, "the contract cannot repair these", {
      size: 9.8,
      weight: 600,
      color: pal.ink3,
    }),
  );
  const outside = [
    "issuer freeze or blacklist",
    "malicious token upgrade",
    "dishonest ownerOf reports",
    "prize burned by its own contract",
    "recovery recipient loses keys",
    "forced-in unrelated NFTs",
    "direct USDC donations",
    "total transaction censorship",
  ];
  let oy = 98;
  for (const o of outside) {
    put(
      ctx,
      `<rect x="${ox}" y="${oy}" width="224" height="28" rx="9" fill="${pal.dangerWash}" stroke="${pal.danger}" stroke-width="1" opacity="0.9"/>`,
    );
    put(ctx, icon("cross", ox + 9, oy + 6.5, 14, pal.danger));
    put(ctx, txt(ox + 30, oy + 18.5, o, { size: 9.7, weight: 600, color: pal.ink2 }));
    oy += 34.5;
  }
  put(
    ctx,
    txt(
      26,
      H - 26,
      "Trapped value stays visible onchain but has no protocol exit: prevention lives in asset review before creation.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Supported recovery envelope",
    desc: "Inside the envelope every asset has a bounded exit path under honest token and chain assumptions; issuer actions, malicious code, lost keys, and censorship remain outside.",
    height: H,
  });
})();

/* ------------------------------------- 20 trust and dependency map ----- */

figures["20-trust-dependency-map.svg"] = (() => {
  const ctx = makeCtx("f20");
  const H = 486;
  const cw = 210;
  const ch = 86;
  const deps = [
    {
      x: 26,
      y: 40,
      t: "Base network",
      b: "execution, ordering, inclusion, reorg and sequencer behavior",
      icon: "cube",
      accent: pal.indigo,
    },
    {
      x: 484,
      y: 40,
      t: "Pyth Entropy",
      b: "randomness correctness, provider and keeper liveness, fee policy",
      icon: "bolt",
      accent: pal.violet,
    },
    {
      x: 26,
      y: 200,
      t: "USDC issuer",
      b: "transfers, pause, blacklist, and upgrade decisions",
      icon: "coin",
      accent: pal.skyDeep,
    },
    {
      x: 484,
      y: 200,
      t: "Prize contract",
      b: "honest ownerOf, safe transfers, metadata provenance",
      icon: "gem",
      accent: pal.pink,
    },
    {
      x: 26,
      y: 360,
      t: "User stack",
      b: "wallet keys, RPC honesty, frontend authenticity, tx review",
      icon: "key",
      accent: pal.yellow,
    },
    {
      x: 484,
      y: 360,
      t: "Operations and law",
      b: "owner Safe custody, monitoring, jurisdictional compliance",
      icon: "scale",
      accent: pal.green,
    },
  ];
  const hub = { x: 262, y: 196, w: 196, h: 94 };
  const hubCx = hub.x + hub.w / 2;
  const hubCy = hub.y + hub.h / 2;
  for (const d of deps) {
    const cx = d.x + cw / 2;
    const cy = d.y + ch / 2;
    put(
      ctx,
      arrow(ctx, hubCx + (cx > hubCx ? 40 : -40), hubCy + (cy > hubCy ? 22 : -22), cx + (cx > hubCx ? -46 : 46), cy + (cy > hubCy ? -26 : 26), {
        color: pal.lineStrong,
        width: 1.7,
        dashed: true,
        head: true,
      }),
    );
  }
  put(
    ctx,
    `<rect x="${hub.x}" y="${hub.y}" width="${hub.w}" height="${hub.h}" rx="16" fill="${pal.ink}" stroke="${pal.indigoDeep}" stroke-width="2"/>`,
  );
  put(ctx, icon("shield", hubCx - 10, hub.y + 12, 20, pal.white));
  put(
    ctx,
    txt(hubCx, hub.y + 52, "raffle.fun settlement", {
      size: 13,
      weight: 800,
      color: pal.white,
      anchor: "middle",
      family: F_DISP,
    }),
  );
  put(
    ctx,
    txt(hubCx, hub.y + 70, "correct only if its dependencies hold", {
      size: 9.3,
      weight: 550,
      color: "#c9d1ff",
      anchor: "middle",
    }),
  );
  for (const d of deps) {
    rowCard(ctx, {
      x: d.x,
      y: d.y,
      w: cw,
      h: ch,
      title: d.t,
      body: d.b,
      accent: d.accent,
      iconName: d.icon,
    });
  }
  put(
    ctx,
    txt(
      26,
      H - 24,
      "Each arrow is an independent failure surface: contract correctness alone cannot compensate for a failed dependency.",
      { size: 10, weight: 550, color: pal.ink3 },
    ),
  );
  return finish(ctx, {
    title: "Trust and dependency map",
    desc: "Raffle settlement depends on Base, Pyth Entropy, the USDC issuer, the prize contract, user key hygiene, and legal-operational controls; each is an independent failure surface.",
    height: H,
  });
})();

/* ------------------------------------------- 21 worked example --------- */

figures["21-worked-example.svg"] = (() => {
  const ctx = makeCtx("f21");
  const H = 478;
  // Root card.
  const root = { x: 26, y: 150, w: 196, h: 150 };
  put(
    ctx,
    `<rect x="${root.x}" y="${root.y}" width="${root.w}" height="${root.h}" rx="14" fill="${pal.pinkWash}" stroke="${pal.pink}" stroke-width="1.7"/>`,
  );
  put(ctx, icon("gem", root.x + 14, root.y + 13, 19, pal.pink));
  put(
    ctx,
    txt(root.x + 40, root.y + 28, "Pixel Passport #42", {
      size: 12.3,
      weight: 800,
      color: pal.ink,
    }),
  );
  put(
    ctx,
    linesTxt(
      root.x + 14,
      root.y + 54,
      [
        `ticket price ${E.thresholdMet.ticketPrice} USDC`,
        "threshold 100 tickets",
        "recovery wallet fixed",
        "sale runs seven days",
      ],
      17,
      { size: 10.2, weight: 600, color: pal.ink2 },
    ),
  );
  put(
    ctx,
    txt(root.x + 14, root.y + 132, "one deposit, four possible futures", {
      size: 9.2,
      weight: 550,
      color: pal.ink3,
    }),
  );
  // Outcome cards.
  const ox = 306;
  const ow = 388;
  const oh = 88;
  const outcomes = [
    {
      y: 36,
      chip: "120 sold",
      t: "NftWon",
      accent: pal.green,
      fill: pal.greenWash,
      lines: [
        `winner burns for the NFT · sponsor claims ${E.thresholdMet.distributable}`,
        `treasury claims ${E.thresholdMet.fee} (${C.protocolFeePercent} of ${E.thresholdMet.gross})`,
      ],
    },
    {
      y: 144,
      chip: "80 sold · callback lands",
      t: "CashWon",
      accent: pal.pink,
      fill: pal.pinkWash,
      lines: [
        `winner ${E.cashFallback.winnerCash} · sponsor ${E.cashFallback.sponsorCash} · treasury ${E.cashFallback.fee}`,
        "recovery wallet claims the NFT back",
      ],
    },
    {
      y: 252,
      chip: "80 sold · draw never resolves",
      t: "Refunding",
      accent: pal.danger,
      fill: pal.dangerWash,
      lines: [
        `each owner burns tickets for ${E.failedDraw.refundPerTicket} each · ${E.failedDraw.totalRefunds} total`,
        "no fee, no winner · recovery wallet claims the NFT",
      ],
    },
    {
      y: 360,
      chip: "0 sold",
      t: "Closed",
      accent: pal.slate,
      fill: pal.slateWash,
      lines: [
        "sponsor may close early; anyone may close after the sale",
        "no pot exists · recovery wallet claims the NFT",
      ],
    },
  ];
  for (const o of outcomes) {
    put(
      ctx,
      curve(ctx, root.x + root.w + 2, root.y + 75, ox - 5, o.y + oh / 2, {
        color: o.accent,
        width: 2,
        bend: 0.45,
      }),
    );
    put(
      ctx,
      `<rect x="${ox}" y="${o.y}" width="${ow}" height="${oh}" rx="13" fill="${o.fill}" stroke="${o.accent}" stroke-width="1.5"/>`,
    );
    const chip = pill(ctx, {
      x: ox + 14,
      y: o.y + 12,
      text: o.chip,
      size: 9.4,
      weight: 750,
      fg: pal.white,
      bg: o.accent,
      stroke: o.accent,
      h: 21,
    });
    put(ctx, chip.svg);
    put(
      ctx,
      txt(ox + ow - 14, o.y + 28, o.t, {
        size: 12.5,
        weight: 800,
        mono: true,
        color: pal.ink,
        anchor: "end",
      }),
    );
    put(
      ctx,
      linesTxt(ox + 14, o.y + 52, o.lines, 15.5, {
        size: 10,
        weight: 600,
        color: pal.ink2,
      }),
    );
  }
  put(
    ctx,
    txt(26, H - 20, "Illustrative names and assets; every amount is computed from compiled constants in six-decimal raw units.", {
      size: 9.8,
      weight: 550,
      color: pal.ink3,
    }),
  );
  return finish(ctx, {
    title: "Pixel Passport #42: all branches",
    desc: "One raffle configuration and its four possible futures, with the exact amounts the contracts would record in each terminal outcome.",
    height: H,
  });
})();

/* --------------------------------------------------------------- write -- */

mkdirSync(output, { recursive: true });
for (const [name, content] of Object.entries(figures)) {
  writeFileSync(resolve(output, name), `${content}\n`);
}
console.log(
  `Generated ${Object.keys(figures).length} SVG figures in ${output}`,
);
