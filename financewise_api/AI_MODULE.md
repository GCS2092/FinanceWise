# Module IA — FinanceWise

Assistant financier intelligent multi-provider (Groq, Gemini), intégré au backend Laravel et exposé au Flutter.

## Providers supportés

| Provider | Tier gratuit | Carte bancaire | Région | Recommandé |
|---|---|---|---|---|
| **Groq** | 30 req/min, 14 400/jour | Non | Mondial | ✅ Sénégal & Afrique |
| **Gemini** | 15 req/min, 1500/jour | Non | Limité (USA, EU…) | ⚠️ Pas dispo partout |

Le choix se fait via `AI_PROVIDER=groq|gemini` dans `.env`. Tout le code métier est provider-agnostic (interface `AiProvider`).

## Mise en route — Groq (recommandé)

### 1. Créer une clé

- https://console.groq.com/keys (compte Google, pas de carte bancaire)
- Cliquer **"Create API Key"**, copier la clé (commence par `gsk_...`)

### 2. Configurer `.env`

```env
AI_ENABLED=true
AI_PROVIDER=groq
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxx
GROQ_MODEL=llama-3.3-70b-versatile
```

### 3. Vider le cache + migrer

```bash
php artisan config:clear
php artisan migrate
```

### 4. Tester

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8000/api/ai/status
# → {"enabled":true,"provider":"groq","configured":true,"model":"llama-3.3-70b-versatile"}
```

## Modèles Groq recommandés

| Modèle | Force | Vitesse | Quand l'utiliser |
|---|---|---|---|
| `llama-3.3-70b-versatile` | Qualité max, function calling | ~1 s | **Défaut** — chat coach, brief |
| `llama-3.1-8b-instant` | Ultra rapide | ~300 ms | Catégorisation à haut volume |
| `mixtral-8x7b-32768` | Long contexte (32k tokens) | ~1 s | Analyses sur historique étendu |

Change simplement `GROQ_MODEL` dans `.env`.

## Fonctions disponibles

| Fonction | Description | Endpoint |
|---|---|---|
| **Chat coach** | Conversation libre avec function calling — l'IA peut interroger transactions, budgets, objectifs en temps réel | `POST /api/ai/chat` |
| **Brief mensuel** | Résumé narratif + highlights + suggestions, généré le 1er du mois ou à la demande | `GET /api/ai/insights/monthly` |
| **Catégorisation** | Suggère une catégorie pour une description / SMS, apprend des corrections utilisateur | `POST /api/ai/categorize` |
| **Apprentissage** | Enregistre une correction utilisateur pour améliorer la catégorisation | `POST /api/ai/categorize/learn` |
| **Status** | État du provider | `GET /api/ai/status` |
| **Conversations** | Liste / consulter / supprimer l'historique | `GET/DELETE /api/ai/conversations[/{id}]` |

## Architecture

```
app/Services/Ai/
├── Contracts/
│   ├── AiProvider.php           # interface (chat, isConfigured, name)
│   └── AiResponse.php           # réponse normalisée (text + functionCall)
├── Providers/
│   ├── GeminiProvider.php       # Google Gemini REST
│   └── GroqProvider.php         # Groq (compatible OpenAI)
├── AiTools.php                  # 6 outils scopés user (function calling)
├── AiCoachService.php           # boucle chat (max 3 hops d'outils)
├── AiInsightsService.php        # brief mensuel JSON
└── AiCategorizationService.php  # mémoire + LLM + heuristique

app/Providers/
└── AiServiceProvider.php        # bind AiProvider selon AI_PROVIDER

app/Http/Controllers/Api/
└── AiController.php             # endpoints /api/ai/*
```

### Function calling unifié

Le format est normalisé dans `AiProvider::generate()`. Chaque provider traduit en interne :
- **Gemini** : `tools: [{functionDeclarations: [...]}]` + `functionCall` / `functionResponse`
- **Groq/OpenAI** : `tools: [{type: "function", function: {...}}]` + `tool_calls` / `tool` role

Les services métier (`AiCoachService`, `AiInsightsService`, `AiCategorizationService`) ne connaissent que l'interface — ajouter Ollama ou Mistral demande juste un nouveau provider.

### Outils disponibles (`AiTools.php`)

- `get_monthly_summary(month?)`
- `get_transactions_by_category(category, month?)`
- `get_budget_status()`
- `get_goal_progress()`
- `get_top_expenses(limit?, month?)`
- `get_wallets()`

Toutes scopées au user authentifié — l'IA ne voit jamais les données d'un autre utilisateur.

## Sécurité & coûts

- **Rate limit** : 20 req/min/user (`throttle:ai`)
- **Token limit** : 1024 tokens / réponse, 800 / brief
- **Historique** : 10 derniers messages envoyés au LLM
- **Coût** :
  - Groq : 0 € jusqu'à 14 400 req/jour
  - Gemini : 0 € jusqu'à 1 500 req/jour (si free tier dispo dans la région)
- **Fallback** : si LLM indisponible, brief avec highlights heuristiques + catégorisation par règles. L'app ne casse jamais.

## Cron pour le brief mensuel

```cron
* * * * * cd /path-to-project && php artisan schedule:run >> /dev/null 2>&1
```

Le brief est planifié le 1er du mois à 19h. Génération manuelle :

```bash
php artisan ai:monthly-insights
php artisan ai:monthly-insights --period=2026-04 --user=1
```

## Côté Flutter

```
lib/services/ai_service.dart       # client HTTP IA
lib/screens/assistant_screen.dart  # chat avec suggestions
lib/screens/recommendations_screen.dart
lib/widgets/ai_insight_card.dart   # carte "Brief du mois" sur le Dashboard
```

Accessible depuis le menu **Plus** → *Assistant IA* / *Recommandations*.
La catégorisation IA est intégrée dans :
- `widgets/sms_confirmation_dialog.dart` (SMS Wave/OM)
- `screens/transaction_form_screen.dart` (saisie manuelle, debounce 800 ms)

## Changer de provider à chaud

```env
# Aujourd'hui sur Groq, demain sur Gemini :
AI_PROVIDER=gemini
```

Puis `php artisan config:clear`. Aucun redéploiement nécessaire.
