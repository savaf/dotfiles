import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, spaces, panes, props, run, setAgentOrder } from "herdr";

const C = { ink: "#e8e9eb", muted: "#a9adb3", line: "#2a2d32", bg: "#131619", white: "#1b1e22", violet: "#8b7df0" };
const STATES = [
  { key: "blocked", label: "Needs you", color: "#e0a04a", wash: "#3a2a10" },
  { key: "working", label: "Working", color: "#8b7df0", wash: "#2a2650" },
  { key: "done", label: "Done", color: "#45b891", wash: "#12302a" },
  { key: "idle", label: "Idle", color: "#8b9096", wash: "#26292e" },
];
const dot = (color, size = 7) => div().size(size).rounded(size).bg(color).flex_none();
const icon = (program, size = 18) => program?.icon
  ? (program.tint ? svg(program.icon).text_color(C.ink) : image(program.icon)).size(size).flex_none()
  : div().size(size).rounded(4).bg(C.violet);
const chip = (label, selected = false) => h_flex().h(27).px(11).gap(7).items_center().rounded(6)
  .bg(selected ? "#2a2650" : C.white).border(1).border_color(selected ? "#4a4390" : C.line)
  .text_size(11).text_color(selected ? C.violet : "#a9adb3").child(label);

export default class Board extends View {
  init(_p, cx) {
    this.observed = {};
    cx.timer.every(30000, (cx) => cx.notify());
  }
  card(a, state) {
    const old = this.observed[a.address];
    if (!old || old.status !== a.status) this.observed[a.address] = { status: a.status, at: Date.now() };
    const mins = Math.floor((Date.now() - this.observed[a.address].at) / 60000);
    const elapsed = mins ? `${mins}m observed` : "<1m observed";
    return h_flex().id(`agent-${a.address}`).w_full().h(86).flex_none().rounded(7).overflow_hidden()
      .bg(C.white).border(1).border_color(C.line).cursor_pointer().hover(s => s.border_color(state.color))
      .on_click(() => run("agent.focus", { terminal: a.address }))
      .child(div().w(3).h_full().bg(state.color).flex_none())
      .child(v_flex().flex_1().min_w(0).px(12).py(10).gap(7)
        .child(h_flex().gap(7).items_center().text_size(10).text_color(C.muted)
          .child(icon(a.program, 15)).child(div().truncate().child(a.program.name)).child(div().flex_1()).child(div().child(a.address)))
        .child(div().text_size(13).font_semibold().text_color(C.ink).truncate().child(a.tab_name))
        .child(h_flex().items_center().justify_between().text_size(10).text_color(C.muted)
          .child(div().truncate().child(a.space_name)).child(div().flex_none().child(elapsed))));
  }
  render() {
    const role = props()?.role;
    const list = agents();
    const active = spaces().find(s => s.active);
    if (role === "header") return v_flex().size_full().bg(C.white).px(26).justify_center().gap(12)
      .child(h_flex().items_center().gap(10)
        .child(h_flex().gap(3).items_center().children([17, 12, 20].map(h => div().w(5).h(h).rounded(2).bg(C.violet))))
        .child(div().text_size(20).font_semibold().text_color(C.ink).child(active?.name ?? "Project board"))
        .child(div().text_size(19).text_color("#5d6168").child("/"))
        .child(div().text_size(14).text_color(C.muted).child("Agent board"))
        .child(div().flex_1())
        .child(div().text_size(11).text_color(C.muted).child(`${list.length} agents across ${spaces().length} spaces`)))
      .child(h_flex().gap(7).items_center().child(chip("Board", true)).child(chip("All spaces"))
        .child(chip("All agents")).child(div().flex_1()).child(dot("#45b891", 6))
        .child(div().text_size(10).text_color(C.muted).child("Live updates")));
    if (role === "terminals") {
      const tab = active?.tabs.find(t => t.active);
      return h_flex().size_full().px(16).items_center().gap(8).bg(C.white)
        .child(dot(C.violet)).child(div().text_size(12).font_semibold().text_color(C.ink).child("Live workspace"))
        .child(div().text_size(11).text_color(C.muted).child(`${active?.name ?? ""} / ${tab?.name ?? ""}`))
        .child(div().flex_1()).child(div().text_size(10).text_color(C.muted).child("TERMINALS"));
    }
    if (role === "pane") {
      const p = panes().find(p => p.pane === props().pane);
      return h_flex().size_full().px(13).items_center().gap(7).bg("#1b1e22").border_b(1).border_color(C.line)
        .child(icon(p?.program, 14)).child(div().text_size(11).text_color(C.ink).child(p?.program?.name ?? "Terminal"))
        .child(div().flex_1()).child(dot(STATES.find(s => s.key === p?.status)?.color ?? C.muted, 6));
    }
    setAgentOrder(STATES.flatMap(s => list.filter(a => a.status === s.key).map(a => a.address)));
    return h_flex().size_full().px(24).py(17).gap(16).bg(C.bg).children(STATES.map(state => {
      const cards = list.filter(a => a.status === state.key);
      return v_flex().flex_1().min_w(0).h_full().gap(9)
        .child(h_flex().h(27).flex_none().items_center().gap(8).px(3)
          .child(dot(state.color, 8)).child(div().text_size(13).font_semibold().text_color(C.ink).child(state.label))
          .child(div().px(6).py(2).rounded(4).bg(state.wash).text_size(10).text_color(state.color).child(String(cards.length)))
          .child(div().flex_1()).child(div().text_color("#8b9096").text_size(17).child("+")))
        .child(v_flex().flex_1().min_h(0).overflow_y_scrollbar().gap(9).children(cards.map(a => this.card(a, state))));
    }));
  }
}
