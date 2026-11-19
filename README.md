# Car Mundon'GO

Kart arcade 3D (Godot 4.7, GDScript) com a turma virando camundongos pilotos: 9 pistas em 3 copas,
8 pilotos com poder próprio, itens, looping, andares, buracos, atalhos e até 4 jogadores na mesma tela.

## Jogar

- **No navegador (PC ou celular):** https://luiz-maehana.github.io/car-mundon-go/
  No celular, jogue com o aparelho deitado: os controles aparecem na tela (direcional à esquerda;
  DRIFT, ITEM, PODER e FREIO à direita; o acelerador é automático e pode ser desligado em
  Configurações → Jogo). Toque em **TELA CHEIA** na abertura. A versão web começa com o gráfico no Baixo.
- **No PC:** abra o projeto no Godot (abaixo) ou exporte o executável.

## Rodando

1. Abra a pasta no Godot **4.7.x** (Project Manager → Import → `project.godot`).
2. F5 roda a abertura (`scenes/intro.tscn`) → menu em etapas (modo, piloto, pista, ajustes) → corrida.

| Teclado (J1) | Controle | Ação |
|---|---|---|
| W / S | A / B (ou gatilhos) | Acelerar / frear e ré |
| A / D | analógico ou direcional | Virar |
| Espaço / Shift esq. | RB | Drift (no ar: manobra) |
| E / Ctrl esq. | LB / X | Usar item |
| Q | Y | Poder do piloto (com 10 queijinhos) |
| Esc | Start | Pausar |
| M | — | Liga/desliga o som |

J2 joga nas setas (Shift dir. = drift, Enter = item, 1 do teclado numérico = poder) ou no controle 2;
J3 e J4 nos controles 3 e 4. Todas as teclas (menos Esc, M e R) podem ser trocadas em
Configurações → Controles.

**Como jogar:** acelere quando aparecer o **2** na contagem pra sair com turbo (antes disso, queima).
Segure o drift na curva e solte pro mini-turbo (faísca azul → laranja → roxa). Setas no chão e andar
colado atrás de alguém (vácuo) também dão turbo. Pegue caixas de item e queijinhos: cada queijinho
deixa o kart 1% mais rápido e, com **10**, o poder do seu piloto fica pronto (recarga de 20 s).
Caiu num buraco ou ficou preso? Os balões te devolvem pra pista. No **Grand Prix** você escolhe uma
copa e soma pontos (15·12·10·8·6·4·2·1) pelas pistas dela.

## Desenvolvimento (spec-driven)

1. Escreva/atualize o requisito em [SPEC.md](SPEC.md) (ID `RF-xx` + critério de aceite `CA-xx`).
2. Se der pra automatizar, adicione o teste em `tests/suites/` (e a chamada em `tests/run_tests.gd`).
3. Implemente, rode os testes, marque `[x]` na spec.

Onde cada coisa mora e como criar um perigo, poder ou pista novos: SPEC §7 (Arquitetura).

## Testes

```sh
godot --headless --path . --import                            # primeira vez (gera .godot/)
godot --headless --path . --script res://tests/run_tests.gd   # código de saída 0 = OK
```

Os testes não tocam nas configurações nem nos recordes reais (usam arquivos próprios em `user://`).
Capturas para revisão visual: `godot --path . --script tools/screenshot_steps.gd -- <pasta>` (menu),
`tools/screenshot_track.gd -- <pasta> <pista>` (pontos de uma pista), `tools/screenshot_touch.gd`
(controles de toque; com `--rendering-method gl_compatibility` mostra como fica no navegador).

## Executável (Windows)

```sh
godot --headless --path . --export-release "Windows Desktop" export/windows/CarMundonGO.exe
```

Gera `CarMundonGO.exe` + `CarMundonGO.pck` (os dois juntos). O exe é o executável oficial do Godot
sem modificação, o que o Controle Inteligente de Aplicativos do Windows deixa rodar.

## Estrutura

```
assets/chars/        ilustrações dos pilotos (a turma) — NÃO fazem parte da licença MIT
assets/ui/           arte da abertura e imagem de inicialização (idem)
assets/audio/        sons e músicas CC0 (ver CREDITS.md)
assets/kenney/       modelos, interface e fonte CC0 da Kenney, com as licenças em licenses/
scenes/              abertura, menu, corrida, pódio do GP
scripts/             jogo (camadas descritas no SPEC §7): track_*, kart_*, race_*, menu_*,
                     hazards/ (perigos da pista), powers/ (poderes), track_data.gd (pistas)
shaders/             céu, fundo do menu, escudo, cor do kart
tests/               run_tests.gd + suites/ (testes headless) e web_smoke.js (versão web no navegador)
tools/               capturas, medições de pista e IA, check_publish.sh (não vão para o jogo exportado)
```

## Repositório público: o que nunca deve ser commitado

O `.gitignore` já bloqueia os casos comuns, mas revise `git diff --cached` antes de cada commit.

- `.godot/` (cache com caminhos locais) e builds (`/export/`, `/build/`, `*.exe`, `*.pck`).
- Arquivos `.env`, keystores, certificados e chaves; senha ou chave em `export_presets.cfg`.
- Tokens de API, e-mails ou dados pessoais em scripts e configurações.
- Assets sem licença verificada e registrada no [CREDITS.md](CREDITS.md).

Configurações e recordes ficam em `user://` (no Windows, `%APPDATA%\Godot\app_userdata\Car'mundon'GO!\`),
fora da pasta do projeto. Eles são lidos com segurança (`scripts/safe_cfg.gd`): um arquivo trocado
com objeto ou script embutido é recusado.

### Antes de publicar (checklist)

Automático (o GitHub Actions também roda os dois antes de publicar):

```sh
sh tools/check_publish.sh                                       # arquivos proibidos, caminhos locais, e-mails, segredos, arquivos > 10 MB, licenças de terceiros
godot --headless --path . --script res://tests/run_tests.gd     # todos os testes passando
```

Manual:

- [ ] `git status` e `git diff --cached`: só entra o que você quer publicar.
- [ ] Todo asset novo de terceiros está no [CREDITS.md](CREDITS.md), com a licença conferida.
- [ ] Build exportado e aberto uma vez (ver "Executável").

## Créditos

Modelos, interface e fonte: Kenney (CC0). Sons e músicas: OpenGameArt, todos CC0 (Kenney,
rubberduck, domasx2, IgnasD, MintoDog, Centurion_of_war, cynicmusic, Joth, Fupi, 3xBlast,
Zane Little Music e outros). Detalhes e links: [CREDITS.md](CREDITS.md).

## Licença

O código (scripts, cenas, shaders, testes e ferramentas) está sob a licença MIT ([LICENSE](LICENSE)).
As ilustrações dos pilotos e a arte da abertura retratam pessoas reais (a turma) e **não** fazem
parte da licença MIT: não reutilize. Os assets de terceiros mantêm suas próprias licenças
(ver [CREDITS.md](CREDITS.md)).
