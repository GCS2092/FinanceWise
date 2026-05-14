<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\User;

class PromptBuilder
{
    public function compileSystemPrompt(User $user, string $financialContextBlock, string $conversationSummary): string
    {
        $sections = config('ai.system_prompt_sections', []);
        $name = $user->name ?: 'utilisateur';
        $parts = [];
        foreach ($sections as $chunk) {
            $parts[] = trim(str_replace('{{user_name}}', $name, (string) $chunk));
        }
        $parts[] = trim($financialContextBlock);
        if ($conversationSummary !== '') {
            $parts[] = "Résumé des échanges plus anciens (compression — les chiffres exacts passent par les outils) :\n" . trim($conversationSummary);
        }

        return implode("\n\n", array_filter($parts));
    }
}
