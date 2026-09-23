# Plano de Analytics e Dados

## Contrato
Eventos `snake_case`, nomes/params estáveis, timestamp no collector, `event_id` futuro para dedupe. Sem nome, e-mail, texto livre, localização precisa ou receipt. Moeda usa `currency_type`, `amount`, `source/sink`. IDs vêm do catálogo. Consentimento e child-directed status governam adapters; eventos essenciais podem ficar somente locais.

## Taxonomia
| Evento | Momento | Parâmetros essenciais |
|---|---|---|
| first_open | primeira execução | app_version, platform |
| tutorial_start | início | variant |
| tutorial_step | transição | step_name, elapsed_ms |
| tutorial_complete | fim | duration, retries |
| session_start/end | lifecycle | duration no end, entry |
| service_start | confirmou | type, pet_id, station_id |
| service_complete | reward commitado | type, quality, duration, reward |
| service_fail | falha terminal | type, reason, progress |
| pet_arrived | spawn aceito | pet_id, rarity, customer_type |
| pet_left | saída sem serviço | reason, patience |
| perfect_service | classificação | type, combo_before |
| combo_reached | marcos 2/3/5/10/20/50 | level |
| establishment_upgrade | spend commitado | id, level, cost |
| staff_hired | aquisição | id, rarity, source |
| currency_earned/spent | ledger | type, amount, source/sink, balance_after |
| offline_reward | cálculo | seconds, amount, cap_hit |
| rewarded_offer | oferta visível | type, placement, eligible |
| rewarded_start/complete | lifecycle ad | type, provider, reward_id |
| interstitial_impression | callback confirmado | placement, minutes_session |
| shop_open | loja visível | entry |
| iap_view/start/success/fail | billing | sku, localized_price no view, reason |
| daily_reward | claim idempotente | day, cycle_id |
| daily_mission_complete | commit | id, rerolled |
| event_start/complete | progress | id, score/tier |
| collection_unlock | novo item | id, category, rarity, source |
| clip_exported | arquivo compartilhável criado | type, duration, share_target opcional categórico |
| notification_scheduled/open | local push | template_id, delay_bucket |
| config_activated | config aceita | version, fetch_source |
| save_recovered | backup usado | slot, reason |
| churn_risk_signal | regra interna | reason categórico |

`iap_success` só ocorre após acknowledge + validação definida. `rewarded_complete` só após callback e ledger idempotente. Falhas têm enum, nunca mensagem bruta de SDK.

## Funis
1. Install → tutorial_start → tutorial_complete → service_start → service_complete → first_upgrade → D1.
2. Offer → rewarded_start → complete → próxima ação → session_end.
3. Shop → iap_view → start → success; separar pending/cancel/provider error.
4. Pet arrival → serve → completion → review → repeat pet.

## KPIs
Retenção clássica e rolling D1/3/7/14/30; DAU/MAU; p50/p90 sessão; sessões/DAU; serviços/sessão; perfect/fail; TTFU; coleção D7; ad opt-in/completion/frequency; conversion, ARPDAU/ARPPU/LTV; crash-free/ANR. Todos por app version, acquisition, country, hardware tier e experiment, preservando privacidade/amostra mínima.

## Qualidade
Schema registry versionado, teste automático de required params, painel de eventos desconhecidos, reconciliação ledger vs purchase, lateness e duplicate rate. Sandbox/dev traffic excluído. Alertas: queda >30% de event volume, tutorial_complete impossível, currency negativo, ad antes de policy cap, purchase sem grant.

## Dashboards
Executive (retention/health/revenue), onboarding, core loop, economy, monetization ethics, LiveOps, technical. Owner e frequência de revisão explícitos. A decisão acompanha hipótese, período, amostra, intervalo e guardrails — não só screenshot.

## Remote Config
Chaves por namespace e versão; defaults locais; allowlist/type/range; rollout gradual; kill switch; last-known-good; exposição de experimento registrada antes do outcome. Não confiar em config cliente para entitlement, receipt ou ranking.
