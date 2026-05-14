<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\AiConversation;

class ResponseFormatter
{
    /**
     * @param  array<int, array{name: string, args: array}>  $toolCalls
     */
    public function formatSuccess(
        AiConversation $conversation,
        string $reply,
        array $toolCalls,
        bool $usedLlm,
        string $intent,
        ?string $providerName,
    ): array {
        return [
            'reply' => $reply,
            'conversation_id' => $conversation->id,
            'tool_calls' => $toolCalls,
            'used_llm' => $usedLlm,
            'intent' => $intent,
            'provider' => $providerName,
        ];
    }

    public function formatDisabled(): array
    {
        return [
            'reply' => "L'assistant IA est désactivé.",
            'conversation_id' => null,
            'tool_calls' => [],
            'used_llm' => false,
            'intent' => 'disabled',
            'provider' => null,
        ];
    }
}
