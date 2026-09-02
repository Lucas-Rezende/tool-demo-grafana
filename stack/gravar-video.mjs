// Grava o vídeo de backup da demonstração.
//
// Lê as sete URLs congeladas de snapshot/favoritos.html, percorre-as com o
// ritmo de uma apresentação e sobrepõe uma legenda em cada passo. O resultado
// é mudo de propósito: a ideia é que alguém do grupo narre por cima, ao vivo,
// se o Docker não subir na sala.

import { chromium } from 'playwright';
import { readFileSync, mkdirSync, readdirSync, renameSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';

const REPO = process.env.REPO_RAIZ || resolve(process.cwd());
const FAVORITOS = join(REPO, 'snapshot', 'favoritos.html');
const SAIDA = join(REPO, 'snapshot');
const TMP = join(SAIDA, '.video-tmp');

const L = 1440, A = 900;

// --- URLs -------------------------------------------------------------------

function lerFavoritos() {
  const html = readFileSync(FAVORITOS, 'utf8');
  const urls = [...html.matchAll(/HREF="([^"]+)"/g)].map((m) => m[1]);
  if (urls.length !== 7) {
    throw new Error(`esperava 7 favoritos em ${FAVORITOS}, encontrei ${urls.length}`);
  }
  return urls;
}

// --- legenda ----------------------------------------------------------------

const CSS = `
#legenda-demo {
  position: fixed; left: 0; right: 0; bottom: 0; z-index: 2147483647;
  background: rgba(17,18,23,.93); color: #fff;
  font: 400 26px/1.35 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  padding: 20px 34px 24px; box-sizing: border-box;
  border-top: 4px solid #ff8833;
  transition: opacity .35s ease; opacity: 0;
}
#legenda-demo.visivel { opacity: 1; }
#legenda-demo .passo {
  display: block; font-size: 15px; letter-spacing: .13em;
  text-transform: uppercase; color: #ff8833; margin-bottom: 7px; font-weight: 600;
}
#legenda-demo .sub {
  display: block; font-size: 20px; color: #c9ccd4; margin-top: 8px;
}`;

async function legenda(page, passo, texto, sub) {
  await page.evaluate(
    ({ css, passo, texto, sub }) => {
      if (!document.getElementById('legenda-demo-css')) {
        const s = document.createElement('style');
        s.id = 'legenda-demo-css';
        s.textContent = css;
        document.head.appendChild(s);
      }
      let el = document.getElementById('legenda-demo');
      if (!el) {
        el = document.createElement('div');
        el.id = 'legenda-demo';
        document.body.appendChild(el);
      }
      el.innerHTML =
        (passo ? `<span class="passo">${passo}</span>` : '') +
        texto +
        (sub ? `<span class="sub">${sub}</span>` : '');
      requestAnimationFrame(() => el.classList.add('visivel'));
    },
    { css: CSS, passo, texto, sub: sub || '' },
  );
}

async function limparLegenda(page) {
  await page.evaluate(() => {
    const el = document.getElementById('legenda-demo');
    if (el) el.classList.remove('visivel');
  }).catch(() => {});
}

// --- utilidades -------------------------------------------------------------

const pausa = (ms) => new Promise((r) => setTimeout(r, ms));

// O Grafana só desenha o painel quando ele entra na área visível. Sem esta
// rolagem, metade do dashboard aparece em branco no vídeo.
async function acordarPaineis(page) {
  await page.mouse.move(L / 2, A / 2);
  for (const d of [500, 500, 500, -600, -600, -400]) {
    await page.mouse.wheel(0, d);
    await pausa(320);
  }
  await pausa(1200);
}

async function rolar(page, delta, passos = 6, intervalo = 380) {
  await page.mouse.move(L / 2, A / 2);
  for (let i = 0; i < passos; i++) {
    await page.mouse.wheel(0, delta);
    await pausa(intervalo);
  }
}

async function abrir(page, url) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await pausa(4500);
}

// --- roteiro ----------------------------------------------------------------

async function main() {
  const urls = lerFavoritos();
  rmSync(TMP, { recursive: true, force: true });
  mkdirSync(TMP, { recursive: true });

  // Usa um navegador já instalado na máquina, em vez de baixar o Chromium do
  // Playwright (~150 MB). Se nenhum dos dois existir, cai no Chromium que o
  // `npx playwright install chromium` teria baixado.
  let browser;
  for (const channel of ['chrome', 'msedge', undefined]) {
    try {
      browser = await chromium.launch({ channel, headless: true });
      break;
    } catch (e) {
      if (channel === undefined) {
        throw new Error(
          'nenhum navegador disponível. Rode: npx playwright install chromium',
        );
      }
    }
  }
  const ctx = await browser.newContext({
    viewport: { width: L, height: A },
    recordVideo: { dir: TMP, size: { width: L, height: A } },
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();

  // --- abertura
  await abrir(page, urls[0]);
  await acordarPaineis(page);
  await legenda(
    page,
    'Tool Demo · DCC/UFMG',
    'Grafana — observabilidade como apoio à manutenção de software',
    'Gravação de apoio. Dados de uma janela real de 45 minutos, congelada.',
  );
  await pausa(7000);

  // --- 1. dashboard
  await legenda(
    page,
    'Passo 1 de 7 — Métrica',
    'O dashboard: cerca de 5% das requisições falham',
    'Overall Error %age. Existe defeito, e ele não é raro.',
  );
  await pausa(7000);

  await legenda(
    page,
    'Passo 1 de 7 — Métrica',
    'O erro está espalhado pelos cinco endpoints',
    'Todos na mesma faixa. Qual está no topo muda conforme o instante: é ruído, não sinal.',
  );
  await pausa(8000);

  await rolar(page, 420, 5);
  await legenda(
    page,
    'Passo 1 de 7 — Métrica',
    'Segundo fato: o percentil 95 está em ~15 segundos',
    'A aplicação está lenta. Erro e lentidão são, por enquanto, dois fatos separados.',
  );
  await pausa(8000);
  await rolar(page, -420, 6);

  // --- 2. variável de template
  await abrir(page, urls[1]);
  await acordarPaineis(page);
  await legenda(
    page,
    'Passo 2 de 7 — Hipótese 1',
    'Filtrando por um endpoint: a hipótese cai',
    'A variável de template reescreve todas as consultas da tela. Não há endpoint culpado.',
  );
  await pausa(9000);

  // --- 3. logs
  await abrir(page, urls[2]);
  await legenda(
    page,
    'Passo 3 de 7 — Log',
    'Loki: as linhas de erro trazem o traceId',
    '{job="alloy"} | logfmt | status="Error" — o Loki indexa rótulos, não o texto da linha.',
  );
  await pausa(9000);
  await rolar(page, 300, 3);
  await pausa(4000);

  // --- 4. Ok vs Error
  await abrir(page, urls[3]);
  await pausa(3000);
  await legenda(
    page,
    'Passo 4 de 7 — Hipótese 2',
    'As requisições que falham são as lentas?',
    'quantile_over_time sobre o campo dur, separado por status. Log virou série temporal.',
  );
  await pausa(8000);
  await legenda(
    page,
    'Passo 4 de 7 — Hipótese 2',
    'Não são. As duas linhas se sobrepõem',
    'Falhar e demorar são problemas independentes deste sistema.',
  );
  await pausa(9000);

  // --- 5. trace
  await abrir(page, urls[4]);
  await pausa(3000);
  await legenda(
    page,
    'Passo 5 de 7 — Trace',
    'A cascata de spans, no Tempo',
    'A mesma requisição, agora serviço por serviço.',
  );
  await pausa(6000);
  await rolar(page, 330, 4);
  await legenda(
    page,
    'Passo 5 de 7 — Trace',
    'Os middlewares levam microssegundos',
    'O código da aplicação não é o gargalo. Quase todo o tempo está em um único span.',
  );
  await pausa(8000);

  // Clicar no span do banco, que é onde o diagnóstico fecha.
  try {
    await page.getByText('pg.query:INSERT postgres', { exact: false }).first().click({ timeout: 8000 });
    await pausa(2500);
    // O painel de detalhe abre logo abaixo da linha clicada, exatamente onde
    // fica a legenda. Sem esta rolagem, o quadro mais importante do vídeo sai
    // coberto pela própria legenda.
    await rolar(page, 260, 3, 420);
    await pausa(1500);
  } catch {
    // Se o clique falhar, o vídeo segue: a cascata sozinha já mostra o span.
  }
  await legenda(
    page,
    'Passo 5 de 7 — Trace',
    'null value in column "name" violates not-null constraint',
    'INSERT INTO owlbear(name) VALUES ($1) — a validação só existe no schema do banco.',
  );
  await pausa(12000);

  // --- 6. alertas
  await abrir(page, urls[5]);
  await pausa(3500);
  await legenda(
    page,
    'Passo 6 de 7 — Alerta',
    'As mesmas consultas viram regras de alerta',
    'Uma regra avalia o presente, a cada 10 s. Um painel consulta o intervalo que você pedir.',
  );
  await pausa(9000);

  // --- 7. regra sintética
  await abrir(page, urls[6]);
  await pausa(3000);
  await rolar(page, 200, 2);
  await legenda(
    page,
    'Passo 7 de 7 — Alerta',
    'Regra sintética: Normal → Pending → Alerting',
    'vector(1) > 0 não depende de dado nenhum. Existe só para tornar o ciclo visível.',
  );
  await pausa(10000);

  // --- fecho
  await legenda(
    page,
    'Fim da demonstração',
    'Métrica → log → trace, até o span e a dependência culpada',
    'Daqui em diante — qual função dentro do span consome o tempo — já é profiling.',
  );
  await pausa(9000);
  await limparLegenda(page);
  await pausa(1500);

  await ctx.close();
  await browser.close();

  const bruto = readdirSync(TMP).find((f) => f.endsWith('.webm'));
  if (!bruto) throw new Error('o Playwright não gerou o arquivo de vídeo');
  const destino = join(SAIDA, 'demo-backup.webm');
  rmSync(destino, { force: true });
  renameSync(join(TMP, bruto), destino);
  rmSync(TMP, { recursive: true, force: true });
  console.log(destino);
}

main().catch((e) => {
  console.error('ERRO:', e.message);
  process.exit(1);
});
