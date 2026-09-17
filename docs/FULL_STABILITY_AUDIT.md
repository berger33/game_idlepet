# Auditoria Completa de Estabilidade

**Data:** 17/09/2026 · **Escopo:** código, dados, saves, economia, UI, input, áudio, lifecycle e build metadata

## Resultado executivo

A auditoria encontrou inconsistências funcionais e pontos de crash defensivo que não apareciam nos testes de catálogo. Todos os itens reproduzíveis por inspeção foram corrigidos. A base passou por parser/linter GDScript, testes Python, validação estrutural, simulações de 120 níveis e verificação Git. O runtime Godot e aparelhos Android ainda são um gate obrigatório: nenhum processo estático pode provar ausência absoluta de crash gráfico, driver, plugin ou lifecycle.

## Achados corrigidos

### HIGH

1. **Excesso classificado como Good.** `BathService.finish()` aceitava todo progresso de 62% a 99%, embora HUD marcasse acima da janela como erro. Agora 62% até o início da janela é Good, janela é Perfect e qualquer valor acima do máximo é `overwashed`.
2. **Save tipado podia falhar com arrays malformados.** `Array[String].assign()` recebia Variant sem validação. Agora strings, IDs de pets, dicionários, números, settings, afeto e limites são sanitizados; Caramelo é restaurado se não houver pet válido.
3. **Save futuro era aceito silenciosamente.** Saves com versão maior que a suportada agora são rejeitados e o loader tenta os backups, evitando downgrade destrutivo.
4. **Seleção de pet podia dividir por zero.** O fluxo de próximo cliente agora possui fallback explícito para Caramelo mesmo se o estado vier vazio.
5. **Remote Config aceitava valores perigosos.** Agora há allowlist, tipo, finite check, faixa por chave e reparo da relação `target_min < target_max`.
6. **Recompensa offline não aparecia.** O evento era emitido antes de a cena conectar ao EventBus. SaveManager agora mantém recompensa pendente, consumida pela Main com toast e áudio após a UI estar pronta.

### MEDIUM

7. **Três de dez conquistas funcionavam.** Todas as dez são avaliadas: primeiro banho, Perfect 1/10, combo 5/20, 500 moedas, upgrade 5, dez reviews 5 estrelas, cinco pets e uma hora offline. Recompensas agora coincidem com o catálogo.
8. **Estatísticas cumulativas ausentes.** Save v5 adiciona Perfects totais, reviews 5 estrelas e segundos offline coletados, com migração v4→v5.
9. **Missões divergiam do HUD.** O HUD prometia 75 moedas para três missões, mas JSON declarava Brasas/60 moedas e “banho” contava tosa. As três missões ativas agora usam métricas coerentes e 75 moedas.
10. **Rollback permitia repetir daily.** Datas iguais/anteriores à última coleta são recusadas e registradas como sinal de clock rollback.
11. **Tela de daily anunciava o próximo dia após coletar.** Agora mostra o dia efetivamente coletado e estado “Coletado hoje”.
12. **CTA de Ajustes dizia “Coletar recompensas”.** Agora muda para “Alternar modo econômico”; ações irrelevantes ficam escondidas em Coleção/Mapa.
13. **Tosa produzia bolhas e som de espuma.** Agora produz tufos com a cor do pet e SFX próprio de máquina.
14. **Timeout continuava atualizando HUD.** `_process` agora retorna imediatamente após falha terminal.
15. **Estado visual vazava entre pets.** Reset limpa ferramenta, reação, bolhas e corações.
16. **Resultado dizia “Banho Quente” durante tosa.** Marco passou a “Ritmo Perfeito”.
17. **Erro de tosa falava em espuma.** Mensagens agora são específicas ao serviço e ao motivo.
18. **Upgrade era chamado de banheira durante tosa.** Copy passou a “estação”.
19. **Busca frágil por `get_child(0)`.** O label do pedido agora tem referência tipada própria.
20. **Índice semanal não tinha clamp.** LiveOps limita weekday a 0–6.

### LOW / HARDENING

21. Volumes são limitados antes de `linear_to_db`, evitando valor inválido ou ganho excessivo.
22. Níveis, moedas, reviews, combo, prestígio, XP, tier e tempo recebem clamps na restauração.
23. IDs duplicados de arrays salvos são removidos.
24. Afeto é limitado a 50 e filtrado por catálogo.
25. Catálogo possui verificador de recursos `res://`, cores, raridades, serviços, tiers, crescimento econômico, arquivos grandes e credenciais proibidas.
26. Afeto agora para em 50 e só paga cada marco uma vez; evita overflow e repetição de Brasas.
27. Missões detectam virada do dia mesmo com o aplicativo aberto durante a meia-noite.
28. Foi criado teste Godot headless para boundaries do banho, monotonicidade econômica, conteúdo e recuperação de estado malformado.

## Matriz executada

| Teste | Resultado |
|---|---|
| `python3 tools/validate_project.py` | 0 erros, 0 warnings |
| `python3 -m unittest discover -s tests -v` | aprovado |
| JSON parse de todos os catálogos | aprovado |
| IDs únicos, 15 cães/15 gatos | aprovado |
| Carreira média ≥60 h e expert ≥50 h | aprovado |
| Simulação econômica 120 níveis | finita/monotônica |
| `gdformat --check` | aprovado |
| `gdlint` em autoload/core/scenes/teste Godot | 0 problemas |
| `git diff --check` | aprovado |
| referências `res://` | todas existentes |
| higiene de credenciais/arquivos >5 MB | aprovado |

## Testes preparados para runtime

Quando Godot 4.3+ estiver instalado:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script tests/run_godot_tests.gd
godot --path .
```

O segundo comando testa no próprio engine: 61%/70%/90%/97% do banho, 121 níveis de custo, offline negativo, prestígio, 30 pets, tier 10 e sanitização de save adversarial.

## Riscos externos ainda não elimináveis neste ambiente

- Import/render real dos PNGs e layout em múltiplas proporções.
- APIs específicas da versão exata do Godot/export template.
- Android pause/resume, low-memory, back gesture, áudio e vibração física.
- AdMob, Billing, Firebase e notificações: providers reais ainda dependem de contas, plugins e aparelho.
- AAB, target SDK, assinatura e Play internal track.
- FPS, memória, temperatura e crash-free users exigem hardware/telemetria.

Esses riscos não são bugs confirmados, mas impedem afirmar matematicamente “funciona perfeitamente”. O estado correto é: **sem inconsistências estáticas conhecidas, com defesas de dados e suíte pronta para validação no engine/aparelho**.
