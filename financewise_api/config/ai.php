<?php

$systemPromptSections = require __DIR__ . '/ai/system_prompt.php';

return [
    'system_prompt_sections' => $systemPromptSections,

    'orchestrator' => [
        /** Nombre max de paires user/assistant récentes envoyées au LLM (hors boucle outils). */
        'max_recent_messages' => (int) env('AI_MAX_RECENT_MESSAGES', 8),
        /** Nombre de messages (user+assistant) « anciens » non couverts par un résumé avant de déclencher un résumé auto. */
        'summary_trigger_messages' => (int) env('AI_SUMMARY_TRIGGER_MESSAGES', 14),
        'financial_context_ttl_seconds' => (int) env('AI_FINANCIAL_CONTEXT_TTL', 90),
        /** Température pour le chat financier (bas = plus factuel). */
        'chat_temperature' => (float) env('AI_CHAT_TEMPERATURE', 0.25),
        'chat_max_tokens' => (int) env('AI_CHAT_MAX_TOKENS', 512),
        /** Si true, les réponses entièrement calculées côté serveur passent quand même par le LLM pour reformuler (plus de coût). */
        'reformulate_direct_answers' => filter_var(env('AI_REFORMULATE_DIRECT', false), FILTER_VALIDATE_BOOLEAN),
        /** Résumés conversationnels : tokens max pour la sortie du modèle. */
        'summary_max_tokens' => (int) env('AI_SUMMARY_MAX_TOKENS', 350),
        'summary_temperature' => (float) env('AI_SUMMARY_TEMPERATURE', 0.2),
    ],
];
