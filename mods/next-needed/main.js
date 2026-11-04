// Pula para o próximo agente que precisa de você. Aberto por um atalho
// (keys.json: "mod.open:next-needed"), fecha o próprio overlay na hora e
// foca o agente: primeiro os "blocked" (esperando resposta), depois os
// "done" (terminaram enquanto você não olhava; viram "idle" quando você
// olha, então saem da fila sozinhos). Dentro de cada grupo segue a ordem de
// agents() (space, tab, pane) a partir do agente focado, dando a volta:
// apertar de novo passa para o próximo blocked em vez de ficar no mesmo.
// Nenhum esperando: só um aviso.

import { View, div } from "gpui-kit";
import { agents, run, props, closeOverlay, notify } from "herdr";

const URGENCY = ["blocked", "done"];

export function pick(list) {
  const at = list.findIndex((a) => a.focused);
  // a partir do focado, sem ele: ele mesmo só se for o único da fila
  const order = at < 0 ? list : [...list.slice(at + 1), ...list.slice(0, at + 1)];
  for (const status of URGENCY) {
    const hit = order.find((a) => a.status === status);
    if (hit) return hit;
  }
  return null;
}

export default class NextNeeded extends View {
  init(_props, _cx) {
    // só age aberto como overlay (o atalho); `herdr-app check` monta sem props
    const overlay = props()?.overlay;
    if (!overlay) return;
    closeOverlay(overlay);
    const next = pick(agents());
    if (next) run("agent.focus", { terminal: next.address });
    else notify({ title: "Nenhum agente precisa de você", level: "info", timeout: 2000 });
  }

  render() {
    return div();
  }
}
