// Context menus: cópia do `menu` do Herdr 0.1.13 (layout `ary`, via
// `terminal_menu`) com um item a mais no menu do pane: "Copy pane info",
// que põe no clipboard quem é o pane e os comandos `hc` para outro agente
// falar com ele. Opened as a popup with
// props { tab: "pane" | "tab" | "space" | "global", target }.
// ↑/↓ move, Enter runs, Esc closes. An item is [label, command, args];
// a command "worktree" opens the worktree dialog instead; "copy-info" copies.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, openOverlay, theme, keys, terminals, spaces, panes, agents, exec, notify } from "herdr";

// Título do terminal sem o prefixo do omp (`π <spinner|>> <ícone> `) nem
// ícones (o mesmo corte do mod session-status).
function cleanTitle(title) {
  return (title ?? "")
    .replace(/^π(?=\s)/u, "")
    .replace(/\p{Co}/gu, "")
    .replace(/^[\s\p{So}\p{P}\p{S}]+/u, "")
    .trim();
}

// O texto colado noutro pane: identidade do pane e como falar com ele.
function paneInfo(tg) {
  const term = terminals().find((t) => t.address === tg.terminal);
  const pane = panes().find((p) => p.pane === tg.pane);
  const agent = agents().find((a) => a.pane === tg.pane || a.address === tg.terminal);
  const space = agent && spaces().find((s) => s.id === agent.space);
  const addr = tg.terminal;
  const title = cleanTitle(agent?.title ?? pane?.title);
  const cwd = pane?.cwd ?? term?.cwd;
  const what = agent?.app ?? pane?.app ?? pane?.program?.name;
  return [
    `Outro pane do Herdr para você conversar (terminal ${addr}):`,
    ...(what ? [`- programa: ${what}${agent ? ` (status: ${agent.status})` : ""}`] : []),
    ...(title ? [`- sessão: ${title}`] : []),
    ...(cwd ? [`- pasta: ${cwd}`] : []),
    ...(agent ? [`- space / tab: ${agent.space_name} / ${agent.tab_name || agent.tab_index}`] : []),
    ...(space?.machine ? [`- máquina: ${space.machine}`] : []),
    "Como falar com ele (rode no seu shell):",
    `- mandar mensagem: hc send ${addr} "<mensagem>"`,
    `- ler a tela dele: hc read ${addr}`,
    `- esperar ele terminar: hc wait ${addr}`,
  ].join("\n");
}

// Where a space is now: its first terminal's live folder, else where it was made.
function place(s) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return panes().find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}

// A space's checkout: "main" (a repo's own), "linked" (a worktree), or null.
async function checkout(folder, on) {
  const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd: folder, on });
  const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd: folder, on });
  if (top.code !== 0 || common.code !== 0) return null;
  return common.stdout.trim() === `${top.stdout.trim()}/.git` ? "main" : "linked";
}

function items(p, git) {
  p = p ?? {};
  const tg = p.target ?? {};
  switch (p.tab) {
    case "pane": {
      // A kept sub-agent can go back under its parent, still running.
      const all = terminals();
      const term = all.find((t) => t.address === tg.terminal);
      const parent = term?.parent && all.find((t) => t.address === term.parent);
      // Once they go to the program, Shift+right-click still opens this menu.
      const toProgram = term?.labels?.["herdr.right-click"] === "program";
      return [
        ["Split right", "pane.split", { direction: "right", pane: tg.pane }],
        ["Split down", "pane.split", { direction: "down", pane: tg.pane }],
        ["Zoom", "pane.zoom", { pane: tg.pane }],
        ...(tg.terminal ? [["Copy pane info", "copy-info", { pane: tg.pane, terminal: tg.terminal }]] : []),
        ...(term
          ? [
              toProgram
                ? ["Use Herdr right-click menu", "terminal.right_click", { terminal: term.address, to: "menu" }]
                : ["Send right-clicks to pane", "terminal.right_click", { terminal: term.address, to: "program" }],
            ]
          : []),
        ...(parent ? [[`Send back to ${parent.name || parent.address}`, "terminal.park", { terminal: term.address }]] : []),
        ["Close pane", "pane.close", { pane: tg.pane }],
      ];
    }
    case "tab":
      return [
        ["Rename", "tab.rename", { id: tg.id }],
        ["New tab", "tab.new", { space: tg.space }],
        ["Close", "tab.close", { id: tg.id }],
      ];
    case "space":
      return [
        ["Rename", "space.rename", { id: tg.id }],
        ...(git ? [["New worktree", "worktree", { space: tg.id, action: "new" }], ["Open worktree", "worktree", { space: tg.id, action: "open" }]] : []),
        ...(git === "linked" ? [["Remove worktree", "worktree", { space: tg.id, action: "remove" }]] : []),
        ["Close", "space.close", { id: tg.id }],
      ];
    default:
      return [
        ["New space", "space.new", {}],
        ["Keybinds", "app.help", {}],
        ["Theme: graphite", "app.theme", { name: "graphite" }],
        ["Theme: ink", "app.theme", { name: "ink" }],
        ["Theme: moss", "app.theme", { name: "moss" }],
        ["Theme: atom one dark", "app.theme", { name: "atom-one-dark" }],
      ];
  }
}

function menuIcon(command) {
  const name = command.endsWith(".close") ? "x" : command.endsWith(".rename") ? "square-pen" : command.endsWith(".new") ? "plus" : command === "worktree" ? "git-branch" : command === "copy-info" ? "file-text" : command === "app.help" ? "terminal" : command === "app.theme" ? "settings" : command === "pane.split" ? "panel-right" : command === "pane.zoom" ? "square" : "terminal";
  return `mods/workspace-chrome/${name}.svg`;
}

// The key bound to a command, for the hint on the right.
function shortcut(name, args) {
  // `pane.split:right` binds pane.split with { direction: "right" }.
  const value = args && Object.values(args)[0];
  const k = keys().find((b) => b.section === "global" && (b.action === name || b.action === `${name}:${value}`));
  return k ? k.keys : "";
}

export default class Menu extends View {
  init(_props, cx) {
    this.at = 0;
    this.git = null;
    this.handle = cx.focus_handle();
    this.handle.focus();
    const p = props();
    const space = p?.tab === "space" && spaces().find((s) => s.id === p.target?.id);
    const folder = space && place(space);
    if (folder)
      cx.spawn(async (cx) => {
        this.git = await checkout(folder, space.machine).catch(() => null);
        cx.notify();
      });
  }

  choose(i, cx) {
    const it = items(props(), this.git)[i];
    if (!it) return;
    if (it[1] === "copy-info") {
      // pbcopy lê o texto do argumento ($1), não de shell montado com ele.
      // LC_ALL=UTF-8: o mod roda sem locale, e o pbcopy lê bytes como MacRoman
      // ("sessão" vira "sess√£o"; medido 2026-11-05 com env -i).
      const text = paneInfo(it[2]);
      cx.spawn(async () => {
        const r = await exec("/bin/sh", ["-c", 'printf %s "$1" | LC_ALL=en_US.UTF-8 pbcopy', "sh", text]).catch((e) => ({ code: 1, stderr: String(e) }));
        closeOverlay(props()?.overlay);
        notify(r.code === 0
          ? { title: `Pane ${it[2].terminal} copiado`, body: "Cole no outro pane para ele falar com este.", level: "success", timeout: 3000 }
          : { title: "Não copiou", body: r.stderr.trim(), level: "error" });
      });
      return;
    }
    closeOverlay(props()?.overlay);
    if (it[1] === "worktree") openOverlay({ mod: "worktree", kind: "dialog", ...(it[2].action === "open" ? { width: 560, height: 480 } : { width: 440, height: 260 }), props: it[2] });
    else run(it[1], it[2]);
  }

  render(cx) {
    const t = theme();
    const list = items(props(), this.git);
    return v_flex()
      .id("menu")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(5)
      .bg(t.popover)
      .text_size(12.8)
      .on_key_down((e, cx) => {
        if (e.key === "down") this.at = (this.at + 1) % list.length;
        else if (e.key === "up") this.at = (this.at + list.length - 1) % list.length;
        else if (e.key === "enter") this.choose(this.at, cx);
        else if (e.key === "escape") closeOverlay(props().overlay);
        else return;
        cx.notify();
      })
      .children(
        list.map((it, i) =>
          v_flex()
            .when(i > 0 && (it[1].endsWith(".close") || it[1] === "app.help" || (it[1] === "app.theme" && list[i - 1][1] !== "app.theme")), el => el.child(div().mx(7).my(4).h(1).bg(t.border)))
            .child(h_flex()
            .id(`mi-${i}`)
            .h(31)
            .px(8)
            .gap(9)
            .rounded(7)
            .items_center()
            .justify_between()
            .text_color(t.foreground)
            .when(i === this.at, (el) => el.bg(t.selected))
            .hover((s) => s.bg(t.hover))
            .on_click((_e, cx) => this.choose(i, cx))
            .child(svg(menuIcon(it[1])).size(14).flex_none().text_color(t.muted))
            .child(div().flex_1().child(it[0]))
            .child(div().text_size(11).text_color(t.dim).child(shortcut(it[1], it[2])))),
        ),
      );
  }
}
