# Design de som — fonte única e contratos

Os efeitos do jogo **não são mais sintetizados em runtime**. Cada ação tem o seu
instrumento, modelado fisicamente em `tools/gen_sfx.py` (Python puro, sem
dependências, determinístico) e versionado como WAV em `audio/sfx/`. O
`AudioManager.gd` virou um mixer: carrega os assets, gerencia o pool de vozes,
a trilha progressiva e a música.

A música ambiente e a camada de energia continuam sintetizadas no
`AudioManager.gd` (`_ambient_loop`, `_energy_loop`) — intocadas.

## Por que assets e não síntese em runtime

Os osciladores em GDScript (seno + ruído de hash a 22 050 Hz) soavam como
8 bits: sem espaço, sem harmônicos ricos, sem ruído com caráter. Modelagem
física em Python permite Karplus-Strong, glissando de bolha, varredura de
banda, reverb Schroeder estéreo e dither TPDF — a 44 100 Hz, sem custo nenhum
na inicialização do jogo.

## Instrumentos por ação

| Ação | Arquivos | Instrumento |
|---|---|---|
| banho (esfregar) | `bubble_0..9` | bolhas d'água: glissando de Minnaert (a nota **sobe** enquanto a bolha se forma) + respingo + corpo de água |
| tosa | `clipper_0..9` | tesourada: lâmina em varredura de banda + ring metálico inarmônico + batida do fechamento |
| secagem | `dryer_0..9` | sopro de ar (ruído rosa) com corte subindo + zumbido de motor + tremolo |
| laço | `bow_0..9` | corda de náilon dedilhada (Karplus-Strong com segunda camada desafinada) |
| perfume | `spray_0..2` | aerossol: clique da válvula + chiado do bico + ping de vidro (C6→D6→E6; a 3ª é o perfect) |
| janela perfeita | `window` | harpa de vidro E6→G6 com vibrato |
| UI | `tap`, `tool_pickup`, `panel_open`, `equip` | marimba muda (fundamental + 4º parcial + feltro), gaveta, velcro |
| serviço/recompensa | `service_start`, `coin`, `perfect`, `upgrade`, `level_up`, `review`, `pass_claim`, `prestige`, `comeback`, `share_saved` | água servida, tilinte metálico, glissandos de harpa na pentatônica + shimmer |
| pets | `pet_happy`, `pet_surprise` | guinchos suaves (scoop de pitch com fase integrada) |
| erros / estado | `error_soft`, `error`, `freeze` | thud grave macio (sem bronca), gelo em vidro descendente |

## Contratos (cobertos por `tests/test_data_and_economy.py::SoundDesignTests`)

1. **Pentatônica de Dó maior** em tudo que é melódico — qualquer sequência de
   SFX fica consonante com o loop ambiente (C, Am, F, G); errar não "briga".
2. **Som progressivo**: cada gesto tem 10 degraus; `play_progress` escolhe o
   degrau pelo avanço da ação (alternando com o seguinte + micro-jitter de
   ±0,8%). Drenar ou passar da janela toca uma oitava abaixo (`pitch 0.5`) e
   mais baixo — o jogador **ouve** a aproximação dos 100%.
3. **Ticks de loop abaixo dos eventos**: pico máximo dos ticks ≤ 0,65 × o pico
   mediano dos one-shots (repetem ~6x/s).
4. **Sem artefatos digitais**: sem clipping, sem offset DC, primeiro e último
   sample em zero (nada de degrau de silêncio), durações dentro do alvo.
5. **Escadas ascendentes de verdade**, medidas no áudio embarcado: taxa de
   cruzamento de zero para bolha/tesoura e energia por Goertzel (nota
   declarada × oitavas) para a corda.
6. **Sem órfãos**: nomes no cache do `AudioManager` == WAVs em `audio/sfx` ==
   manifesto do gerador.

## Como regenerar / conferir

```bash
python tools/gen_sfx.py            # reescreve audio/sfx/*.wav + .preview/sfx/
python tools/gen_sfx.py --check    # regenera em memória e compara com os WAVs
python tools/gen_sfx.py --stats    # tabela pico/RMS/duração/nota dominante
```

`--check` roda no CI: o gerador é a fonte única, então um WAV fora de sync com
ele falha o build. A comparação tolera poucos LSB (`math.sin` depende da libm
de cada máquina) e nada além disso.

Os demos em `.preview/sfx/` (não versionados) mostram o arrastar completo de
cada serviço — rampa 0→100% com a nota subindo, swell, jitter e os 3 avisos
graves de "drenando" — além da história do perfume (`demo_perfume_janela.wav`).
