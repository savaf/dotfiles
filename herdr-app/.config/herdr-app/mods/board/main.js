// Agents as cards in three columns: Needs you, Working, Done (done and idle).

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { agents, spaces, run, theme, props, shared, setWindowTitle } from "herdr";

const COLUMNS = [
  { id: "blocked", label: "Needs you", match: (s) => s === "blocked" },
  { id: "working", label: "Working", match: (s) => s === "working" },
  { id: "done", label: "Done", match: (s) => s !== "blocked" && s !== "working" },
];

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
    try { this.folded = new Set(JSON.parse(localStorage.getItem("folded") ?? '["done","settled"]')); } catch { this.folded = new Set(["done", "settled"]); }
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


  save() {
    localStorage.setItem("pins", JSON.stringify(this.pins));
    localStorage.setItem("settled", JSON.stringify(this.settled));
    localStorage.setItem("folded", JSON.stringify([...this.folded]));
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
    for (const a of list) if (this.settled[a.address] && (a.status === "working" || a.status === "blocked")) delete this.settled[a.address];
    const pinned = list.filter((a) => this.pins.includes(a.address)).sort((x, y) => this.pins.indexOf(x.address) - this.pins.indexOf(y.address));
    const rest = list.filter((a) => !this.pins.includes(a.address));
    const isSettled = (a) => Boolean(this.settled[a.address]) && a.status !== "working" && a.status !== "blocked";
    const groups = [
      { id: "pinned", label: "Pinned", color: t.accent, items: pinned },
      ...COLUMNS.map((c) => ({ id: c.id, label: c.label, color: t[c.id] ?? t.dim, items: rest.filter((a) => c.match(a.status) && !(c.id === "done" && isSettled(a))) })),
      { id: "settled", label: "Settled", color: t.dim, items: rest.filter(isSettled) },
    ];
    for (const g of groups) if (g.id !== "pinned") g.items.sort((x, y) => seen(y) - seen(x) || y.seq - x.seq);

    const iconBtn = (id, file, tip, on) => div().id(id).flex_none().p(3).rounded(5).text_color(t.dim).cursor_pointer()
      .hover((s) => s.bg(t.hover).text_color(t.foreground)).tooltip(tip)
      .on_click((_e, cx) => { cx.stop_propagation(); on(); this.save(); cx.notify(); })
      .child(svg(`mods/workspace-chrome/${file}.svg`).size(13));

    const row = (a, g) => {
      const pic = a.program?.icon
        ? (a.program.tint ? svg(a.program.icon).size(14).flex_none().text_color(t.muted) : image(a.program.icon).w(14).h(14).flex_none())
        : null;
      const detail = clean(a.pane_name || a.title);
      const since = this.changed[a.address]?.at;
      const sp = bySpace.get(a.space);
      const branch = sp?.branch;
      const worktree = (sp?.folder ?? "").includes("/.herdr/worktrees/");
      const st = stats[a.address];
      const bits = [];
      if (st?.cost > 0) bits.push(`$${st.cost.toFixed(2)}`);
      if (st && st.input + st.output > 0) bits.push(`${tokens(st.input + st.output)} tok`);
      const isPinned = this.pins.includes(a.address);
      const done = a.status !== "working" && a.status !== "blocked";
      const hot = this.hovered === a.address;
      return h_flex().id(`vrow-${a.address}`).flex_none().px(10).py(8).gap(9).rounded(8).items_start()
        .bg(a.focused ? t.selected : t.chrome)
        .border_l(3).border_color(g.color)
        .cursor_pointer().hover((s) => s.bg(a.focused ? t.selected : t.hover))
        .on_hover((on, cx) => { if (on) this.hovered = a.address; else if (this.hovered === a.address) this.hovered = null; cx.notify(); })
        .on_click(() => run("pane.focus", { pane: a.pane }))
        .when(Boolean(pic), (el) => el.child(div().mt(2).child(pic)))
        .child(v_flex().flex_1().min_w(0).gap(2)
          .child(h_flex().gap(6).items_center()
            .child(div().flex_1().min_w(0).truncate().text_size(13).font_semibold().text_color(t.foreground).child(a.space_name || a.program?.name || a.address))
            .when(a.status === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
            .when(hot, (el) => el
              .when(done, (el) => el.child(iconBtn(`settle-${a.address}`, "check", isSettled(a) ? "Bring back" : "Settle: put away until it works again", () => {
                if (this.settled[a.address]) delete this.settled[a.address]; else { this.settled[a.address] = true; this.pins = this.pins.filter((x) => x !== a.address); }
              })))
              .child(iconBtn(`pin-${a.address}`, isPinned ? "pin-off" : "pin", isPinned ? "Unpin" : "Pin to the top", () => {
                this.pins = isPinned ? this.pins.filter((x) => x !== a.address) : [...this.pins, a.address];
                if (!isPinned) delete this.settled[a.address];
              })))
            .when(!hot && Boolean(since), (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(duration(now - since)))))
          .when(Boolean(detail), (el) => el.child(div().truncate().text_size(11.5).text_color(t.muted).child(detail)))
          .when(Boolean(branch), (el) => el.child(h_flex().gap(5).items_center().text_size(11).text_color(t.dim)
            .child(svg("mods/workspace-chrome/git-branch.svg").size(11).flex_none())
            .child(div().min_w(0).truncate().child(branch))
            .when(worktree, (el) => el.child(div().flex_none().px(5).rounded(4).bg(t.hover).child("worktree")))))
          .when(bits.length > 0, (el) => el.child(div().text_size(11).text_color(t.dim).child(bits.join(" · ")))));
    };

    // Plan usage per account, from the newest numbers any session reported.
    const usage = new Map();
    for (const v of Object.values(stats)) if (v?.account && v.five !== "") usage.set(v.account, v);
    const usageLine = [...usage.entries()].map(([acc, v]) => `${acc} 5h ${v.five}%${v.week !== "" ? ` · 7d ${v.week}%` : ""}`).join("  |  ");

    return v_flex().size_full().min_h(0).bg(t.chrome).border_t(1).border_color(t.border)
      .child(v_flex().px(16).pt(12).pb(6).flex_none().gap(6)
        .child(h_flex().items_center().gap(8)
          .child(div().text_size(11.5).font_medium().text_color(t.dim).child("Agents"))
          .child(div().flex_1())
          .child(div().text_size(11).text_color(t.dim).child(`${total} · ${working} working${needs ? ` · ${needs} need you` : ""}`)))
        .when(Boolean(usageLine), (el) => el.child(div().truncate().text_size(11).text_color(t.dim).child(usageLine)))
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
        const header = h_flex().id(`vhead-${g.id}`).px(8).mt(6).h(30).flex_none().gap(6).items_center().rounded(6)
          .text_size(11.5).font_medium().cursor_pointer().hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => { open ? this.folded.add(g.id) : this.folded.delete(g.id); this.save(); cx.notify(); })
          .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(11).flex_none().text_color(t.dim))
          .child(div().text_color(g.color).child(g.label))
          .child(div().px(6).rounded(8).bg(g.items.length ? g.color + "26" : t.hover).text_color(g.items.length ? g.color : t.dim).child(String(g.items.length)));
        return [header, ...(!open ? [] : g.items.length ? g.items.map((a) => row(a, g)) : [div().px(26).py(4).text_size(11.5).text_color(t.dim).child("Nothing here")])];
      })));
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
