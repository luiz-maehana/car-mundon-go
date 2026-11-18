# Car'mundon'GO! — Especificação (MVP)

> Spec viva do projeto. Toda feature nova entra aqui **antes** do código, com ID e critério de aceite.
> Status: `[x]` feito · `[ ]` pendente · `[~]` parcial.

## 1. Visão

Jogo de corrida de kart arcade 3D (gênero kart racer: drift com mini-turbo, caixas de item, 8 pilotos), em que os pilotos são a nossa turma. Objetivo do MVP: **uma corrida completa, divertida e jogável do menu até o pódio**, para validar a sensação de pilotagem antes de investir em arte, pistas e multiplayer.

- Engine: **Godot 4.7** (GDScript), renderer *Compatibility* (roda em PC fraco e permite exportar pra web depois).
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
- [x] **RF-16** Kart da IA preso (parado > 2.5 s) ou qualquer kart fora dos limites é reposicionado no centro da pista.

### Itens
- [x] **RF-20** 3 fileiras de 4 caixas "?" na pista. Passar por uma dá um item (se o slot estiver vazio); a caixa volta em 3 s.
- [x] **RF-21** Sorteio depende da posição: quem está atrás ganha mais turbo e bomba, quem lidera ganha mais casca.
- [x] **RF-22** **Turbo:** 1.3 s de velocidade +30%.
- [x] **RF-23** **Casca:** largada atrás do kart; quem passa em cima roda (perde controle 1.1 s e 65% da velocidade).
- [x] **RF-24** **Bomba:** projétil reto pra frente; explode no muro, em outro kart (que roda) ou em uma casca (as duas somem).

### Corrida
- [x] **RF-30** Grid de largada 2×4 atrás da linha; jogador larga em último.
- [x] **RF-31** Contagem 3-2-1-VAI! Ninguém se move antes do VAI.
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
- [x] **RF-111** No kart, o piloto é um camundongo de capacete na cor do piloto, com orelhonas e nome em cima. A arte dos rostos **não** aparece na pista.
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
- **RNF-04** Nos testes headless o motor (AudioStreamGenerator) fica desligado: com o driver de áudio *dummy* do Godot 4.7 ele dá segfault junto com a tela dividida. Com driver real: 0 crashes em 36 corridas de 4 jogadores (`tools/stress_races.gd -- mp`, com janela). Os motores de todos os jogadores são mixados num gerador só.

## 7. Arquitetura

```
scenes/intro.tscn    -> scripts/intro.gd       tela de abertura (cena principal)
scenes/menu.tscn     -> scripts/menu.gd        jogadores, seleção de piloto e voltas
scenes/race.tscn     -> scripts/race.gd        orquestra a corrida (estado, itens, colisões, ranking, câmera)
scripts/game.gd      (autoload "Game")         piloto escolhido, voltas, mapa de inputs
scripts/characters.gd                          dados dos 8 pilotos
scripts/track.gd                               pista procedural (Catmull-Rom -> amostras a cada 2 m) + malhas
scripts/kart.gd                                física arcade, drift, IA, visual do kart
scripts/hud.gd, scripts/minimap.gd             interface
tests/run_tests.gd                             testes headless
tools/screenshot.gd                            prints do menu/corrida para revisão visual
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

Teste manual (checklist por release):
- [ ] Dá pra ganhar a corrida jogando bem; dá pra perder jogando mal.
- [ ] Drift é controlável e o mini-turbo é perceptível.
- [ ] 60 fps estáveis num PC comum.

## 9. Roadmap pós-MVP (cada item vira seção nova desta spec)
1. **Rostos/modelos dos amigos** — fotos já suportadas em `assets/faces/`; depois modelos low-poly.
2. ~~**Multiplayer local** em tela dividida (2–4 jogadores).~~ → §4 RF-60..67.
3. ~~**Áudio**~~ → §4 RF-80..83.
4. ~~**Mais pistas**~~ → §4 RF-120..122. Falta: elevação, rampas, atalhos e modo Grand Prix (pontos somados nas 3 pistas).
5. **Mais itens** (escudo, raio, item "assinatura" por piloto).
6. ~~**Largada turbo**~~ → §4 RF-85..87.
7. **Export web** (GitHub Pages) pra turma jogar no navegador.
8. **Multiplayer online.**
