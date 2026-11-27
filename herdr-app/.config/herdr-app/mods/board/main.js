// Agents as cards in three columns: Needs you, Working, Done (done and idle).

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { agents, spaces, terminals, run, theme, props, shared, setWindowTitle, setAgentOrder, nextCommand } from "herdr";

const COLUMNS = [
  { id: "blocked", label: "Needs you", match: (s) => s === "blocked" },
  { id: "working", label: "Working", match: (s) => s === "working" },
  { id: "done", label: "Done", match: (s) => s !== "blocked" && s !== "working" },
];

// The sidebar splits Done (finished, not looked at yet) from Idle (seen, quiet).
const VCOLUMNS = [
  { id: "blocked", label: "Needs you", match: (s) => s === "blocked" },
  { id: "working", label: "Working", match: (s) => s === "working" },
  { id: "done", label: "Done", match: (s) => s === "done" },
  { id: "idle", label: "Idle", match: (s) => s !== "blocked" && s !== "working" && s !== "done" },
];

// Why an agent needs you, when its report says: approval, a question, or a failure.
function needKind(a) {
  const t = terminals().find((x) => x.address === a.address);
  const k = t?.status?.kind ?? t?.kind ?? t?.report?.kind;
  if (t?.status?.state === "error" || t?.state === "error") return "Failed";
  if (k === "permission") return "Approval";
  if (k === "question") return "Input";
  return "Needs you";
}

// Drops the status glyph or spinner an agent puts before its title.
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}\p{Ps}\p{Pi}]+/u, "").trim();

function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

const tokens = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : String(n));

export default class Board extends View {
  init(_props, cx) {
    // Each agent's last state and when it changed (ms), kept across restarts.
    try { this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}"); } catch { this.changed = {}; }
    if (!this.changed || typeof this.changed !== "object" || Array.isArray(this.changed)) this.changed = {};
    try { this.folded = new Set(JSON.parse(localStorage.getItem("folded2") ?? '["idle","settled"]')); } catch { this.folded = new Set(["idle", "settled"]); }
    // Pinned agents stay on top; settled ones (put away once finished) fold into their own section
    // and come back by themselves when the agent works or needs you again.
    try { this.pins = JSON.parse(localStorage.getItem("pins") ?? "[]"); } catch { this.pins = []; }
    try { this.settled = JSON.parse(localStorage.getItem("settled") ?? "{}"); } catch { this.settled = {}; }
    if (!Array.isArray(this.pins)) this.pins = [];
    if (!this.settled || typeof this.settled !== "object" || Array.isArray(this.settled)) this.settled = {};
    this.hovered = null;
    // Search over name, title, branch and program; account chip filters by Claude account.
    this.query = "";
    this.account = localStorage.getItem("account") || "";
    this.title = null;
    this.search = InputState.new({ placeholder: "Filter agents…" });
    this.search.on("change", (_e, cx) => { this.query = this.search.value().trim().toLowerCase(); cx.notify(); });
    // Keyboard: the sidebar copy takes the keys when pane.go or board.focus reaches it.
    this.typing = false;
    this.cursor = null;
    this.nav = [];
    this.undo = null;
    this.kidFold = new Set();
    this.search.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.search.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    if (props()?.vertical) {
      this.handle = cx.focus_handle();
      cx.spawn(async (cx) => {
        for (;;) {
          const c = await nextCommand();
          if (String(c).includes("focus")) { this.handle.focus(); cx.notify(); }
        }
      });
    }
    cx.timer.every(30000, (cx) => cx.notify());
  }

  // Looking at a finished agent turns done into idle; that is not the agent doing anything.
  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed)) if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
  }


  snapshot() {
    return { pins: [...this.pins], settled: { ...this.settled } };
  }

  // One handler for every key the focused board understands.
  onKey(e, cx) {
    if (this.typing) {
      if (e.key === "escape") { this.handle.focus(); cx.notify(); }
      return;
    }
    if (e.modifiers.control || e.modifiers.alt || e.modifiers.platform) return;
    const k = e.key;
    const nav = this.nav;
    let i = nav.findIndex((n) => n.key === this.cursor);
    const go = (to) => { this.cursor = nav[to]?.key ?? null; cx.notify(); };
    const cur = nav[i];
    const fold = (id, open) => {
      open ? this.folded.delete(id) : this.folded.add(id);
      this.save();
      cx.notify();
    };
    if (!nav.length) return;
    if (k === "down" || k === "j") go(i < 0 ? 0 : (i + 1) % nav.length);
    else if (k === "up" || k === "k") go(i < 0 ? nav.length - 1 : (i + nav.length - 1) % nav.length);
    else if (k === "home") go(0);
    else if (k === "end") go(nav.length - 1);
    else if (k === "enter" || k === "space" || k === " ") {
      if (!cur) return;
      if (cur.kind === "head") fold(cur.id, this.folded.has(cur.id));
      else run("pane.focus", { pane: cur.a.pane });
    } else if (k === "right" && cur?.kind === "head") fold(cur.id, true);
    else if (k === "left") {
      if (cur?.kind === "head") fold(cur.id, false);
      else if (cur) { for (let j = i - 1; j >= 0; j--) if (nav[j].kind === "head") { go(j); break; } }
    } else if ((k === "p" || k === "s") && cur?.kind === "row") {
      const a = cur.a;
      if (k === "s" && (a.status === "working" || a.status === "blocked")) return;
      this.undo = this.snapshot();
      if (k === "p") {
        const on = this.pins.includes(a.address);
        this.pins = on ? this.pins.filter((x) => x !== a.address) : [...this.pins, a.address];
        if (!on) delete this.settled[a.address];
      } else if (this.settled[a.address]) delete this.settled[a.address];
      else { this.settled[a.address] = true; this.pins = this.pins.filter((x) => x !== a.address); }
      this.save();
      cx.notify();
    } else if (k === "u" && this.undo) {
      this.pins = this.undo.pins;
      this.settled = this.undo.settled;
      this.undo = null;
      this.save();
      cx.notify();
    } else if (k === "/") { this.search.focus(); }
    else if (k === "escape") { run("pane.go", { direction: "right" }); }
  }

  save() {
    localStorage.setItem("pins", JSON.stringify(this.pins));
    localStorage.setItem("settled", JSON.stringify(this.settled));
    localStorage.setItem("folded2", JSON.stringify([...this.folded]));
  }

  // The sidebar version: one column, folding sections, a row per agent.
  vertical(t, all, now) {
    let list = all;
    const seen = (a) => this.changed[a.address]?.at ?? 0;
    const stats = shared("agent.stats") ?? {};
    const bySpace = new Map(spaces().map((sp) => [sp.id, sp]));
    // The window title carries how many agents need you, visible even when this window is behind others.
    const needs = all.filter((a) => a.status === "blocked").length;
    const wanted = needs ? `(${needs}) Herdr` : null;
    if (wanted !== this.title) { this.title = wanted; setWindowTitle(wanted); }
    const total = all.length, working = all.filter((a) => a.status === "working").length;
    const accounts = [...new Set(Object.values(stats).map((v) => v?.account).filter(Boolean))];
    if (this.account && !accounts.includes(this.account)) this.account = "";
    const q = this.query;
    const match = (a) => {
      if (this.account && stats[a.address]?.account !== this.account) return false;
      if (!q) return true;
      const sp = bySpace.get(a.space);
      return [a.space_name, a.pane_name, a.title, sp?.branch, a.program?.name].some((x) => (x ?? "").toLowerCase().includes(q));
    };
    list = list.filter(match);
    // Work or a question brings a settled agent back.
    for (const a of all) if (this.settled[a.address] && (a.status === "working" || a.status === "blocked")) delete this.settled[a.address];
    const pinned = list.filter((a) => this.pins.includes(a.address)).sort((x, y) => this.pins.indexOf(x.address) - this.pins.indexOf(y.address));
    const rest = list.filter((a) => !this.pins.includes(a.address));
    const isSettled = (a) => Boolean(this.settled[a.address]) && a.status !== "working" && a.status !== "blocked";
    const groups = [
      { id: "pinned", label: "Pinned", color: t.accent, items: pinned },
      ...VCOLUMNS.map((c) => ({ id: c.id, label: c.label, color: t[c.id] ?? t.dim, items: rest.filter((a) => c.match(a.status) && !((c.id === "done" || c.id === "idle") && isSettled(a))) })),
      { id: "settled", label: "Settled", color: t.dim, items: rest.filter(isSettled) },
    ];
    for (const g of groups) if (g.id !== "pinned") g.items.sort((x, y) => seen(y) - seen(x) || y.seq - x.seq);

    // alt-up / alt-down (agent.prev / agent.next) walk the board top to bottom.
    setAgentOrder(groups.flatMap((g) => g.items.map((a) => a.address)));
    const nav = [];
    const focused = Boolean(this.handle?.is_focused());

    const iconBtn = (id, file, tip, on) => div().id(id).flex_none().p(3).rounded(5).text_color(t.dim).cursor_pointer()
      .hover((s) => s.bg(t.hover).text_color(t.foreground)).tooltip(tip)
      .on_click((_e, cx) => { cx.stop_propagation(); this.undo = this.snapshot(); on(); this.save(); cx.notify(); })
      .child(svg(`mods/workspace-chrome/${file}.svg`).size(13));

    // Live children of an agent (programs and agents it started, depth first), with their tree lines.
    const terms = terminals();
    const listed = new Set(all.map((a) => a.address));
    const tree = (addr, lead = []) => terms.filter((k) => k.parent === addr && k.state === "live").flatMap((k, i, arr) => {
      const last = i === arr.length - 1;
      return [{ k, lines: [...lead, last ? "└" : "├"] }, ...tree(k.address, [...lead, last ? "" : "│"])];
    });
    const wordOf = (k) => {
      const w = typeof k.status === "string" ? k.status : k.status?.state;
      return w === "error" ? "blocked" : w === "done" ? "idle" : w;
    };
    const kidRow = ({ k, lines }) => {
      const w = wordOf(k);
      const pic = k.program?.icon
        ? (k.program.tint ? svg(k.program.icon).size(12).flex_none().text_color(t.muted) : image(k.program.icon).w(12).h(12).flex_none())
        : null;
      return h_flex().id(`kid-${k.address}`).flex_none().h(24).pl(24).pr(8).gap(6).rounded(6).items_center().text_size(12)
        .cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click(() => (listed.has(k.address) ? run("pane.focus", { terminal: k.address }) : run("terminal.peek", { terminal: k.address })))
        .children(lines.map((l) => div().self_start().mt(-4).w(9).h(16).flex_none()
          .when(Boolean(l), (el) => el.border_l(1.5).border_color(t.input))
          .when(l === "└" || l === "├", (el) => el.border_b(1.5).rounded_bl(6))))
        .when(Boolean(pic), (el) => el.child(pic))
        .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(k.name || k.template || k.program?.name || k.agent || k.address))
        .when(w === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(11).flex_none().text_color(t.working).spin(900)))
        .when(w === "blocked", (el) => el.child(div().size(6).flex_none().rounded(3).bg(t.blocked)));
    };

    const row = (a, g) => {
      const kids = tree(a.address);
      const kidsOpen = !this.kidFold.has(a.address);
      const foldChip = kids.length ? div().id(`kids-${a.address}`).flex_none().px(4).h(18).flex().items_center().gap(3).rounded(4)
        .text_size(11).text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground)).tooltip(kidsOpen ? "Hide sub-agents" : "Show sub-agents")
        .on_click((_e, cx) => { cx.stop_propagation(); kidsOpen ? this.kidFold.add(a.address) : this.kidFold.delete(a.address); cx.notify(); })
        .child(svg(`mods/workspace-chrome/chevron-${kidsOpen ? "down" : "right"}.svg`).size(10).flex_none())
        .child(String(kids.length)) : null;
      const pic = a.program?.icon
        ? (a.program.tint ? svg(a.program.icon).size(14).flex_none().text_color(t.muted) : image(a.program.icon).w(14).h(14).flex_none())
        : null;
      const detail = clean(a.pane_name || a.title);
      // Working and blocked use core's own stamp (exact, survives restarts); the rest the local observation.
      const exact = shared("agent.since")?.[a.address];
      const since = exact && exact.state === a.status && (a.status === "working" || a.status === "blocked") ? exact.ms : this.changed[a.address]?.at;
      const sp = bySpace.get(a.space);
      const branch = sp?.branch;
      const worktree = (sp?.folder ?? "").includes("/.herdr/worktrees/");
      const st = stats[a.address];
      const bits = [];
      if (st?.cost > 0) bits.push(`$${st.cost.toFixed(2)}`);
      if (st && st.input + st.output > 0) bits.push(`${tokens(st.input + st.output)} tok`);
      if (st?.ctx != null) bits.push(`ctx ${Math.round(st.ctx)}%`);
      const isPinned = this.pins.includes(a.address);
      const done = a.status !== "working" && a.status !== "blocked";
      const hot = this.hovered === a.address;
      const key = `row:${a.address}`;
      nav.push({ key, kind: "row", a });
      const cursor = focused && this.cursor === key;
      const rowEl = h_flex().id(`vrow-${a.address}`).flex_none().px(10).py(8).gap(9).rounded(8).items_start()
        .bg(a.focused ? t.selected : t.chrome)
        .border_l(3).border_color(g.color)
        .when(cursor, (el) => el.bg(t.raised).border_t(1).border_b(1).border_r(1).border_color(t.accent))
        .cursor_pointer().hover((s) => s.bg(a.focused ? t.selected : t.hover))
        .on_hover((on, cx) => { if (on) this.hovered = a.address; else if (this.hovered === a.address) this.hovered = null; cx.notify(); })
        .on_click(() => run("pane.focus", { pane: a.pane }))
        .when(Boolean(pic), (el) => el.child(div().mt(2).child(pic)))
        .child(v_flex().flex_1().min_w(0).gap(2)
          .child(h_flex().gap(6).items_center()
            .child(div().flex_1().min_w(0).truncate().text_size(13).font_semibold().text_color(t.foreground).child(a.space_name || a.program?.name || a.address))
            .when(a.status === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
            .when(Boolean(foldChip), (el) => el.child(foldChip))
            .when(hot, (el) => el
              .when(done, (el) => el.child(iconBtn(`settle-${a.address}`, "check", isSettled(a) ? "Bring back" : "Settle: put away until it works again", () => {
                if (this.settled[a.address]) delete this.settled[a.address]; else { this.settled[a.address] = true; this.pins = this.pins.filter((x) => x !== a.address); }
              })))
              .child(iconBtn(`pin-${a.address}`, isPinned ? "pin-off" : "pin", isPinned ? "Unpin" : "Pin to the top", () => {
                this.pins = isPinned ? this.pins.filter((x) => x !== a.address) : [...this.pins, a.address];
                if (!isPinned) delete this.settled[a.address];
              })))
            .when(!hot && a.status === "blocked", (el) => el.child(div().flex_none().px(6).h(18).flex().items_center().rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).child(needKind(a))))
            .when(!hot && a.status !== "blocked" && Boolean(since), (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(duration(now - since)))))
          .when(Boolean(detail), (el) => el.child(div().truncate().text_size(11.5).text_color(t.muted).child(detail)))
          .when(Boolean(branch), (el) => el.child(h_flex().gap(5).items_center().text_size(11).text_color(t.dim)
            .child(svg("mods/workspace-chrome/git-branch.svg").size(11).flex_none())
            .child(div().min_w(0).truncate().child(branch))
            .when(worktree, (el) => el.child(div().flex_none().px(5).rounded(4).bg(t.hover).child("worktree")))))
          .when(bits.length > 0, (el) => el.child(div().text_size(11).text_color(t.dim).child(bits.join(" · ")))));
      return kids.length ? v_flex().flex_none().gap(2).child(rowEl).children(kidsOpen ? kids.map(kidRow) : []) : rowEl;
    };

    // Per account: plan limits when the account exposes them (Pro), else what the live sessions spent
    // (contracted Enterprise accounts have no 5h / 7d counters).
    const per = new Map();
    for (const v of Object.values(stats)) {
      if (!v?.account) continue;
      const e = per.get(v.account) ?? { cost: 0, n: 0, five: "", week: "" };
      e.cost += v.cost || 0;
      e.n += 1;
      if (v.five !== "" && v.five != null) { e.five = v.five; e.week = v.week; }
      per.set(v.account, e);
    }
    const usageLines = [...per.entries()].map(([acc, e]) => (e.five !== "" ? `${acc} · 5h ${e.five}%${e.week !== "" ? ` · 7d ${e.week}%` : ""}` : `${acc} · $${e.cost.toFixed(2)} · ${e.n} sessions`));

    const root = v_flex().size_full().min_h(0).bg(t.chrome).border_t(1).border_color(t.border)
      .child(v_flex().px(16).pt(12).pb(6).flex_none().gap(6)
        .child(h_flex().items_center().gap(8)
          .child(div().text_size(11.5).font_medium().text_color(t.dim).child("Agents"))
          .child(div().flex_1())
          .child(div().text_size(11).text_color(t.dim).child(`${total} · ${working} working${needs ? ` · ${needs} need you` : ""}`)))
        .children(usageLines.map((line) => div().truncate().text_size(11).text_color(t.dim).child(line)))
        .when(accounts.length > 1, (el) => el.child(h_flex().gap(6).children(["", ...accounts].map((acc) => {
          const on = this.account === acc;
          return div().id(`acct-${acc || "all"}`).px(8).h(22).flex().items_center().rounded(11).text_size(11)
            .bg(on ? t.selected : t.hover).text_color(on ? t.foreground : t.muted).cursor_pointer()
            .on_click((_e, cx) => { this.account = acc; localStorage.setItem("account", acc); cx.notify(); })
            .child(acc || "All");
        }))))
        .child(h_flex().h(28).px(8).items_center().rounded(6).bg(t.hover)
          .child(Input.new(this.search).flex_1().h_full().text_size(12).text_color(t.foreground))))
      .child(v_flex().id("vboard").flex_1().min_h(0).px(8).pb(8).gap(4).overflow_y_scrollbar().children(groups.flatMap((g) => {
        if (g.id === "pinned" && g.items.length === 0) return [];
        if (g.id === "settled" && g.items.length === 0) return [];
        const open = !this.folded.has(g.id);
        nav.push({ key: `head:${g.id}`, kind: "head", id: g.id });
        const header = h_flex().id(`vhead-${g.id}`).px(8).mt(6).h(30).flex_none().gap(6).items_center().rounded(6)
          .text_size(11.5).font_medium().cursor_pointer().hover((s) => s.bg(t.hover))
          .when(focused && this.cursor === `head:${g.id}`, (el) => el.bg(t.raised).border(1).border_color(t.accent))
          .on_click((_e, cx) => { open ? this.folded.add(g.id) : this.folded.delete(g.id); this.save(); cx.notify(); })
          .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(11).flex_none().text_color(t.dim))
          .child(div().text_color(g.color).child(g.label))
          .child(div().px(6).rounded(8).bg(g.items.length ? g.color + "26" : t.hover).text_color(g.items.length ? g.color : t.dim).child(String(g.items.length)));
        return [header, ...(!open ? [] : g.items.length ? g.items.map((a) => row(a, g)) : [div().px(26).py(4).text_size(11.5).text_color(t.dim).child("Nothing here")])];
      })));
    this.nav = nav;
    if (this.handle) root.track_focus(this.handle).on_key_down((e, cx) => this.onKey(e, cx));
    return root;
  }

  card(t, a, now, col) {
    const color = t[col.id] ?? t.dim;
    const pic = a.program?.icon
      ? (a.program.tint ? svg(a.program.icon).size(14).flex_none().text_color(t.muted) : image(a.program.icon).w(14).h(14).flex_none())
      : null;
    const detail = clean(a.pane_name || a.title);
    const since = this.changed[a.address]?.at;
    return v_flex()
      .id(`card-${a.address}`)
      .flex_none()
      .p(10)
      .gap(4)
      .rounded(8)
      .bg(a.focused ? t.selected : t.raised)
      .border(1)
      .border_color(a.focused ? t.accent : t.border)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .on_click(() => run("pane.focus", { pane: a.pane }))
      .child(h_flex().gap(7).items_center()
        .when(Boolean(pic), (el) => el.child(pic))
        .child(div().flex_1().min_w(0).truncate().font_semibold().text_size(13).text_color(t.foreground).child(a.space_name || a.program?.name || a.address))
        .when(col.id === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(col.id === "blocked", (el) => el.child(div().size(8).flex_none().rounded(4).bg(t.blocked))))
      .when(Boolean(detail), (el) => el.child(div().truncate().text_size(12).text_color(t.muted).child(detail)))
      .child(h_flex().gap(6).text_size(11).text_color(t.dim)
        .child(div().flex_1())
        .when(Boolean(since), (el) => el.child(div().child(duration(now - since)))));
  }

  render(_cx) {
    const t = theme();
    const list = agents();
    const now = Date.now();
    this.track(list, now);
    if (props()?.vertical) return this.vertical(t, list, now);
    // Newest change first inside each column.
    const seen = (a) => this.changed[a.address]?.at ?? 0;
    return h_flex().size_full().bg(t.canvas).p(10).gap(10).children(COLUMNS.map((col) => {
      const cards = list.filter((a) => col.match(a.status)).sort((x, y) => seen(y) - seen(x) || y.seq - x.seq);
      return v_flex().id(`col-${col.id}`).flex_1().h_full().min_w(0).min_h(0).gap(8)
        .child(h_flex().px(4).h(24).gap(6).items_center().flex_none()
          .child(div().size(8).rounded(4).bg(t[col.id] ?? t.dim))
          .child(div().text_size(12).font_semibold().text_color(t.foreground).child(col.label))
          .child(div().text_size(12).text_color(t.dim).child(String(cards.length))))
        .child(v_flex().id(`list-${col.id}`).flex_1().min_h(0).gap(8).overflow_y_scrollbar()
          .children(cards.length ? cards.map((a) => this.card(t, a, now, col)) : [div().px(4).text_size(12).text_color(t.dim).child("—")]));
    }));
  }
}
