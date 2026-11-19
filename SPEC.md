# Car Mundon'GO — Especificação (MVP)

> Spec viva do projeto. Toda feature nova entra aqui **antes** do código, com ID e critério de aceite.
> Status: `[x]` feito · `[ ]` pendente · `[~]` parcial.

## 1. Visão

Jogo de corrida de kart arcade 3D (gênero kart racer: drift com mini-turbo, caixas de item, 8 pilotos), em que os pilotos são a nossa turma. Objetivo do MVP: **uma corrida completa, divertida e jogável do menu até o pódio**, para validar a sensação de pilotagem antes de investir em arte, pistas e multiplayer.

- Engine: **Godot 4.7** (GDScript). Renderer **Forward+** no PC (v0.9), com opção de gráficos BAIXO; a web usará Compatibility.
- Arte do MVP: 100% procedural (primitivas + cores). Nenhum asset externo obrigatório.
- Idioma da interface: português.

## 2. Escopo

### Dentro do MVP
- Menu de seleção de piloto (8 pilotos) e de número de voltas.
- 1 pista fechada ("Circuito Queijo Suíço") com asfalto, zebras, grama lenta e muros.
- 1 jogador humano vs 7 pilotos controlados por IA.
- Drift com mini-turbo, 3 itens, contagem regressiva, voltas, posição, minimapa, resultado.

### Fora do MVP (ver Roadmap §9)
Multiplayer local/online, mais pistas, modelos 3D/rostos reais, áudio, Grand Prix, rampas/elevação.

## 3. Pilotos

Stats de 1 a 5, soma 12 em todos (balanceados). **Valores provisórios** — ajustar com a turma em `scripts/characters.gd`.

| ID | Nome | Cor | Velocidade | Aceleração | Controle | Peso |
|---|---|---|---|---|---|---|
| fejaum | FeJauM | laranja | 4 | 3 | 3 | 2 |
| burcca | Burcca | vermelho | 5 | 2 | 2 | 3 |
| mugurin | Mugurin | verde | 2 | 4 | 4 | 2 |
| telles | Telles | azul | 3 | 3 | 3 | 3 |
| ortiz | Ortiz | roxo | 4 | 2 | 2 | 4 |
| shinando | Shinando | amarelo | 3 | 4 | 3 | 2 |
| nanni | Nanni | rosa | 2 | 5 | 3 | 2 |
| digao | Digão | branco | 3 | 2 | 2 | 5 |

Conversão de stat para física (em `kart.gd`):
- Velocidade máx = `22 + 1.6 × vel` m/s
- Aceleração = `9 + 2.2 × ace` m/s²
- Giro = `1.55 + 0.16 × ctr` rad/s
- Peso = `1 + pes` (quem é mais pesado empurra mais nas batidas)

**Rosto opcional:** se existir `assets/faces/<id>.png`, a foto aparece como um *sprite* em cima do capacete do piloto.

## 4. Requisitos funcionais

### Menu
- [x] **RF-01** Tela inicial mostra os 8 pilotos em cards com nome, cor e barras de stats.
- [x] **RF-02** Seleção por mouse (clique seleciona, clique de novo inicia) e teclado (setas + Enter).
- [x] **RF-03** Escolha de voltas: 1, 2, 3 (padrão) ou 5.

### Pilotagem
- [x] **RF-10** Acelerar, frear/ré e virar. Virar exige velocidade (kart parado não gira).
- [x] **RF-11** Grama (fora do asfalto) limita a velocidade a 50% (exceto com turbo).
- [x] **RF-12** Muros impedem sair da pista; bater raspando perde velocidade proporcional ao impacto.
- [x] **RF-13** **Drift:** segurar o botão de drift virando acima de 12 m/s faz o kart pular e derrapar na direção escolhida. Virar pra dentro fecha a curva, pra fora abre.
- [x] **RF-14** **Mini-turbo:** ao soltar o drift, ≥0.7 s de drift = turbo azul curto (0.6 s); ≥1.5 s = turbo laranja (1.1 s). Faíscas mostram a carga.
- [x] **RF-15** Batida entre karts empurra conforme o peso.
- [x] **RF-16** Kart da IA preso (parado > 2.5 s) ou qualquer kart fora dos limites é reposicionado no centro da pista. (v0.25: virou o resgate com balões, RF-310.)

### Itens
- [x] **RF-20** 3 fileiras de 4 caixas "?" na pista. Passar por uma dá um item (se o slot estiver vazio); a caixa volta em 3 s.
- [x] **RF-21** Sorteio depende da posição: quem está atrás ganha mais turbo e bomba, quem lidera ganha mais casca.
- [x] **RF-22** **Turbo:** 1.3 s de velocidade +30%.
- [x] **RF-23** **Casca:** largada atrás do kart; quem passa em cima roda (perde controle 1.1 s e 65% da velocidade).
- [x] **RF-24** **Bomba:** projétil reto pra frente; explode no muro, em outro kart (que roda) ou em uma casca (as duas somem).

### Corrida
- [x] **RF-30** Grid de largada 2×4 atrás da linha; jogador larga em último.
- [x] **RF-31** Contagem 3-2-1-VAI! no centro da tela (cada número entra grande e encolhe; VAI! em verde). Ninguém se move antes do VAI.
- [x] **RF-32** Volta só conta andando pra frente (progresso contínuo ao longo da pista; andar de ré desconta).
- [x] **RF-33** Posição em tempo real: quem terminou ordena por tempo, o resto por progresso.
- [x] **RF-34** Ao terminar, o jogador vira piloto automático; resultado aparece 3 s depois com posição e tempo de todos.
- [x] **RF-35** `R` reinicia a corrida, `Esc` volta ao menu.

### IA
- [x] **RF-40** IA segue a linha central olhando à frente (mais longe quanto mais rápida), trocando de faixa aleatoriamente.
- [x] **RF-41** IA faz drift nas curvas e ganha mini-turbo pelas mesmas regras do jogador.
- [x] **RF-42** IA usa itens: turbo em reta, casca depois de alguns segundos, bomba quando há kart na mira.
- [x] **RF-43** *Rubber band* leve: IA muito à frente do jogador fica até 6% mais lenta, muito atrás fica até 8% mais rápida.

### HUD
- [x] **RF-50** Volta atual/total, cronômetro, posição (ex.: `3º/8`), slot de item, minimapa com todos os karts.
- [x] **RF-51** Mensagens: contagem, "VOLTA 2", "VOLTA FINAL!", "CONTRAMÃO!", "CHEGOU!".

### Multiplayer local — tela dividida (v0.2)
- [x] **RF-60** Menu tem seletor de jogadores: 1 a 4. Os humanos escolhem o piloto em sequência ("JOGADOR 2, escolha"); um piloto já escolhido fica marcado `P1`…`P4` e não pode ser repetido. `Backspace` desfaz a última escolha.
- [x] **RF-61** Tela dividida: 2 jogadores = em cima/embaixo; 3–4 jogadores = grade 2×2 (com 3, o 4º quadro mostra um minimapa grande).
- [x] **RF-62** Cada jogador tem câmera e HUD próprios (volta, posição, item, mensagens). O HUD escala com o tamanho do quadro.
- [x] **RF-63** O nome do próprio piloto fica escondido só na câmera dele; os outros veem.
- [x] **RF-64** Os humanos largam no fundo do grid; o restante dos 8 lugares é IA.
- [x] **RF-65** O resultado aparece quando **todos os humanos** terminam (ou 3 s depois do último). Quem termina antes vira piloto automático.
- [x] **RF-66** O *rubber band* da IA usa como referência o humano mais adiantado.
- [x] **RF-67** Com 1 jogador, WASD e setas controlam o mesmo kart (como no MVP).

### Arte dos camundongos (v0.3 — substitui as fotos)
- [x] **RF-70** Cada piloto tem ilustração de camundongo de corpo inteiro. `tools/process_characters.gd` remove o fundo e gera `assets/chars/<id>.png` (corpo) e `assets/chars/<id>_head.png` (busto com orelhas).
- [x] ~~**RF-71** busto como cabeça do piloto no kart~~ → removido no v0.6 (feedback: caras só no mapa/HUD).
- [x] **RF-72** Os cards do menu mostram o busto.
- [x] **RF-73** O HUD mostra o busto do jogador ao lado da posição; o resultado tem **pódio** com o top 3 de corpo inteiro e o busto de cada piloto na lista.
- [x] **RF-74** Sem arte, o piloto usa capacete colorido com orelhinhas (o jogo não quebra).

### Áudio, largada turbo e pause (v0.4)
- [x] **RF-80** Todo som é sintetizado em código (`scripts/sfx.gd`), sem arquivos de áudio: bipes da contagem, "VAI!", caixa de item, turbo, casca, bomba, rodada, volta, chegada.
- [x] **RF-81** Motor de cada jogador humano com tom que sobe com a velocidade (e mais agudo no turbo).
- [x] **RF-82** Música chiptune em loop no menu e na corrida (gerada uma vez e reaproveitada). `M` liga/desliga todo o som.
- [x] **RF-83** Sons de eventos só tocam quando envolvem um jogador humano (os da IA não poluem o áudio).
- [x] **RF-85** **Largada turbo:** começar a segurar o acelerador quando faltam entre 1.6 s e 0.6 s pro VAI dá 1 s de turbo ("LARGADA TURBO!").
- [x] **RF-86** **Queimou:** segurar o acelerador desde antes de 1.6 s deixa o kart 0.7 s sem acelerar ("QUEIMOU!"). Soltar antes do VAI zera.
- [x] **RF-87** A IA acerta a largada turbo 35% das vezes.
- [x] **RF-90** **Pause:** `Esc` (ou Start no controle) pausa com menu Continuar / Reiniciar / Menu; `Esc` de novo continua. Na tela de resultado, `Esc` vai pro menu.

### Tela de abertura (v0.5)
- [x] **RF-100** O jogo abre numa tela de título com a arte `assets/ui/intro.jpg` cobrindo a tela inteira (sem distorcer, cortando as sobras) e a música tocando.
- [x] **RF-101** Um aviso "APERTE ENTER PARA COMEÇAR" pisca embaixo; qualquer tecla, clique ou botão de controle vai pro menu (Esc fecha o jogo).
- [x] **RF-102** A arte entra com um *fade-in* rápido e um leve zoom lento (efeito "vivo").
- [x] **RF-103** No menu, `Esc` volta pra tela de abertura.

### Ajustes do primeiro playtest (v0.6)
- [x] **RF-110** Volume: todo som gerado é normalizado (efeitos com pico 0.9, música 0.75) e o master tem limitador em -0.5 dB. Pico medido na corrida entre -6 e -0.5 dB (antes: -11 a -15 dB, "som baixo").
- [x] **RF-111** (substituído pelo RF-171) No kart, o piloto é um camundongo de capacete na cor do piloto, com orelhonas e nome em cima. A arte dos rostos **não** aparece na pista.
- [x] **RF-112** O minimapa mostra o busto de cada piloto no lugar do pontinho (o jogador com borda branca, por cima dos outros).
- [x] **RF-113** O HUD tem a lista de posições ao vivo (busto + nome, 1º a 8º) na lateral esquerda; a linha do jogador fica destacada.

### Mais pistas (v0.7)
- [x] **RF-120** Pistas são dados (`TRACKS` em `track.gd`): nome, pontos de controle e tema (céu, chão, grama, muros, sol, decoração).
- [x] **RF-121** Três pistas:
  - **Circuito Queijo Suíço** — dia, gramado com pinheiros (a original).
  - **Deserto do Parmesão** — fim de tarde, areia, muros laranja/creme, cactos.
  - **Cozinha à Meia-Noite** — noite, piso escuro, muros roxo/ciano, postes com luz.
- [x] **RF-122** O menu tem o botão `PISTA: <nome>` que alterna entre as pistas; a escolha fica salva no `Game` entre corridas.

### HUD, física e gameplay (v0.8)
**HUD**
- [x] **RF-130** Itens com ícone desenhado (turbo = setas laranja, casca = banana amarela, bomba = bola preta com pavio). Ao pegar a caixa, uma **roleta** de 1 s gira os ícones; o item só pode ser usado depois dela (vale pra IA também).
- [x] **RF-131** Velocímetro em km/h no canto inferior direito (laranja durante turbo) com a barra de carga do drift na cor do nível (azul/laranja/roxo).
- [x] **RF-132** A posição "pula" (escala) quando muda e tem cor de pódio: 1º ouro, 2º prata, 3º bronze.
- [x] **RF-133** Tempo da volta atual e melhor volta embaixo do cronômetro; ao fechar uma volta aparece o tempo dela.
- [x] **RF-134** Volta final: indicador de volta em vermelho e a música acelera 8%.
- [x] **RF-135** Contador de queijinhos ao lado do item (ícone de queijo + `x/10`).

**Física**
- [x] **RF-140** Setas de turbo no asfalto (2 por pista): passar por cima dá 0.8 s de turbo. A IA mira nelas às vezes.
- [x] **RF-141** Rampa (1 por pista): o kart decola (altura e gravidade de verdade), vira menos no ar e não pega grama. **Manobra:** apertar drift no ar faz uma pirueta e dá 0.7 s de turbo ao pousar. A IA faz a manobra 70% das vezes.
- [x] **RF-142** Vácuo: andar logo atrás de outro kart (4–14 m, no cone de 15°, ambos acima de 15 m/s) por 1.2 s dá 0.8 s de turbo ("VÁCUO!").
- [x] **RF-143** Drift nível 3: ≥ 2.4 s de drift = turbo roxo de 1.6 s.
- [x] **RF-144** Batidas: impacto proporcional à velocidade de aproximação; o mais leve perde mais velocidade. Som de batida (kart×kart e muro forte) para humanos.
- [x] **RF-145** Visual: rodas giram com a velocidade, as dianteiras esterçam, a carroceria inclina na curva e treme na grama.

**Gameplay**
- [x] **RF-150** Queijinhos: fileiras de queijos na pista (voltam 8 s depois de pegos). Cada um dá +1% de velocidade máxima, até 10. Quem é atingido (casca/bomba) perde 3.
- [x] **RF-151** Dificuldade da IA no menu (`IA: FÁCIL / NORMAL / DIFÍCIL`): habilidade 0.84–0.90 / 0.90–0.97 / 0.97–1.02 e *rubber band* mais forte no difícil.

### Gráficos (v0.9)
- [x] **RF-160** Renderer **Forward+** no PC (a versão web, quando existir, usa Compatibility). Ambiente com tonemap ACES, bloom (glow), SSAO, neblina leve na cor do horizonte, saturação +10% e MSAA 4x.
- [x] **RF-161** (substituído pelo RF-182) Opção `GRÁFICOS: ALTO / BAIXO` no menu (salva no `Game`). BAIXO desliga SSAO, bloom, sombras suaves e MSAA e reduz as partículas pela metade.
- [x] **RF-162** Texturas procedurais em projeção triplanar (sem UV): asfalto granulado com relevo, grama com variação, areia, e piso de azulejo xadrez na cozinha.
- [x] **RF-163** Céu em shader: gradiente, sol com halo, nuvens animadas; na pista noturna, estrelas e lua.
- [x] **RF-164** Kart remodelado: carroceria arredondada com pintura metálica, bico, para-choques, volante, escapamento duplo, número do grid em placa branca, braços do piloto no volante.
- [x] **RF-165** Partículas (CPUParticles3D): faíscas do drift na cor do nível, fogo do turbo, poeira na grama/areia, fumaça + estrelinhas ao ser atingido, poeira no pouso da rampa, confete na chegada dos humanos.
- [x] **RF-166** Linhas de velocidade na tela durante o turbo; tremida de câmera em batida, pancada e pouso.
- [x] **RF-167** Cenário: arquibancada com torcida colorida na largada, bandeirolas na reta, pilhas de pneu nas curvas mais fechadas, tufos de grama/pedras (ou queijos gigantes na cozinha).
- [x] **RF-168** Caixas de item com brilho arco-íris animado (shader).

### Modelos e assets (v0.10)
Assets de terceiros: só **CC0** (Kenney: Car Kit, Food Kit, Racing Kit, UI Pack, Fonts), copiados para `assets/kenney/` com as licenças. Créditos em `CREDITS.md`.
- [x] **RF-170** Kart = modelo do Car Kit (`kart-*.glb`) escalado pro tamanho do jogo, com o piloto original escondido. Carroceria recolorida na cor do piloto (shader troca só as partes coloridas, mantém branco/cinza). Rodas do modelo giram e as dianteiras esterçam.
- [x] **RF-171** Camundongo novo feito em código: cabeção com focinho claro, olhos com brilho, nariz rosa, bigodes, orelhonas e rabo. Cada amigo tem o seu **visual** (`look` em `characters.gd`): cor do pelo, tipo/cor de cabelo, barba, óculos (grau ou escuros), fone de ouvido e cor da camiseta, tirados das ilustrações.
- [x] **RF-172** Itens 3D do Food Kit: a casca é uma banana de verdade, os queijinhos são queijos.
- [x] **RF-173** Cenário do Racing Kit: pórtico de largada com semáforo no lugar do arco, arquibancadas cobertas, torres de faixa, tendas e boxes perto da largada, outdoors e árvores do kit.
  - Textos 3D fixos (placa do pórtico, faixa da arquibancada, números dos karts) são de uma face só: o Label3D é dupla face por padrão e frente/verso se sobrepunham espelhados.
- [x] **RF-174** Interface com fonte **Kenney Future Narrow** (tema global com fallback pra fonte padrão) e botões do UI Pack (amarelo = ação principal, cinza = opções) no menu, pause e resultado; sons de clique do UI Pack.
- [x] **RF-175** Marca do jogo nos cenários: **ZAWSZE** (combustível/patrocínio). O banner "TANKCO" do Racing Kit é trocado em todos os props por `assets/brand/zawsze_banner.png`, gerado por `tools/make_brand.gd`.

### Configurações (v0.11)
- [x] **RF-180** Tela de configurações (abas **ÁUDIO / VÍDEO / JOGO / CONTROLES**) aberta pelo botão `CONFIGURAÇÕES` do menu e pelo pause. Toda mudança vale na hora (inclusive no meio da corrida pausada) e é salva em `user://settings.cfg`. Botão `PADRÃO` restaura tudo; `Esc` ou `VOLTAR` fecha.
- [x] **RF-181** Áudio: volume geral, música, efeitos e motor (0–100%), cada um num bus próprio (`Music`, `SFX`, `Engine` → `Master`). `M` continua mutando tudo.
- [x] **RF-182** Vídeo: tela cheia, vsync, limite de FPS (sem limite/30/60/120/144/240), qualidade **BAIXO / MÉDIO / ALTO**, escala de resolução 3D (50–100%), campo de visão (60–90°) e mostrar FPS.
  - ALTO = bloom + SSAO + MSAA 4x + sombra 140 m; MÉDIO = bloom + MSAA 2x + sombra 100 m; BAIXO = sem bloom/SSAO/MSAA, sombra 60 m.
- [x] **RF-183** Jogo: intensidade da tremida de câmera (0–100%), linhas de velocidade, partículas (normais/reduzidas), nomes sobre os karts, minimapa, lista de posições e unidade de velocidade (km/h ou mph).
- [x] **RF-184** Controles: tabela com as teclas/botões de cada ação para J1, J2 e controles; zona morta do analógico (5–50%).
- [x] **RF-185** O antigo botão `GRÁFICOS` do menu vira `CONFIGURAÇÕES` (a qualidade passa a morar na aba Vídeo).

### Grand Prix (v0.12)
- [x] **RF-190** Menu tem `MODO: CORRIDA / GRAND PRIX` (canto superior esquerdo). No GP o botão de pista mostra `PISTAS: AS 3` e fica desativado; voltas, IA e jogadores valem pras 3 corridas.
- [x] **RF-191** O GP são as 3 pistas em sequência: Circuito Queijo Suíço → Deserto do Parmesão → Cozinha à Meia-Noite.
- [x] **RF-192** Pontos por corrida: 1º 15 · 2º 12 · 3º 10 · 4º 8 · 5º 6 · 6º 4 · 7º 2 · 8º 1 (quem não terminou pontua pela posição em que estava). Desempate da classificação: mais pontos → mais vitórias → melhor posição na última corrida.
- [x] **RF-193** Durante a corrida o HUD mostra `GRAND PRIX · CORRIDA n/3`.
- [x] **RF-194** Resultado no GP: cada piloto com tempo, `+pontos` e total; botão principal `PRÓXIMA: <pista>` (ou `PÓDIO DO GP` na última). `R`/"Correr de novo" ficam desativados depois do resultado (sem pontuar duas vezes); `Esc` abandona o GP e volta pro menu.
- [x] **RF-195** Tela final do GP: "CAMPEÃO DO GRAND PRIX", pódio com o top 3 de corpo inteiro e os pontos, tabela com os 8, confete; botões `NOVO GRAND PRIX` e `MENU`.

### Itens novos (v0.13)
- [x] **RF-200** Sorteio ponderado por posição (1º–2º: casca/ratoeira/escudo/bomba/turbo; 3º–4º: + triplo; 5º–8º: bomba/turbo/triplo/escudo/casca/**gato**). O gato só sai de 5º pra trás e só existe um por vez.
- [x] **RF-201** **GATO**: corre pela pista atrás do 1º colocado (ou do 2º, se quem soltou é o líder), dá o bote quando chega perto e faz rodar 1.6× mais tempo. Miado de aviso quando o alvo é humano.
- [x] **RF-202** **RATOEIRA**: armadilha de madeira com isca de queijo; quem passa fica preso 1.2 s parado e perde 3 queijinhos.
- [x] **RF-203** **ESCUDO DE QUEIJO**: bolha por 8 s que absorve um ataque (casca, bomba, ratoeira ou gato); pisca no final.
- [x] **RF-204** **QUEIJO TRIPLO**: 3 turbos, usados um de cada vez (HUD mostra `x3`, `x2`, `x1`).
- [x] **RF-205** IA usa os itens novos: escudo logo que pega, gato em seguida, triplo nas retas, casca/ratoeira quando tem alguém colado atrás.

### IA mais esperta (v0.14)
- [x] **RF-210** **Desvio:** a IA olha a pista à frente (alcance cresce com o "cuidado") e, se tem casca/ratoeira perto da faixa dela, troca pro outro lado com folga. Cada perigo é avaliado uma vez (o cuidado define a chance de reagir).
- [x] **RF-211** **Ultrapassagem:** kart mais lento até 10 m à frente na mesma faixa → a IA abre pro lado com mais espaço.
- [x] **RF-212** **Caixas:** sem item, a IA mira na caixa ativa mais próxima da próxima fileira (chance pela agressividade).
- [x] **RF-213** **Personalidade** por piloto (`ai` em `characters.gd`, 0–1): `aggro` (usa itens antes e mira bomba de mais longe), `avoid` (desvia mais e mais cedo), `focus` (troca menos de faixa à toa), `drift` (começa drift em curvas mais abertas).
  - Burcca e Ortiz agressivos; Nanni e Mugurin cautelosos; Telles e Shinando focados; FeJauM e Digão equilibrados.

### Música por pista e torcida (v0.15)
- [x] **RF-220** Cada contexto tem a sua trilha chiptune gerada em código (`Sfx.music(estilo)`), em loop e guardada em cache:
  - `menu` (abertura/menu) — 118 bpm, dó maior, calma.
  - `queijo` — 150 bpm, lá menor (a trilha original).
  - `deserto` — 136 bpm, ré com escala "árabe" (frígio dominante) e percussão seca.
  - `cozinha` — 164 bpm, mi menor, baixo em oitavas, mais funk.
  - `victory` — 132 bpm, sol maior, pra tela de campeão do GP.
- [x] **RF-221** A música troca sozinha ao mudar de tela/pista (`Game.play_music`), sem reiniciar se o estilo já está tocando. A aceleração da volta final continua valendo.
- [x] **RF-222** Torcida sintetizada (`crowd`) no VAI! e quando um humano cruza a chegada.

### Contra o relógio (v0.16)
- [x] **RF-230** `MODO` no menu alterna CORRIDA → GRAND PRIX → **CONTRA O RELÓGIO**. Nesse modo é sempre 1 jogador (o botão de jogadores fica travado em 1) e a pista é escolhida normalmente.
- [x] **RF-231** Na corrida contra o relógio só existe o kart do jogador (sem IA, sem caixas de item); ele larga na frente do grid e recebe um **Queijo Triplo** no VAI!. Queijinhos e setas continuam valendo.
- [x] **RF-232** Recordes por pista em `user://records.cfg`: melhor tempo total (e quem fez) e melhor volta (e quem fez). O HUD mostra o recorde durante a corrida.
- [x] **RF-233** **Fantasma**: a posição/direção do jogador é gravada a cada 0.1 s; a melhor corrida da pista vira um kart translúcido que repete o percurso (interpolado) nas próximas tentativas. Também aparece como bolinha azul no minimapa.
- [x] **RF-234** Resultado do contra o relógio: tempo total, tempo de cada volta, melhor volta, comparação com o recorde e "NOVO RECORDE!" quando bate; botões `TENTAR DE NOVO (R)` e `MENU`.

### UI/UX robusta (v0.17)
- [x] **RF-240** Menu 100% navegável por teclado e controle, sem mouse: linha de cima (`MODO`, `CONFIGURAÇÕES`) ↑ cartas dos pilotos ↓ linha de opções (`JOGADORES`, `VOLTAS`, `IA`, `PISTA`, `CORRER!`). Setas/direcional/analógico movem o foco (botões desativados são pulados), Enter/A aperta. O botão focado fica destacado. A/B do controle entram no `ui_accept`/`ui_cancel` (o Godot não traz por padrão), então todo botão focado funciona no controle; o foco no botão do resultado só chega 0,8 s depois (quem segura A pra acelerar não reinicia sem querer). O pause usa o tema do jogo.
- [x] **RF-241** "Voltar" igual em todas as telas: Esc / Backspace / B. No menu: desfaz o último piloto confirmado → senão volta o foco pras cartas → senão vai pra abertura. No pause: continua a corrida. Na tela de resultado e no pódio do GP: menu. Nas configurações: fecha.
- [x] **RF-242** As dicas de controle (rodapé do menu e da corrida) mostram teclas do teclado ou botões do controle conforme o último dispositivo usado, trocando na hora.
- [x] **RF-243** No Grand Prix, `Menu` no pause pede confirmação ("Abandonar o Grand Prix?" SIM / NÃO, foco no NÃO).
- [x] **RF-244** Nada de interface sai da tela: menu, resultado (corrida e contra o relógio), pause e configurações cabem em 16:9, 4:3 e 21:9.

### Ícones e sons (v0.19)
- [x] **RF-206** Ícones dos itens são fotos dos próprios modelos 3D do jogo (foguete, banana, bomba, ratoeira, gato, queijo, queijo triplo, escudo), geradas por `tools/render_icons.gd` em `assets/icons/` (128 px, fundo transparente). Sem a foto, o HUD volta pro desenho em código.
- [x] **RF-207** Efeitos e músicas vêm de arquivos CC0 em `assets/audio/` (créditos em CREDITS.md); `Sfx` cai na versão sintetizada se faltar arquivo. Vinheta própria na volta final; motor gravado em loop com pitch 0,75–1,45.

### Tela de escolha de piloto (v0.20)
- [x] **RF-260** Layout em duas colunas: à esquerda a grade 4×2 de cartas (retrato), à direita o painel do piloto em destaque (corpo inteiro, nome, 4 barras de atributo, quem está escolhendo). Topo: `MODO`, título e `CONFIGURAÇÕES`; embaixo a linha de opções e as dicas. Espaçamento uniforme (margem 24, espaço 12–16).
- [x] **RF-261** A arte nunca sai da carta: cabeça encaixada (proporção mantida) dentro da área da carta, com recorte; nome numa faixa embaixo. A base reta da arte (corte nos ombros) fica escondida atrás da faixa do nome; brilho atrás da cabeça e escurecido embaixo; holofote e sombra no chão no painel. Sobra de fundo das artes do Shinando e do Ortiz removida por `tools/clean_art.gd` (só a cor do fundo, a partir de sementes).
- [x] **RF-262** Animações: carta selecionada cresce e a borda pulsa; trocar de piloto desliza/esmaece a arte grande e anima as barras até o valor novo, com som; o corpo do piloto "respira". Passar o mouse numa carta seleciona.
- [x] **RF-263** Confirmar: a carta dá um pulo com brilho, ganha o selo J1..J4 com a cor do jogador e toca o som de confirmação. No último jogador a tela escurece rápido antes da corrida.

### Menu em etapas (v0.23)
- [x] **RF-290** Fluxo: abertura → **1 MODO** → **2 PILOTO** → **3 PISTA** → **4 AJUSTES** → corrida. Barra de cima com VOLTAR, título, trilha das etapas (atual em amarelo, feitas em verde) e CONFIGURAÇÕES.
- [x] **RF-291** MODO: três cartões grandes (CORRIDA, GRAND PRIX, CONTRA O RELÓGIO) com ícone e descrição + linha JOGADORES 1–4 (só 1 no contra o relógio; passar por ele não zera a escolha).
- [x] **RF-292** PISTA: lista à esquerda e painel com o **trajeto desenhado** (se desenha ao trocar, depois um ponto dá voltas), largada, setas (T), rampa (R), zonas coloridas (farofa, esteiras, grelha) e perigos (F, Q, P), descrição, extensão, recorde e o que tem na pista. No Grand Prix mostra a copa.
- [x] **RF-293** AJUSTES: VOLTAS e IA mudam com ◄ ► (setas desenhadas), resumo de modo/pilotos/pista e CORRER!.
- [x] **RF-294** Cada etapa entra deslizando; ao subir/descer o foco cai no item escolhido.
- [x] **RF-295** Voltar: desfaz o último piloto → etapa anterior (da PISTA reabre o último piloto) → abertura.

### Drift no estilo arcade (v0.22)
- [x] **RF-280** No drift o kart gira no máx. 1,05× o giro normal (0,45× abrindo), a velocidade acompanha o bico (aderência alta; o "de lado" é só o modelo) e, ao soltar, sai alinhado — o mini-turbo empurra reto pra frente.

### Pistas novas: Churrascada e Fábrica (v0.21)
- [x] **RF-270** Zonas de superfície por trecho da pista (dados da pista, `zones`): **farofa** (velocidade máx. ×0,62, igual fora da pista), **esteira** (carrega o kart pra frente a 9 m/s, mesmo parado, e dá +15% de velocidade máx.), **esteira lateral** (empurra pro lado a 5 m/s) e **grelha** (só visual, onde ficam as labaredas). No ar nada vale. Esteiras têm faixas que andam.
- [x] **RF-271** Perigos da pista (`hazards`), controlados pela corrida, só depois do VAI!: **labareda** (ciclo: aviso com brasa 0,6 s → fogo `on` s → apagada; quem passa no fogo roda), **roda de queijo** (rola de um lado pro outro da pista, quem encosta roda) e **prensa** (desce com aviso de sombra; pega quem está embaixo, rodada forte). Escudo protege como de costume.
- [x] **RF-272** A IA enxerga labaredas acesas/avisando, a roda e a prensa descendo, e as zonas de farofa, pelo mesmo sensor de casca/ratoeira (com a personalidade de desvio de cada piloto).
- [x] **RF-273** **Churrascada de Domingo**: mesa de madeira, pista de tábua, zebra de toalha xadrez, muro verde e amarelo, espetos e garrafas em volta, tomates/pães/cebolas espalhados; farofa em dois trechos e grelha com 3 linhas de labaredas; rampa = pulo da tábua pro prato.
- [x] **RF-274** **Fábrica de Queijo**: galpão escuro com luz de forno, chão de chapa, muro amarelo e preto, chaminés e máquinas, queijos empilhados; esteira pra frente na reta, esteira lateral numa curva, 2 rodas de queijo e 2 prensas.
- [x] **RF-275** Cada uma com música CC0 própria.

### Parquinho em Oito e Copa Farofa (v0.24)
- [x] **RF-300** Pista em **8 com cruzamento no mesmo nível** (`"crossing": true`): a pista acha sozinha onde as passadas se cruzam; ali não desenha muro, zebra nem grama dentro da outra pista, a passada de cima fica um tiquinho mais alta (sem piscar) e ganha faixas brancas tracejadas. Os karts seguem a própria passada (busca local do índice) e batem de lado em quem cruza. O trajeto no menu marca o cruzamento com um X.
- [x] **RF-301** **Caixa de areia** (zona `sand`) na metade de dentro de uma curva fechada: segura menos que a farofa (×0,72), então cortar por dentro é um atalho com preço. Moldura de madeira e forminhas de brinquedo.
- [x] **RF-302** **Escorregador**: a rampa da pista pode ter altura própria (`ramp_h`, 2,2 m no parquinho) e visual de brinquedo (`ramp_style: slide`). Setas, rampa, caixas e queijinhos podem ter posições próprias por pista (longe do cruzamento).
- [x] **RF-303** **Gangorra** (perigo `seesaw`) numa metade da pista, balançando sempre: com a ponta de trás no chão vira rampa e lança o kart; com a ponta levantada é parede (bate e roda). A IA desvia quando está levantada.
- [x] **RF-304** Cenário de praça: árvores, balanços e bolas gigantes; zebra azul/amarela, muro rosa/verde, pista de borracha laranja, fim de tarde. Música própria (CC0).
- [x] **RF-305** **Copas no Grand Prix**: Copa Queijo (queijo, deserto, cozinha) e **Copa Farofa** (churrasco, parquinho, deserto, fábrica). Na etapa PISTA do GP a lista vira a lista de copas.

### Voltar o kart preso (v0.25)
- [x] **RF-310** **Resgate com balões**: um cacho de 3 balões pega o kart e devolve na pista (sobe 6 m, some, desce no ponto seguro; 1,3 s sem controle). Chama quando o kart **quer andar e não sai do lugar** (jogador: 3 s acelerando; IA: 2,5 s) ou quando **cai** abaixo do chão (vãos das pistas futuras; cair custa 3 queijinhos, ficar preso não custa nada). Substitui o teletransporte seco do RF-16.
- [x] **RF-311** **Ponto seguro**: o kart lembra a última amostra em que andou pra frente, no chão, dentro da pista. A pista marca o que não serve (perigos, zonas, rampa e pouso, cruzamento) e o resgate sempre volta pra trás até um ponto bom, nunca adianta. O progresso da volta acompanha.
- [x] **RF-312** Depois de pousar o kart **pisca 1,2 s** e nada acerta (itens, perigos, ratoeira). Pendurado nos balões não bate em ninguém.
- [x] **RF-313** **CONTRAMÃO!** pisca no HUD depois de 1 s andando contra o sentido da pista (antes só aparecia depois da chegada, por engano).

### Geladeira Polar: andares, looping e gelo (v0.26)
- [x] **RF-320** **Altura**: a pista pode ter altura por ponto de controle (`heights`); a linha central é 3D (Hermite), o kart acompanha o chão (sobe, desce, empina o bico) e pousa de pulos na altura certa. Trecho no alto ganha laje por baixo e pilares que nunca caem em cima de outra pista. Muro por amostra: estreito (colado na zebra) no looping e em pontes (`narrow`). Cenário calculado no plano (nada flutua nem nasce embaixo de trecho alto).
- [x] **RF-321** **Looping** (`loops: [{cp, r, w}]`): volta vertical inteira com deslocamento lateral (a saída passa do lado da entrada). Dentro dele o kart vai no **trilho** (grudado, velocidade mínima 20 m/s, direcional troca de faixa), de cabeça pra baixo no alto; a câmera gira junto. A IA mira a entrada e passa sempre. O resgate nunca devolve dentro do looping.
- [x] **RF-322** **Andares e viaduto**: trechos com mais de 3,5 m de diferença são andares; um passa por cima do outro sem recortar muro, karts de andares diferentes não batem, e itens/queijinhos/perigos só pegam quem está na mesma altura.
- [x] **RF-323** **Gelo** (zona `ice`): o kart escorrega (aderência baixa, ainda mais no drift) e anda 5% mais rápido.
- [x] **RF-324** **Geladeira Polar** (1,35 km): fundo da geladeira (0 m) → subida → prateleira (8 m) com looping → congelador (16 m) com gelo e seta de turbo no gelo → ponte estreita por cima da reta de largada → descida com rampa. Túnel de caixa de leite, comida gigante (caixas de leite, iogurtes, ovos, garrafas), cubos de gelo, paredes da geladeira com lâmpada no teto. O trajeto no menu fica mais claro onde é mais alto e marca o looping (L) e o viaduto (V). Música CC0.

### Telhados da Vila: vãos entre prédios (v0.27)
- [x] **RF-330** **Vãos** (`gaps: [{range, len}]`): trechos sem chão; cada um ganha uma **rampinha de beirada** (tábua com a ponta amarela) logo antes. Rápido, o kart voa por cima e pousa no outro prédio; devagar, cai e os balões trazem de volta (−3 queijinhos); pulo curto que bate na parede do prédio da frente também cai. O resgate nunca devolve na rampinha, no vão ou no pouso. A pista pode ter várias rampas (cada uma com sua altura) e nenhuma rampa principal (`ramp_range: null`).
- [x] **RF-331** **Prédios** embaixo dos telhados (`buildings`): um bloco por trecho entre vãos, cores de fachada e janelas acesas/apagadas; sem arquibancada nem boxes (`stands: false`).
- [x] **RF-332** **Gatão** (perigo `roofcat`) patrulhando um telhado de um lado pro outro; quem encosta roda (miau). A IA desvia.
- [x] **RF-333** **Telhados da Vila** (1,3 km, 18–22 m de altura): noite com lua cheia e estrelas, 3 vãos, varais de roupa atravessando a pista, cidade em volta com janelas, caixas d'água e antenas. O trajeto no menu marca os vãos (S) e o gato (C). Música CC0.

### Visual do menu (v0.28)
- [x] **RF-340** Botões do jogo todo viram "bala" escura arredondada com borda clara e foco em contorno amarelo com brilho; ação principal amarelo-queijo com base escura (3D). Fundo do menu = arte da abertura desfocada e escurecida, com listras diagonais andando e vinheta. Barra de cima de vidro; etapas viram chips (feita verde, atual amarela, por vir apagada). Dicas numa pílula escura no rodapé.
- [x] **RF-341** AJUSTES ganha cartão de resumo: modo colorido, retrato de cada piloto (cabeça num círculo da cor dele, borda da cor do jogador no multi) e o trajeto da pista.
- [x] **RF-342** Looping liso: orientação do kart e da câmera interpolada entre amostras (antes girava em degraus de ~10°), "pra cima" da câmera suavizado.

### Carregamento e exe que abre (v0.29)
- [x] **RF-350** **Tela de carregamento** entre o menu e a corrida (e ao reiniciar, na próxima corrida do GP e no GP novo): arte desfocada, queijinho girando, "CARREGANDO" e o nome da pista (no GP, a copa e a corrida). Fica por cima de tudo durante a troca de cena e some sozinha no primeiro quadro da corrida (`Game.go_race`, `hide_loading`).
- [x] **RF-351** **Imagem de inicialização** do Godot (`assets/ui/splash.png`, gerada por `tools/make_splash.gd`): a arte da abertura com "CARREGANDO...", aparece assim que o motor gráfico liga (antes disso, ~2 s de janela preta da placa de vídeo iniciando, que não dá pra evitar no Forward+). O jogo registra no log em quanto tempo ficou pronto (`[boot]`).
- [x] **RF-352** **Exe que o Windows deixa abrir**: com o Controle Inteligente de Aplicativos ligado, exe sem assinatura e "desconhecido" é bloqueado. A exportação agora usa o executável oficial do Godot sem modificação (`embed_pck=false`, `modify_resources=false`) e o jogo vai no `CarMundonGO.pck` ao lado — os dois arquivos precisam ficar juntos na mesma pasta.

### Trocar teclas (v0.18)
- [x] **RF-250** Aba CONTROLES: uma linha por ação (acelerar, frear/ré, virar à esquerda, virar à direita, drift, item) com um botão por coluna — J1 (teclado), J2 (teclado) e CONTROLE. Apertar o botão mostra "APERTE..." e a próxima tecla (ou botão do controle, na coluna CONTROLE) vira a nova. Esc cancela; 6 s sem nada também.
- [x] **RF-251** No teclado cada ação de J1/J2 fica com uma tecla só (a nova substitui as alternativas). No controle dá pra trocar os botões de acelerar, frear, drift e item (vale pros 4 controles); gatilhos RT/LT e analógico/direcional continuam valendo.
- [x] **RF-252** Conflito: se a tecla/botão já é de outra ação (de qualquer jogador no teclado), as duas trocam e aparece um aviso. Esc, M e R (pausar, som, reiniciar) e o Start do controle são reservados e não podem ser usados.
- [x] **RF-253** As trocas são salvas em `user://settings.cfg` (seções `keys` e `pad`) e voltam ao abrir o jogo. `RESTAURAR CONTROLES` (e o `PADRÃO` geral) volta ao mapa original da §5.
- [x] **RF-254** As dicas da tela (menu, corrida) mostram as teclas/botões atuais.

## 5. Controles

| Ação | Jogador 1 (teclado) | Jogador 2 (teclado) | Controle (J1..J4 = controle 1..4) |
|---|---|---|---|
| Acelerar | W | ↑ | A ou RT |
| Frear / ré | S | ↓ | B ou LT |
| Virar | A / D | ← / → | Analógico esquerdo |
| Drift (no ar: manobra) | Espaço / Shift esq. | Shift dir. / Numpad 0 | RB |
| Usar item | E / Ctrl esq. | Enter / Ctrl dir. | LB ou X |
| Reiniciar | R | R | — |
| Pausar | Esc | Esc | Start |
| Som liga/desliga | M | M | — |

Jogadores 3 e 4 só por controle. Com 1 jogador, as teclas do J2 também valem para o J1.

## 6. Requisitos não funcionais
- **RNF-01** 60 ticks de física fixos com *physics interpolation* (suave em monitores 144 Hz).
- **RNF-02** Lógica da corrida roda sem renderização (`race.step(delta)`), permitindo simular corridas inteiras em teste headless.
- **RNF-03** Sem `class_name`: scripts se referenciam por `preload`, para o projeto rodar direto da linha de comando sem passar pelo editor.
- **RNF-04** O som do motor é um loop WAV pré-gerado com pitch variando pela velocidade. (A versão com `AudioStreamGenerator` derrubava o Godot 4.7 com segfault ao criar/destruir corridas de 4 jogadores, inclusive com driver real.) Regressão: `tools/stress_races.gd -- mp` — 144 corridas, 0 crashes (com e sem janela).

## 7. Arquitetura

```
scenes/intro.tscn    -> scripts/intro.gd       tela de abertura (cena principal)
scenes/menu.tscn     -> scripts/menu.gd        jogadores, seleção de piloto e voltas
scenes/race.tscn     -> scripts/race.gd        orquestra a corrida (estado, itens, colisões, ranking, câmera)
scenes/gp_final.tscn -> scripts/gp_final.gd    pódio final do Grand Prix
scripts/game.gd      (autoload "Game")         piloto escolhido, voltas, mapa de inputs
scripts/characters.gd                          dados dos 8 pilotos
scripts/track.gd                               pista procedural (Catmull-Rom -> amostras a cada 2 m) + malhas
scripts/kart.gd                                física arcade, drift, IA, visual do kart
scripts/hud.gd, scripts/minimap.gd             interface
tests/run_tests.gd                             testes headless
scripts/records.gd                             recordes e fantasma do contra o relógio (user://records.cfg)
tools/screenshot.gd                            prints do menu/corrida para revisão visual
tools/screenshot_tt.gd                         prints do contra o relógio (usa recordes à parte)
tools/screenshot_ui.gd                         prints da navegação por controle (menu, pause, confirmação do GP)
tools/esc_flow.gd                              fluxo real abertura→menu→corrida→pause→resultado com teclas simuladas (procura erro/travada)
```

**Modelo de pista:** a linha central é amostrada a cada 2 m (`points`, `tangents`, `rights`). Todo kart guarda o índice da amostra mais próxima (busca local numa janela) e a distância lateral. Isso resolve sem motor de física: grama (`|lateral| > 8`), muro (`|lateral| > 15`), progresso/voltas e mira da IA.

**Progresso:** `progress` soma a variação de índice entre frames (com wrap). Volta = `floor(progress / N) + 1`; terminou quando `progress ≥ voltas × N`. Largada começa com progresso negativo (atrás da linha).

## 8. Critérios de aceite (testes automatizados)

`tests/run_tests.gd` precisa passar:
- [x] **CA-01** Existem 8 pilotos com IDs únicos e stats 1–5 somando 12.
- [x] **CA-02** Pista fechada, amostras uniformes (2 m ± 10%), comprimento > 800 m e **sem sobreposição** (trechos não vizinhos a mais de 2× a distância do muro).
- [x] **CA-03** Corrida simulada só com IA (inclusive o "jogador" em piloto automático) termina com todos os 8 karts em < 6 min de jogo.
- [x] **CA-04** Ordem de chegada coerente: tempos crescentes, posições 1–8 sem repetição.
- [x] **CA-05** Nenhum kart atravessa o muro (lateral máx ≤ muro + 0.5 m) e nenhuma volta é mais rápida que o fisicamente possível.
- [x] **CA-06** Itens são pegos e usados durante a corrida.
- [x] **CA-07** Corrida com 4 humanos (em piloto automático) cria 4 câmeras/quadros, coloca os humanos nas 4 últimas posições do grid e termina com os 8 karts.
- [x] **CA-08** Mapa de controles: cada ação existe para J1..J4, e os eventos de controle de cada jogador só aceitam o seu próprio controle.
- [x] **CA-09** Os 8 pilotos têm arte de corpo e busto carregável, com fundo transparente (cantos com alpha 0).
- [x] **CA-10** Todos os sons existem e não estão vazios; a música tem loop ligado e dura > 8 s.
- [x] **CA-11** Largada: acelerar a 1.2 s do VAI dá turbo; acelerar desde o início queima; não acelerar não dá nada.
- [x] **CA-12** Com a corrida pausada, `step()` não avança tempo nem karts.
- [x] **CA-13** A tela de abertura carrega a arte, é a cena principal do projeto e um aperto de tecla leva pro menu.
- [x] **CA-14** Nenhum kart tem a arte do rosto como malha; o minimapa desenha 8 bustos e o HUD lista os 8 pilotos na ordem do ranking.
- [x] **CA-15** As 3 pistas passam no CA-02 (fechadas, uniformes, sem sobreposição) e uma corrida de 1 volta só com IA termina em cada uma.
- [x] **CA-16** Kart em cima de uma seta de turbo ganha turbo.
- [x] **CA-17** Kart que passa pela rampa sobe mais de 1 m e volta ao chão; com a manobra no ar, pousa com turbo.
- [x] **CA-18** Kart 8 m atrás de outro, alinhado e rápido, ganha turbo de vácuo em menos de 2 s; de lado, não ganha.
- [x] **CA-19** Pegar queijinho soma 1 (máx. 10) e aumenta a velocidade máxima; levar uma casca tira 3.
- [x] **CA-20** Dificuldade muda a faixa de habilidade da IA.
- [x] **CA-21** Roleta: item recém-pego não pode ser usado antes de 1 s.
- [x] **CA-22** Soltar o drift com 2.5 s de carga dá turbo ≥ 1.5 s.
- [x] **CA-23** Qualidade ALTO liga glow e SSAO no ambiente; BAIXO desliga os dois e zera o MSAA.
- [x] **CA-24** Kart tem emissores de partículas; drift carregado liga as faíscas, turbo liga o fogo, grama liga a poeira.
- [x] **CA-25** O material da pista e o do chão têm textura; o cenário tem arquibancada, pneus e decoração (> 0 instâncias).
- [x] **CA-26** Cada kart instancia o GLB do Car Kit, com o piloto original escondido e 4 rodas encontradas (2 dianteiras).
- [x] **CA-27** Os 8 pilotos têm `look` completo; o modelo de cada um tem as peças do visual (ex.: Burcca com óculos + barba + fone; Telles com óculos escuros + cabelo comprido).
- [x] **CA-28** Casca e queijinho usam os modelos do Food Kit; o cenário tem pórtico, arquibancadas e props do Racing Kit.
- [x] **CA-29** O tema global usa a fonte Kenney Future Narrow e ela tem todos os caracteres do jogo (acentos e º).
- [x] **CA-30** Salvar e carregar as configurações devolve os mesmos valores; chave faltando no arquivo usa o padrão.
- [x] **CA-31** Aplicar volumes muda os buses (`Music`/`SFX`/`Engine`); 0% silencia o bus.
- [x] **CA-32** A tela de configurações monta as 4 abas com os controles, e `PADRÃO` restaura os valores.
- [x] **CA-33** Na corrida, desligar nomes/minimapa/lista esconde esses elementos e o campo de visão base segue a configuração.
- [x] **CA-34** A contagem fica no centro do quadro com 1 e 2 jogadores (regressão: com 1 jogador ela ia pro canto).
- [x] **CA-35** Pontuação: a soma de pontos de uma corrida é 58; a classificação ordena por pontos, depois vitórias, depois última corrida.
- [x] **CA-36** GP completo simulado (3 corridas de 1 volta só com IA): passa pelas 3 pistas na ordem, cada corrida pontua uma única vez, total 174, e no fim `gp_is_over()`.
- [x] **CA-37** A tela final do GP monta o pódio com os 3 líderes da classificação.
- [x] **CA-38** Gato persegue e acerta o líder; ratoeira prende 1.2 s; escudo absorve um ataque e some; triplo dá 3 turbos; o sorteio nunca dá gato pros 4 primeiros nem dois gatos ao mesmo tempo.
- [x] **CA-39** IA com cuidado máximo desvia de uma casca na faixa dela; com cuidado zero, bate.
- [x] **CA-40** IA sem item vai pra faixa da caixa da próxima fileira; IA atrás de um kart lento na mesma faixa troca de faixa.
- [x] **CA-41** Os 8 pilotos têm personalidade completa e diferente entre si.
- [x] **CA-42** Os 5 estilos de música existem, em loop, com mais de 8 s e diferentes entre si; cada pista aponta pra um estilo; `play_music` troca o stream e não reinicia o mesmo estilo; a torcida existe e não está vazia.
- [x] **CA-43** Recordes: gravar e ler devolve os mesmos tempos; só um tempo melhor substitui o recorde.
- [x] **CA-44** Corrida contra o relógio tem 1 kart, nenhuma caixa e o jogador com Queijo Triplo após o VAI!; termina e registra o recorde e as voltas.
- [x] **CA-45** O fantasma grava a corrida e, na tentativa seguinte, passa pelos mesmos pontos nos mesmos tempos (erro < 1 m).
- [x] **CA-46** Só com eventos de controle (direcional + A) dá pra trocar modo, voltas, IA e pista, abrir e fechar as configurações e começar a corrida.
- [x] **CA-47** B no menu desfaz o piloto, depois sai das opções, depois vai pra abertura; B no pause continua a corrida.
- [x] **CA-48** Um evento de controle troca as dicas pra botões; uma tecla volta pro teclado.
- [x] **CA-49** Em 1280×720, 1024×768 e 2560×1080 todos os botões e painéis das telas ficam dentro da área visível.
- [x] **CA-50** Menu no pause do GP abre a confirmação; NÃO fecha e mantém o GP; SIM vai pro menu.
- [x] **CA-51** Trocar a tecla de uma ação muda o InputMap (a nova aciona, a antiga não), salva e volta igual depois de recarregar as configurações.
- [x] **CA-52** Tecla já usada por outra ação (inclusive do outro jogador) troca as duas; tecla reservada é recusada e nada muda.
- [x] **CA-53** Trocar o botão de drift do controle vale pros 4 controles e mantém os gatilhos; RESTAURAR volta tudo ao padrão.
- [x] **CA-54** Na tela de configurações, apertar o botão de uma ação e depois uma tecla faz a troca; Esc cancela sem mudar; a dica da corrida mostra a tecla nova.
- [x] **CA-55** Em 1280×720, 1024×768 e 2560×1080 a arte de cada carta fica dentro da carta e o painel do piloto cabe na tela.
- [x] **CA-56** Trocar a seleção atualiza o painel (nome e barras chegam ao valor do piloto após a animação); confirmar marca a carta com o selo do jogador.
- [x] **CA-57** Farofa reduz a velocidade máxima; esteira leva o kart parado pra frente; esteira lateral empurra pro lado; no ar não vale.
- [x] **CA-58** Labareda acesa roda o kart e apagada não; roda de queijo roda quem encosta; prensa embaixo pega e em cima não; nada disso antes do VAI!.
- [x] **CA-59** A IA desvia de labareda acesa à frente (troca de faixa).
- [x] **CA-60** As 2 pistas novas: geometria válida (CA-02), 8 karts terminam 1 volta sem atravessar o muro (CA-15), volta da IA entre 30 e 60 s.
- [x] **CA-61** Depois de um drift completo numa curva, ao soltar o ângulo entre velocidade e direção do kart é < 3° e o mini-turbo acelera pra frente; o giro máximo no drift não passa de 1,05× o normal.
- [x] **CA-62** (CA-46 refeito) Só com controle: escolher modo e jogadores, abrir/fechar configurações, 2 pilotos, copa, mudar voltas e IA e começar; numa corrida, trocar a pista muda o trajeto e a corrida sai na pista escolhida.
- [x] **CA-63** (CA-47 refeito) B desfaz piloto, volta etapas e reabre o último piloto ao sair da PISTA. CA-49 cobre as 4 etapas em 3 proporções.
- [x] **CA-64** Parquinho: um cruzamento a 60..120°, muro aberto só ali, uma passada por cima; kart atravessa e segue na mesma passada; karts das duas passadas colidem.
- [x] **CA-65** Caixa de areia segura (≤ 0,72 do máximo) e menos que a farofa.
- [x] **CA-66** Gangorra: no chão lança o kart, levantada derruba, do outro lado da pista não pega, IA enxerga.
- [x] **CA-67** Escorregador mais alto que a rampa comum e pulo > 3 m; rampa e setas longe do cruzamento.
- [x] **CA-68** Copa Farofa com 4 pistas; no menu ↓ escolhe a copa, o GP começa na Churrascada e a 2ª corrida é o Parquinho.
- [x] **CA-69** Jogador acelerando contra o muro: balões em ~3 s, sobe, pousa no centro da pista no mesmo lugar ou atrás, de frente, progresso certo; pisca e nada acerta; depois normal. Parado sem acelerar não chama.
- [x] **CA-70** Abaixo do chão: resgate, -3 queijinhos, volta no último ponto seguro.
- [x] **CA-71** Pontos seguros: nunca em fogo, farofa, grelha, rampa ou no meio do cruzamento; da grelha volta pra antes dela; a maior parte da pista é segura.
- [x] **CA-72** Andando ao contrário aparece CONTRAMÃO!; virando, some.
- [x] **CA-73** IA parada também é resgatada pelos balões.
- [x] **CA-74** Geladeira: de 0 m a mais de 15 m sem afundar no chão; um viaduto com vão > 6 m e ponte estreita; um looping de cabeça pra baixo no alto, muro estreito na entrada e saída, sem ponto de resgate dentro.
- [x] **CA-75** Na subida o kart fica colado no chão (erro < 5 cm) e empina o bico.
- [x] **CA-76** Looping: entra no trilho, dá a volta inteira de cabeça pra baixo, sai no chão alinhado; devagar também passa; direcional troca de faixa; câmera gira junto.
- [x] **CA-77** No gelo o kart derrapa mais que o dobro do asfalto.
- [x] **CA-78** Viaduto: karts de andares diferentes não batem, queijinho de baixo não é pego por quem passa em cima, resgate no alto pousa no alto.
- [x] **CA-79** IA na Geladeira: volta entre 30 e 60 s, todos passam pelo looping, quase nunca precisam de resgate.
- [x] **CA-80** Telhados: 3 vãos com rampinha logo antes; nenhum ponto de resgate na rampinha, vão ou pouso; tudo no alto e com lua.
- [x] **CA-81** Rápido: o kart voa por cima do vão e pousa no outro prédio sem resgate.
- [x] **CA-82** Devagar: cai no vão, balões, −3 queijinhos e volta no telhado antes do vão; pulo curto que bate na parede também cai.
- [x] **CA-83** Gatão derruba quem encosta, anda de um lado pro outro e a IA vê.
- [x] **CA-84** IA nos Telhados: volta entre 30 e 60 s e quase nunca cai.
- [x] **CA-85** Menu: fundo com a arte, botões do tema novo, 4 chips de etapa com a atual destacada; AJUSTES mostra os retratos dos pilotos e o trajeto. (CA-76 cobre o looping liso: no máximo 4° de giro por quadro.)
- [x] **CA-86** Imagem de inicialização configurada; CARREGANDO com o nome da pista por cima de tudo (no GP, copa e corrida); a corrida tira a tela sozinha.

Teste manual (checklist por release):
- [ ] Dá pra ganhar a corrida jogando bem; dá pra perder jogando mal.
- [ ] Drift é controlável e o mini-turbo é perceptível.
- [ ] 60 fps estáveis num PC comum.

## 9. Roadmap pós-MVP (cada item vira seção nova desta spec)
1. **Rostos/modelos dos amigos** — fotos já suportadas em `assets/faces/`; depois modelos low-poly.
2. ~~**Multiplayer local** em tela dividida (2–4 jogadores).~~ → §4 RF-60..67.
3. ~~**Áudio**~~ → §4 RF-80..83.
4. ~~**Mais pistas**~~ → §4 RF-120..122; ~~Grand Prix~~ → RF-190..195. Falta: elevação e atalhos.
5. ~~**Mais itens**~~ → RF-200..205 (gato, ratoeira, escudo, triplo). Falta: item "assinatura" por piloto.
6. ~~**Largada turbo**~~ → §4 RF-85..87.
7. **Export web** (GitHub Pages) pra turma jogar no navegador.
8. **Multiplayer online.**

## 10. Plano: pistas novas (P1 a P5 feitas — v0.21, v0.24, v0.26 e v0.27)

Ideia geral: o mundo é **visto do tamanho de um camundongo** — cada pista é um lugar comum da casa/cidade em escala gigante, com um "truque" que muda o jeito de pilotar. Uma segunda copa (**Copa Farofa**, 4 pistas) entra no Grand Prix junto da atual (**Copa Queijo**). Tudo original; assets só CC0.

### Pistas

| # | Pista | Onde | Truque de pilotagem | Tecnologia nova |
|---|---|---|---|---|
| P1 | **Churrascada de Domingo** | em cima de uma mesa de churrasco | trecho sobre a **grelha** com labaredas que sobem em ritmo (acertam quem passa na hora errada); **farofa** espalhada = areia que segura o kart; espetos e vinagrete de cenário; pulo da tábua de carne pro prato | T1 superfícies, T4 perigos com tempo |
| P2 ✅ | **Parquinho em Oito** | parquinho da praça à tarde | traçado em **8 com cruzamento no mesmo nível** (dá pra bater de lado em quem cruza); **escorregador** vira rampa gigante; **caixa de areia** como atalho lento; gangorra que sobe e desce | T5 cruzamento, T4 gangorra |
| P3 | **Fábrica de Queijo** | linha de produção | **esteiras** que empurram pra frente (rápido) ou pro lado; **rodas de queijo rolando** pela pista como obstáculo; prensas que descem; queijinhos em dobro | T1 esteira, T4 obstáculos móveis |
| P4 ✅ | **Geladeira Polar** | dentro da geladeira aberta, luz azul | **prateleiras em andares** ligadas por rampas (pista sobe e desce); **gelo** que escorrega no congelador; potes de iogurte e caixa de leite como túnel | T3 elevação, T1 gelo |
| P5 ✅ | **Telhados da Vila** | telhados à noite, lua cheia | **pulos entre prédios** (cair = volta pro último ponto); varal de roupa como teto; **gato de verdade patrulhando** um telhado; antenas e caixas d'água | T3 elevação, T6 vãos + respawn, T4 gato |
| P6 | **Feira Livre** | rua de feira de manhã | pista que **afunila** entre as barracas e abre na rua; caixotes, pastel, caldo de cana; um atalho por baixo das barracas | T2 largura variável, T5 atalho |

### Tecnologia, em ordem de custo

| Id | O que | Custo | Libera |
|---|---|---|---|
| T1 | **Zonas de superfície** por trecho: gelo (menos aderência), farofa/areia (freia), esteira (empurra), água (corrente lateral). Visual + física + IA sabendo evitar\/aproveitar | baixo | P1, P3, P4 |
| T2 | **Largura variável** por ponto de controle (muro acompanha; IA usa a largura local) | baixo | P6 |
| T4 | **Perigos com tempo/movimento** reaproveitando o sistema de perigos: labareda cíclica, roda rolando no trilho, prensa, gangorra, gato patrulha | médio | P1, P2, P3, P5 |
| T5 | **Cruzamento / atalho**: pista que passa por cima de si no mesmo nível (busca de amostra já é local) e atalho como segundo caminho curto com progresso próprio | médio–alto | P2, P6 |
| T3 | **Elevação + inclinação**: altura por ponto de controle, chão do kart segue a pista, curvas inclinadas, câmera acompanha | alto | P4, P5 |
| T6 | **Vãos + respawn**: trechos sem chão; cair devolve no último checkpoint (junta com o item do roadmap "voltar o kart preso") | médio (depois de T3) | P5 |

### Ordem sugerida
1. **T1 + T4 → P1 Churrascada e P3 Fábrica** (tecnologia barata, muda bastante o jogo).
2. **T5 → P2 Parquinho em Oito** (fecha a Copa Farofa com 3 pistas novas + uma das atuais).
3. ~~"Voltar o kart preso"~~ (v0.25) **+ T3 + T6 → P4 Geladeira e P5 Telhados** (o salto técnico grande).
4. **T2 + atalho → P6 Feira Livre.**

Cada pista nova ganha: música CC0 própria, critério de aceite com a IA completando 3 voltas sem ficar presa, tempo de volta entre 35 e 55 s, e prints de revisão.
