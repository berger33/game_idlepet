# Auditoria da Especificação — v1.0

**Data:** 17/09/2026 · **Produto:** PetShop Tycoon: Do Banho à Rede · **Status:** fundação + Playable Core

## Dez conclusões executivas de escopo

1. **O documento descreve um produto live-service de 18–30 meses, não uma única entrega.** Há 120 pets, 60 NPCs, 10 estabelecimentos, 8 cidades, 80 conquistas, 40 pesquisas, temporadas, backend, SDKs e conteúdo audiovisual. A execução correta é por gates: Playable Core → Vertical Slice → MVP comercial → soft launch → 1.0.
2. **A primeira prova de valor é clara e correta:** banho de 5–10 segundos com gesto, progressão, feedback e pet expressivo. Implementamos esse slice antes de multiplicar conteúdo.
3. **Há conflito de escopo em estabelecimentos:** §6.1 lista 10, §13.5 pede 8 e MVP pede 2. Decisão: catálogo macro mantém 10 planejados; produção de 1.0 revalida após dados; MVP entrega 2.
4. **“Offline 100%” conflita com ranking, live events, ads, IAP e cloud.** Decisão: core, save, progressão e eventos em cache funcionam offline; recursos de rede degradam explicitamente, nunca bloqueiam gameplay.
5. **“Zero pay-to-win” conflita com Starter Pack contendo 5.000 moedas e rewarded de produção/groomer.** Decisão: moedas são aceleração não exclusiva, mas vantagem paga existe. Remover moedas diretas do Starter antes de produção ou definir competição sem poder econômico. Gating competitivo será normalizado por cohort/evento.
6. **Gravação MP4 de buffer de 15 s não é recurso nativo multiplataforma do Godot.** Exige plugin Android específico, encoder, permissões, impacto térmico e revisão de privacidade. No Playable Core há marcador de momento; captura real é gate de Vertical Slice em dispositivo, com screenshot/share como fallback documentado.
7. **Plugins Firebase/AdMob/IAP não podem ser validados sem projeto Firebase, IDs de teste, console Play, keystore e aparelho.** A arquitetura usa adapters e defaults offline; integração real pertence ao milestone de monetização, nunca terá credenciais no repositório.
8. **Metas D1/D7, CTR, crash-free e tutorial não são critérios verificáveis por código local.** São gates de soft launch com amostra, janela e dashboards. Critério técnico é emissão correta, consentimento, qualidade dos dados e ausência de regressão.
9. **A meta AAB “assinado e pronto” exige identidade legal, package definitivo e chave de upload.** O preset seguro usa package placeholder e nenhum segredo. A release só avança após decisão irreversível do publisher.
10. **O custo dominante é conteúdo e polish, não engenharia.** Rig modular, atlas, style bible, orçamento de animação e validação humana evitam “cara de IA”. Arte procedural atual é deliberadamente coesa para validar sensação; não é alegada como pacote final de 120 pets.

## Dependências e caminho crítico

| Dependência | Milestone | Responsável/entrada | Risco | Estratégia |
|---|---|---|---|---|
| Godot 4.3+ export templates | Core/build | Engenharia | Médio | Pin por versão; CI headless |
| Fonte Baloo 2/Nunito/Fredoka (OFL) | Vertical Slice | Arte/UI | Baixo | Vendor com licença |
| Dispositivo Android API 24 e mid-range | Core/VS | QA | Alto | matriz física mínima de 3 aparelhos |
| AdMob app + IDs de teste | V0.5 | Publisher | Alto | adapter fake antes da credencial |
| Play Console + produtos IAP | V0.5 | Publisher | Alto | SKU em Remote Config; test tracks |
| Firebase project/config | V0.6 | Publisher | Médio | fila offline e adapter no-op |
| Plugin de captura/share compatível Godot 4 | VS | Engenharia | Alto | spike térmico; fallback screenshot |
| Keystore e package final | Release | Publisher | Crítico | fora do Git; Play App Signing |
| Privacy policy/consent | V0.5 | Legal/Product | Crítico | inventário de SDK e data safety |
| Backend de validação/ranking | Pós-MVP | Backend | Alto | Cloud Functions/Play Games; não confiar no cliente |
| 2D art/audio production | V0.3–0.8 | Conteúdo | Alto | modular, batches, style QA |
| Soft-launch cohort | V0.9 | Growth/Data | Alto | Brasil por região/canal controlado |

## Riscos e decisões abertas

- **CRITICAL:** package `com.seunome...`, entidade publicadora, privacy URL, assinatura e contas de loja.
- **HIGH:** performance/privacidade da captura MP4; validação server-side IAP; capacidade real de conteúdo; economia sem vantagem competitiva paga.
- **MEDIUM:** compatibilidade de plugins na versão Godot escolhida; acessibilidade de gesto circular; localização cultural ES/EN.
- **LOW:** assets ASO variantes e copy final (dependem de screenshot do Vertical Slice).

## Gate do Playable Core

Aceito quando: executa sem erro no Godot; serviço pode resultar em Perfect, Good e erro; toda ação crítica tem visual/som/haptic; moedas e review mudam; upgrade usa fórmula; save restaura; analytics registra; loop é compreensível sem tutorial textual longo. O ajuste de “divertido” exige playtest humano e não será declarado unilateralmente.
