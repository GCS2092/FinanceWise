<?php

namespace App\Services\Ai\Contracts;

/**
 * Contrat unifié pour tous les fournisseurs d'IA (Gemini, Groq, OpenAI, Ollama...).
 * Les services métier (Coach, Insights, Categorization) ne dépendent que de cette interface.
 */
interface AiProvider
{
    /**
     * Indique si le provider est configuré (clé API présente, etc.).
     */
    public function isConfigured(): bool;

    /**
     * Nom du provider (pour logs / debug).
     */
    public function name(): string;

    /**
     * Génère une réponse à partir d'un dialogue.
     *
     * @param array  $messages [{role: 'user'|'assistant'|'system'|'tool', content: string|array, tool_call_id?: string, name?: string}]
     * @param array  $tools    Définitions d'outils au format unifié [{name, description, parameters: {type, properties, required}}]
     * @param array  $options  ['temperature', 'max_tokens', 'json_mode' => bool, 'system' => string]
     * @return AiResponse
     */
    public function generate(array $messages, array $tools = [], array $options = []): AiResponse;
}
