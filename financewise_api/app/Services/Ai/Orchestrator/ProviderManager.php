<?php

namespace App\Services\Ai\Orchestrator;

use App\Services\Ai\Contracts\AiProvider;
use App\Services\Ai\Contracts\AiResponse;
use Illuminate\Support\Facades\Log;

/**
 * Enveloppe l’AiProvider (Gemini, Groq, failover) avec logs structurés et métadonnées.
 */
class ProviderManager
{
    public function __construct(protected AiProvider $inner)
    {
    }

    public function name(): string
    {
        return $this->inner->name();
    }

    public function isConfigured(): bool
    {
        return $this->inner->isConfigured();
    }

    public function generate(array $messages, array $tools = [], array $options = []): AiResponse
    {
        Log::info('[AI_PROVIDER]', [
            'name' => $this->inner->name(),
            'messages_count' => count($messages),
            'tools_count' => count($tools),
            'temperature' => $options['temperature'] ?? null,
            'max_tokens' => $options['max_tokens'] ?? null,
        ]);

        $response = $this->inner->generate($messages, $tools, $options);

        $preview = mb_substr((string) ($response->text ?? ''), 0, 280);
        Log::info('[AI_RESPONSE]', [
            'provider' => $this->inner->name(),
            'text_preview' => $preview,
            'has_function_call' => $response->hasFunctionCall(),
        ]);

        return $response;
    }
}
