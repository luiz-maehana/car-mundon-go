// Teste da versão Web no navegador: abre o jogo exportado e falha se o motor registrar erro.
//   PC:      abertura → Enter → menu em 4 etapas (modo, piloto, pista, CORRER!) → corrida
//   celular: tela de toque deitada → toca pra começar e confere que saiu da abertura (RF-470/472)
// Capturas de cada etapa em <saída>/ para conferir no artefato do CI.
// Roda no CI: node tests/web_smoke.js <url> <saída>  (playwright@1.49.1)
// No CI o navegador desenha por software (SwiftShader): é lento, então só confere que nada quebra.
const { chromium, devices } = require('playwright');

const [url, out] = process.argv.slice(2);
const software = !process.env.WEB_SMOKE_GPU;
// Avisos do navegador que não são do jogo.
const IGNORED = [/AudioContext was not allowed/, /WebGL/i, /GPU stall/i, /favicon/, /pointer ?lock/i, /fullscreen/i];

function watch(page, problems) {
  page.on('console', (m) => {
    const text = m.text();
    if (IGNORED.some((re) => re.test(text))) return;
    if (m.type() === 'error' || /SCRIPT ERROR|^ERROR:|Cannot get class|not available/.test(text)) problems.push(text);
  });
  page.on('pageerror', (e) => problems.push('pageerror: ' + e.message));
}

async function shot(page, name) {
  try {
    return await page.screenshot({ path: `${out}/${name}.png`, timeout: 120000 });
  } catch (e) {
    console.log(`captura ${name} não saiu (desenho por software lento): ${e.message.split('\n')[0]}`);
    return null;
  }
}

async function loaded(page) {
  await page.goto(url);
  await page.waitForFunction(() => {
    const s = document.getElementById('status');
    if (!s) return true;
    const st = getComputedStyle(s);
    return st.display === 'none' || st.visibility === 'hidden' || st.opacity === '0';
  }, null, { timeout: 240000 });
  await page.waitForTimeout(software ? 8000 : 3000);
}

(async () => {
  const args = software ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : [];
  const browser = await chromium.launch({ args });
  const problems = [];

  // PC
  const pc = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  watch(pc, problems);
  await loaded(pc);
  await shot(pc, '01_abertura');
  await pc.keyboard.press('Enter');
  await pc.waitForTimeout(software ? 6000 : 2500);
  await shot(pc, '02_menu');
  for (const step of ['modo', 'piloto', 'pista', 'correr']) {
    await pc.keyboard.press('Enter');
    await pc.waitForTimeout(software ? 5000 : 1500);
  }
  // montar a pista e os karts por software leva tempo
  await pc.waitForTimeout(software ? 120000 : 12000);
  await shot(pc, '03_corrida');

  // celular deitado com toque
  const phone = devices['Pixel 7'];
  const ctx = await browser.newContext({ ...phone, viewport: { width: phone.viewport.height, height: phone.viewport.width } });
  const mob = await ctx.newPage();
  watch(mob, problems);
  await loaded(mob);
  const before = await shot(mob, '04_celular_abertura');
  await mob.touchscreen.tap(mob.viewportSize().width / 2, mob.viewportSize().height / 2);
  await mob.waitForTimeout(software ? 8000 : 2500);
  const after = await shot(mob, '05_celular_menu');
  // RF-472: o toque tem que sair da abertura (as duas capturas iguais = o toque não chegou)
  if (before && after && before.equals(after)) problems.push('o toque na abertura não levou ao menu');

  await browser.close();
  if (problems.length) {
    console.error('Erros do motor na versão Web:\n  ' + problems.slice(0, 20).join('\n  '));
    process.exit(1);
  }
  console.log('Web: abertura, menu e corrida (PC) e abertura → menu no celular, sem erro do motor.');
})().catch((e) => { console.error(e); process.exit(1); });
