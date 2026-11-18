# Car'mundon'GO!

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
- Traçado da pista: `CONTROL_POINTS` em `scripts/track.gd` (o teste CA-02 avisa se trechos se sobrepuserem)

## Multiplayer local
No menu, `JOGADORES: N` (1–4). Cada jogador confirma o seu piloto em sequência (Backspace desfaz).
J1 = WASD + Espaço/E ou controle 1 · J2 = setas + Shift dir./Enter ou controle 2 · J3/J4 = controles 3/4.

## Som e pause
Todo som é sintetizado em código (`scripts/sfx.gd`). `M` liga/desliga · `Esc`/Start pausa.
Largada turbo: comece a acelerar quando aparecer o **2** (entre 1.6 s e 0.6 s do VAI). Antes disso, queima.
