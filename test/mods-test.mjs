// Carrega os mods com "herdr"/"gpui-*" falsos e testa a lógica pura:
// pane-head (nome/endereço do agente) e o patch de PR do space-folders.
// `--live`: também consulta o GitHub (gh) nos PRs reais do pedido.
//   node test/mods-test.mjs [--live]
import { register } from "node:module";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const mods = ["pane-head", "space-folders", "next-needed"].map((m) => join(ROOT, "mods", m, "main.js"));

// Os nomes importados de cada módulo do app, lidos dos próprios mods.
const names = {};
for (const f of mods) {
  for (const [, list, from] of readFileSync(f, "utf8").matchAll(/import\s*\{([^}]*)\}\s*from\s*"([^"]+)"/g)) {
    (names[from] ??= new Set());
    for (const n of list.split(",").map((s) => s.trim()).filter(Boolean)) names[from].add(n);
  }
}
const stub = (from) => [...names[from]].map((n) => (n === "View" ? "export class View {}" : `export const ${n} = () => null;`)).join("\n");
const urls = Object.fromEntries(Object.keys(names).map((k) => [k, "data:text/javascript," + encodeURIComponent(stub(k))]));
register("data:text/javascript," + encodeURIComponent(`
  const urls = ${JSON.stringify(urls)};
  export async function resolve(s, c, next) { return urls[s] ? { url: urls[s], shortCircuit: true } : next(s, c); }
`));

let fail = 0;
const ok = (c, msg) => { console.log(`${c ? "  ok" : "  FALHOU"} — ${msg}`); if (!c) fail++; };

const ph = await import(join(ROOT, "mods/pane-head/main.js"));
const sf = await import(join(ROOT, "mods/space-folders/main.js"));
await import(join(ROOT, "mods/next-needed/main.js"));

const list = [{ address: "t2y", pane: "p1", space_name: "dotfiles-2026" }, { address: "t38", pane: "p9", space_name: "durable-pi" }];
const terms = [{ address: "t2y", name: "superagent" }, { address: "t38", name: null }];
ok(JSON.stringify(ph.agentOf("p1", "t2y", list, terms)) === '{"address":"t2y","name":"superagent"}', "pane-head: agente com name no hc → name + endereço");
ok(ph.agentOf("p9", null, list, terms)?.name === "durable-pi", "pane-head: sem name, usa o space");
ok(ph.agentOf("pX", "tZZ", list, terms) === null, "pane-head: pane sem agente → null (cabeçalho original)");

const t = { ansi1: "red", ansi2: "green", ansi3: "yellow", ansi5: "purple", dim: "dim", foreground: "fg" };
ok(sf.rollup([{ status: "COMPLETED", conclusion: "SUCCESS" }, { state: "SUCCESS" }]) === "success", "rollup: tudo verde → success");
ok(sf.rollup([{ status: "IN_PROGRESS", conclusion: "" }, { status: "COMPLETED", conclusion: "SUCCESS" }]) === "pending", "rollup: um rodando → pending");
ok(sf.rollup([{ status: "IN_PROGRESS" }, { status: "COMPLETED", conclusion: "FAILURE" }]) === "failure", "rollup: um vermelho ganha de rodando → failure");
ok(sf.rollup([{ state: "PENDING" }]) === "pending" && sf.rollup([]) === "none", "rollup: status PENDING → pending; sem checks → none");
ok(sf.prTone(t, { state: "MERGED" }) === "purple", "tom: merged roxo");
ok(sf.prTone(t, { state: "CLOSED" }) === "red" && sf.prTone(t, { state: "OPEN", draft: true, checks: "success" }) === "dim", "tom: fechado vermelho, draft apagado");
ok(["pending", "success", "failure"].map((c) => sf.prTone(t, { state: "OPEN", checks: c })).join() === "yellow,green,red", "tom: aberto por checks amarelo/verde/vermelho");
ok(sf.prTone(t, null) === null, "tom: sem PR → null (ícone cinza de sempre)");

if (process.argv.includes("--live")) {
  const view = (n) => JSON.parse(execFileSync("gh", ["pr", "view", String(n), "--repo", "Mentor-Concursos/mentor-frontend", "--json", "number,state,isDraft,statusCheckRollup"], { encoding: "utf8" }));
  const p108 = view(108), p114 = view(114);
  const tone = (j) => sf.prTone(t, { n: j.number, state: j.state, draft: j.isDraft, checks: sf.rollup(j.statusCheckRollup ?? []) });
  ok(p108.state === "MERGED" && tone(p108) === "purple", `live: PR 108 ${p108.state} → ${tone(p108)}`);
  ok(p114.state !== "MERGED" && ["yellow", "green", "red", "dim", "fg"].includes(tone(p114)), `live: PR 114 ${p114.state}/${sf.rollup(p114.statusCheckRollup ?? [])} → ${tone(p114)}`);
}

console.log(fail ? `FALHOU (${fail})` : "MODS OK");
process.exit(fail ? 1 : 0);
