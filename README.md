# Car Mundon'GO

Kart racer arcade em Godot 4.7 com a turma como pilotos. Especificação completa em [SPEC.md](SPEC.md).

## Rodar
Abra a pasta no Godot 4.7 e aperte F5 — ou pela linha de comando:

```
godot --path .
```

## Testes (critérios de aceite da spec)
```
godot --headless --path . --script tests/run_tests.gd
```
Simula uma corrida inteira de 3 voltas só com IA e valida pista, ranking, muros e itens.

## Screenshots para revisão
```
godot --path . --script tools/screenshot.gd -- <pasta_saida>
```

## Fluxo de desenvolvimento (spec-driven)
1. Escreva/atualize o requisito em `SPEC.md` (ID `RF-xx` + critério de aceite).
2. Se der pra automatizar, adicione o teste em `tests/run_tests.gd` (`CA-xx`).
3. Implemente, rode os testes, marque `[x]` na spec.

## Personalizar
- Stats/cores dos pilotos: `scripts/characters.gd`
- Arte dos pilotos: coloque as ilustrações (fundo liso) numa pasta e rode `godot --headless --path . --script tools/process_characters.gd -- <pasta>`; gera `assets/chars/`
- Pistas: `TRACKS` em `scripts/track.gd` (pontos + tema). O teste CA-02 avisa se trechos se sobrepuserem.

## Multiplayer local
No menu, `JOGADORES: N` (1–4). Cada jogador confirma o seu piloto em sequência (Backspace desfaz).
J1 = WASD + Espaço/E ou controle 1 · J2 = setas + Shift dir./Enter ou controle 2 · J3/J4 = controles 3/4.

## Som e pause
Todo som é sintetizado em código (`scripts/sfx.gd`). `M` liga/desliga · `Esc`/Start pausa.
Largada turbo: comece a acelerar quando aparecer o **2** (entre 1.6 s e 0.6 s do VAI). Antes disso, queima.

## Dicas de pilotagem
- **Drift** (segure Espaço virando): faísca azul → laranja → roxa = turbo cada vez maior.
- **Rampa**: aperte drift no ar pra fazer a manobra e ganhar turbo no pouso.
- **Setas no chão** dão turbo; andar **colado atrás** de alguém dá turbo de vácuo.
- **Queijinhos**: cada um deixa o kart 1% mais rápido (até 10); levar casca/bomba tira 3.

## Gráficos
Renderer Forward+ com bloom, SSAO, neblina e texturas procedurais. Em PC fraco, abra **CONFIGURAÇÕES → VÍDEO** e use qualidade BAIXO e/ou escala de resolução menor.
Medido numa RTX 5070: 1 jogador ~180 FPS (vsync), 4 jogadores ~90 FPS.

## Configurações
Menu → **CONFIGURAÇÕES** (ou Esc → Configurações durante a corrida): volumes (geral/música/efeitos/motor), tela cheia, vsync, limite de FPS, qualidade, resolução 3D, campo de visão, FPS na tela, tremida, linhas de velocidade, partículas, nomes, minimapa, lista de posições, km/h ou mph e zona morta do analógico. Salvo em `user://settings.cfg`.

## Grand Prix
No menu, **MODO: GRAND PRIX** (canto superior esquerdo): as 3 pistas em sequência, pontos 15·12·10·8·6·4·2·1 por corrida, e pódio do campeão no final. Desempate: vitórias, depois a última corrida.
