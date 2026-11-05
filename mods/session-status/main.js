// Barra de status do layout `ary`: a `workspace-status` do Herdr (máquina,
// branch, agentes, atalho da paleta) mais o resumo da sessão do agente em
// foco, tirado do título que o programa põe no terminal.
//
// O omp escreve o título como `π <spinner|>> <ícone> TAG: resumo`
// (ex.: `π ⠹ <ícone> FOOTER: Add Herdr session summary footer mod`); o Claude Code
// como `✳ resumo`. `summary()` tira o prefixo e separa a TAG.
//
// Também recebe `session-status.agent-next` / `agent-prev` (keys.json, layout
// `ary`; os laterais do mouse com a camada no Hammerspoon): pula de agente em
// ordem de prioridade, blocked > done > idle > working, e dentro de cada grupo
// na ordem de agents(). Está aqui porque comando de mod só chega a uma cópia
// viva, e esta barra está sempre no `ary`.
import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, panes, focused, theme, run, window, keys, nextCommand } from "herdr";

const RANK = { blocked: 0, done: 1, idle: 2, working: 3 };
// Um "passeio" guarda a ordem do primeiro aperto: olhar um agente done o vira
// idle, e reordenar a cada aperto faria pular os outros done. Vale enquanto o
// foco continua no agente aonde o passeio levou e por até TOUR_TTL ms.
const TOUR_TTL = 30000;

export function tourOrder(list) {
  return list.map((a, i) => ({ a, i }))
    .sort((x, y) => (RANK[x.a.status] ?? 9) - (RANK[y.a.status] ?? 9) || x.i - y.i)
    .map((x) => x.a.address);
}

// state: { order, last, time } do aperto anterior (ou null). Devolve o alvo
// (address ou null) e o estado novo.
export function step(state, list, dir, now) {
  const live = new Set(list.map((a) => a.address));
  const here = list.find((a) => a.focused)?.address;
  const fresh = state && now - state.time < TOUR_TTL && here === state.last;
  const order = fresh ? state.order.filter((x) => live.has(x)) : tourOrder(list);
  const at = fresh ? order.indexOf(state.last) : dir > 0 ? -1 : 0;
  for (let n = 1; n <= order.length; n++) {
    const target = order[(((at + dir * n) % order.length) + order.length) % order.length];
    if (target !== here) return { target, state: { order, last: target, time: now } };
  }
  return { target: null, state: null };
}

// Agente mostrado: o do pane em foco; senão o mais recente da tab em foco.
function current() {
  const f = focused();
  const list = agents();
  if (!f) return null;
  const byFocus = list.find((a) => (f.agent && a.address === f.agent) || (f.terminal && a.address === f.terminal) || (f.pane && a.pane === f.pane));
  if (byFocus) return { title: byFocus.title, status: byFocus.status };
  const inTab = list.filter((a) => a.tab === f.tab).sort((a, b) => b.seq - a.seq)[0];
  if (inTab) return { title: inTab.title, status: inTab.status };
  const pane = panes().find((p) => p.pane === f.pane && p.terminal);
  return pane?.title ? { title: pane.title, status: pane.status } : null;
}

export function summary(title) {
  const clean = (title ?? "")
    .replace(/^π(?=\s)/u, "")
    .replace(/\p{Co}/gu, "")
    .replace(/^[\s\p{So}\p{P}\p{S}]+/u, "")
    .trim();
  const m = clean.match(/^([A-Z0-9][A-Z0-9_-]{1,15}):\s+(.+)$/u);
  return m ? { tag: m[1], text: m[2] } : { tag: null, text: clean };
}

export default class SessionStatus extends View {
  init(_props, cx) {
    this.tour = null;
    cx.spawn(async () => {
      for (;;) {
        const c = String(await nextCommand()).split(".").pop();
        if (c !== "agent-next" && c !== "agent-prev") continue;
        const r = step(this.tour, agents(), c === "agent-next" ? 1 : -1, Date.now());
        this.tour = r.state;
        if (r.target) run("agent.focus", { terminal: r.target });
      }
    });
  }

  hint() {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+", option: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "app.palette");
    const parts = b && b.keys.endsWith("--") ? [...b.keys.slice(0, -2).split("-"), "-"] : b?.keys.split("-");
    const key = parts && parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join("");
    return key ? `${key}  commands` : "commands";
  }

  render() {
    const t = theme();
    const space = spaces().find((s) => s.active);
    const list = agents();
    const needs = list.filter((a) => a.status === "blocked").length;
    const cur = current();
    const s = cur ? summary(cur.title) : null;
    const label = (icon, text) => h_flex().flex_shrink_0().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    return h_flex().size_full().px(14).gap(16).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), (el) => el.child(label("branch", space.branch)))
      .child(h_flex().flex_shrink_0().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, (el) => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(h_flex().id("session").flex_1().min_w(0).gap(8).items_center()
        .when(Boolean(s?.text), (el) => el.tooltip(cur.title)
          .child(div().flex_shrink_0().size(6).rounded(3).bg(t[cur.status] ?? t.dim))
          .when(Boolean(s.tag), (el) => el.child(div().flex_shrink_0().px(6).rounded(4).bg(t.raised).text_color(t.foreground).font_semibold().child(s.tag)))
          .child(div().min_w(0).truncate().text_color(t.foreground).child(s.text))))
      .child(div().id("palette").flex_shrink_0().text_color(t.dim).on_click(() => run("app.palette")).child(this.hint()));
  }
}
