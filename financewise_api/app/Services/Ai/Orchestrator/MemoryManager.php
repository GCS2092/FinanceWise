<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\AiConversation;

class MemoryManager
{
    public function combinedSummaryText(AiConversation $conversation): string
    {
        return $conversation->summaries()
            ->orderBy('to_message_id')
            ->get()
            ->pluck('body')
            ->filter()
            ->implode("\n---\n");
    }

    /**
     * @return array<int, array{role: string, content: string}>
     */
    public function buildRecentTranscript(AiConversation $conversation, int $maxRecent): array
    {
        $rows = $conversation->messages()
            ->whereIn('role', ['user', 'assistant'])
            ->orderBy('id')
            ->get();

        $tail = $rows->slice(max(0, $rows->count() - $maxRecent))->values();

        $out = [];
        foreach ($tail as $m) {
            $out[] = [
                'role' => $m->role,
                'content' => $m->content,
            ];
        }

        return $out;
    }
}
