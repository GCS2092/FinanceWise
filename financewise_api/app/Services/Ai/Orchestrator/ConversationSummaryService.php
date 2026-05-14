<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\AiConversation;
use App\Models\AiConversationSummary;
use App\Models\AiMessage;
use App\Models\User;
use App\Services\Ai\Contracts\AiProvider;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Throwable;

class ConversationSummaryService
{
    public function __construct(protected AiProvider $provider)
    {
    }

    /**
     * Compresse les messages anciens hors fenêtre récente lorsque le seuil est dépassé.
     */
    public function ensureSummaries(AiConversation $conversation, User $user): void
    {
        if (!config('services.ai.enabled', true) || !$this->provider->isConfigured()) {
            return;
        }

        $maxRecent = max(4, (int) config('ai.orchestrator.max_recent_messages', 8));
        $trigger = max(6, (int) config('ai.orchestrator.summary_trigger_messages', 14));
        $chunkSize = max($trigger, 20);

        $all = $conversation->messages()
            ->whereIn('role', ['user', 'assistant'])
            ->orderBy('id')
            ->get();

        if ($all->count() <= $maxRecent) {
            return;
        }

        $tailFirst = $all->slice(-$maxRecent)->first();
        if (!$tailFirst) {
            return;
        }
        $tailMinId = $tailFirst->id;

        /** @var Collection<int, AiMessage> $head */
        $head = $all->filter(fn (AiMessage $m) => $m->id < $tailMinId)->values();

        $safety = 0;
        while ($safety++ < 12) {
            $maxCovered = (int) ($conversation->summaries()->max('to_message_id') ?? 0);

            /** @var Collection<int, AiMessage> $uncovered */
            $uncovered = $head->filter(fn (AiMessage $m) => $m->id > $maxCovered)->values();

            if ($uncovered->count() < $trigger) {
                break;
            }

            $batch = $uncovered->take($chunkSize)->values();
            if ($batch->isEmpty()) {
                break;
            }

            try {
                $body = $this->summarizeBatch($batch);
            } catch (Throwable $e) {
                Log::warning('[AI_ERROR]', [
                    'phase' => 'conversation_summary',
                    'error' => $e->getMessage(),
                ]);
                break;
            }

            $fromId = $batch->first()->id;
            $toId = $batch->last()->id;

            AiConversationSummary::create([
                'conversation_id' => $conversation->id,
                'from_message_id' => $fromId,
                'to_message_id' => $toId,
                'body' => $body,
                'meta' => ['message_count' => $batch->count()],
            ]);

            Log::info('[AI_SUMMARY]', [
                'conversation_id' => $conversation->id,
                'from_message_id' => $fromId,
                'to_message_id' => $toId,
            ]);
        }
    }

    /**
     * @param  Collection<int, AiMessage>  $batch
     */
    protected function summarizeBatch(Collection $batch): string
    {
        $lines = [];
        foreach ($batch as $m) {
            $prefix = $m->role === 'user' ? 'Utilisateur' : 'Assistant';
            $lines[] = $prefix . ' : ' . mb_substr($m->content, 0, 1800);
        }
        $joined = implode("\n", $lines);

        $response = $this->provider->generate(
            messages: [[
                'role' => 'user',
                'content' => "Voici un extrait de conversation finance (tutoiement). Résume en 5 phrases maximum, style télégraphique, en conservant surtout : montants cités, catégories, objectifs, questions ouvertes. Ne rajoute aucun chiffre absent du texte.\n\n" . $joined,
            ]],
            tools: [],
            options: [
                'system' => 'Tu es un compresseur de contexte pour FinanceWise. Français uniquement.',
                'temperature' => (float) config('ai.orchestrator.summary_temperature', 0.2),
                'max_tokens' => (int) config('ai.orchestrator.summary_max_tokens', 350),
            ],
        );

        $text = trim((string) ($response->text ?? ''));
        if ($text === '') {
            return 'Résumé indisponible : les échanges précédents portaient sur des questions financières dans FinanceWise.';
        }

        return $text;
    }
}
