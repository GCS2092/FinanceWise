# Audit architecture IA — FinanceWise (Laravel + Flutter)

**Date :** 2026-05-12  
**Périmètre :** assistant conversationnel, catégorisation, insights, providers Gemini / Groq, persistance `ai_*`.

> **Note nomenclature :** le backend utilise **Groq** (API compatible OpenAI, modèles Llama/Mixtral), pas xAI **Grok**. La doc et les variables d’environnement restent `GROQ_*`. Le failover « type Grok » correspond à ce second LLM rapide.

---

## 1. Cartographie des composants existants (avant refonte ciblée)

| Zone | Fichier / route | Rôle |
|------|-----------------|------|
| HTTP | `app/Http/Controllers/Api/AiController.php` | `POST /ai/chat`, `GET /ai/conversations`, `GET /ai/conversations/{id}`, insights, catégorisation |
| Coach | `app/Services/Ai/AiCoachService.php` | Point d’entrée stable ; délègue à l’orchestrateur |
| Orchestration | `app/Services/Ai/Orchestrator/*` | Mémoire, prompts, contexte financier, intentions, résumés, logs, provider |
| Outils | `app/Services/Ai/AiTools.php` | Function calling : agrégats SQL scoppés utilisateur |
| Providers | `GeminiProvider`, `GroqProvider`, `FailoverAiProvider` | Appels HTTP, retry 2×, failover |
| Binding | `app/Providers/AiServiceProvider.php` | Chaîne `AiProvider` + `ProviderManager` (logs) |
| Catégorisation | `app/Services/Ai/AiCategorizationService.php` | Mémoire corrections → LLM → heuristique |
| Insights | `app/Services/Ai/AiInsightsService.php` | Brief mensuel JSON, agrégats + LLM |
| Persistance | `ai_conversations`, `ai_messages`, `ai_insights`, `ai_category_corrections` | Historique + insights |
| Mémoire longue | `ai_conversation_summaries` (nouvelle) | Résumés par plage de `message_id` |
| Flutter | `lib/services/ai_service.dart`, `lib/screens/assistant_screen.dart` | Client API `/ai/*` |

---

## 2. Diagnostic — pourquoi l’IA « perdait » le contexte et devenait incohérente

### 2.1 Perte de contexte

1. **Historique brut volumineux** : jusqu’à `AI_MAX_CHAT_HISTORY` (ex. 10–20) messages *user/assistant* envoyés en entier au LLM, **sans résumé** des tours plus anciens. Au-delà de quelques échanges, le modèle ne « voit » pas les faits anciens que l’utilisateur suppose encore connus.
2. **Pas de couche mémoire structurée** : seules les lignes `ai_messages` ; pas de segment « résumé fidèle » vs « détail récent ».
3. **System prompt monolithique** : ~200+ lignes d’instructions + FAQ d’outils **répétées à chaque requête**, ce qui dilue l’attention du modèle sur le fil utile.
4. **Pas d’injection systématique d’un snapshot financier compact** : le modèle devait enchaîner d’outils pour des questions simples, ou improviser s’il ne les appelait pas.

### 2.2 Incohérences et hallucinations

1. **Température relativement haute** (ex. 0,4–0,5) sur le chat et les insights → plus de variation linguistique et de risque d’extrapolation.
2. **Contrainte « appeler un outil »** forte dans l’ancien prompt, mais le modèle peut quand même répondre entre deux appels ou reformuler des chiffres de mémoire de contexte **stale**.
3. **Function calling multi-tours** : les réponses `tool` injectent du JSON parfois volumineux ; sans compression d’historique, le modèle mélange parfois d’anciennes sorties d’outils avec la question courante.

### 2.3 Prompts trop gros

1. Ancien `systemPrompt()` dans `AiCoachService` : très long (identité + longue matrice outil/FAQ).
2. Historique complet (N messages) + éventuellement plusieurs tours d’outils → croissance **O(tours × outils)** dans une même session.
3. Insights : `json_encode($aggregates)` correct mais non borné si beaucoup de budgets / objectifs (reste acceptable).

### 2.4 Mémoire conversationnelle

- Stockage correct en base, mais **fenêtre LLM = copie brute** des derniers messages ; pas de stratégie « résumé + queue courte ».

### 2.5 Performance

1. Latence réseau × (1 + nombre de hops outils) ; pas de cache des agrégés « vue mois » entre deux messages rapprochés.
2. Failover : retries + second provider en cascade en cas d’erreur.

### 2.6 Coûts API

1. Chaque message repasse un system prompt énorme.
2. Questions statistiques simples déclenchaient quand même un aller-retout LLM + outils.
3. Pas de distinction explicite « réponse 100 % Laravel » vs « besoin LLM ».

---

## 3. Synthèse des risques

| Risque | Gravité | Mitigation mise en place |
|--------|---------|---------------------------|
| Hallucination chiffrée | Haute | Snapshot financier serveur + règles `config/ai/system_prompt.php` + outils obligatoires pour le fil LLM |
| Contexte trop long | Moyenne | Résumés `ai_conversation_summaries` + fenêtre `max_recent_messages` |
| Coût / latence | Moyenne | Intent sans LLM, cache snapshot financier TTL, température basse, prompt system modulaire |
| Défaillance provider | Moyenne | Failover existant + logs `[AI_FALLBACK]` + message de secours calculé en Laravel |

---

## 4. Nouvelle architecture (réutilisation maximale)

```
Flutter
  → POST /ai/chat (inchangé)
      → AiController → AiCoachService → AiOrchestrator
            ├── IntentDetectionService (réponses directes Laravel si possible)
            ├── ConversationSummaryService (compression hors fenêtre)
            ├── MemoryManager (résumés + N derniers messages)
            ├── FinancialContextBuilder (snapshot JSON compact + cache)
            ├── PromptBuilder (assemble config/ai/system_prompt.php + contextes)
            ├── ProviderManager → AiProvider (Gemini / Groq / Failover)
            └── ResponseFormatter (métadonnées intent / used_llm / provider)
```

**Tables :** le cahier des charges mentionnait `conversations` / `messages` / `conversation_summaries`. Le projet utilisait déjà `ai_conversations` et `ai_messages` (rôles `user|assistant|system|tool`). **Aucune migration destructive** : ajout de `ai_conversation_summaries` liée à `ai_conversations`.

---

## 5. Fichiers créés ou modifiés (principaux)

**Créés**

- `docs/ai_architecture_audit.md` (ce document)
- `config/ai.php`
- `config/ai/system_prompt.php`
- `database/migrations/2026_05_12_120000_create_ai_conversation_summaries_table.php`
- `app/Models/AiConversationSummary.php`
- `app/Services/Ai/Orchestrator/AiOrchestrator.php`
- `app/Services/Ai/Orchestrator/MemoryManager.php`
- `app/Services/Ai/Orchestrator/PromptBuilder.php`
- `app/Services/Ai/Orchestrator/FinancialContextBuilder.php`
- `app/Services/Ai/Orchestrator/ConversationSummaryService.php`
- `app/Services/Ai/Orchestrator/IntentDetectionService.php`
- `app/Services/Ai/Orchestrator/ProviderManager.php`
- `app/Services/Ai/Orchestrator/ResponseFormatter.php`

**Modifiés**

- `app/Services/Ai/AiCoachService.php` — délégation orchestrateur
- `app/Models/AiConversation.php` — relation `summaries()`
- `app/Providers/AiServiceProvider.php` — `ProviderManager`, ordre `auto` → Gemini puis Groq
- `app/Services/Ai/Providers/FailoverAiProvider.php` — logs `[AI_FALLBACK]`
- `app/Services/Ai/Providers/GroqProvider.php` — température par défaut plus basse
- `app/Services/Ai/AiInsightsService.php` — température 0,3
- `app/Http/Controllers/Api/AiController.php` — pagination `messages` + métadonnées
- `config/services.php` — défaut `AI_PROVIDER=gemini,groq`, commentaire `max_chat_history`
- `financewise_flutter/lib/services/ai_service.dart`
- `financewise_flutter/lib/screens/assistant_screen.dart`

---

## 6. Livrable synthétique (questions Partie 13)

1. **Problèmes trouvés** : cf. sections 2–3.  
2. **Nouvelle architecture** : section 4.  
3. **Pourquoi perte de contexte** : fenêtre brute + absence de résumé + prompt trop lourd.  
4. **Optimisations** : intentions sans LLM, résumés, snapshot financier caché, température 0,25–0,3, prompt modulaire, logs structurés.  
5. **Réduction coûts estimée** : **~15–40 %** de tokens prompts sur le chat (system raccourci + moins d’historique) ; **~30–100 % d’appels LLM évités** sur les requêtes correspondant aux intentions directes (salutations courtes, dépenses du mois, budgets/objectifs listés). Ordre de grandeur dépend du mélange réel des questions.  
6. **Performances** : moins de tokens → latence légèrement meilleure ; cache snapshot 90 s réduit charge DB + taille contexte.  
7. **Points restants** : streaming SSE non implémenté ; reformulation LLM des réponses directes optionnelle (`AI_REFORMULATE_DIRECT`) ; détection d’intention heuristique (affiner avec classifieur léger ou embeddings si besoin) ; politiques Laravel `Policy` si exposition multi-tenant élargie.  
8. **API messages** : `GET /ai/conversations/{id}` sans paramètres → **comportement identique à l’historique** (tous les messages). Avec `?limit=` et/ou `?before_id=` → pagination fenêtre glissante, champs `has_more` et `next_before_id`.

---

## 7. Variables d’environnement utiles

| Variable | Rôle |
|----------|------|
| `AI_PROVIDER` | ex. `gemini`, `groq`, `gemini,groq`, `auto` |
| `AI_MAX_RECENT_MESSAGES` | Taille fenêtre chat (défaut 8) |
| `AI_SUMMARY_TRIGGER_MESSAGES` | Seuil pour résumer l’historique hors fenêtre |
| `AI_FINANCIAL_CONTEXT_TTL` | TTL cache snapshot financier (secondes) |
| `AI_CHAT_TEMPERATURE` | Température chat orchestrateur |
| `AI_REFORMULATE_DIRECT` | `true` pour reformuler au LLM les réponses calculées |

---

## 8. Logs structurés

Préfixes utilisés : `[AI_REQUEST]`, `[AI_CONTEXT]`, `[AI_SUMMARY]`, `[AI_PROVIDER]`, `[AI_RESPONSE]`, `[AI_FALLBACK]`, `[AI_INTENT]`, `[AI_ERROR]`.

---

*Fin du document d’audit et d’architecture cible.*
