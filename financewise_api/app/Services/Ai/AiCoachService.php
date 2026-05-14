<?php

namespace App\Services\Ai;

use App\Models\User;
use App\Services\Ai\Orchestrator\AiOrchestrator;

/**
 * Coach financier conversationnel — point d’entrée stable pour le contrôleur.
 * La logique détaillée vit dans {@see AiOrchestrator}.
 */
class AiCoachService
{
    public function __construct(protected AiOrchestrator $orchestrator)
    {
    }

    public function ask(User $user, string $message, ?int $conversationId = null): array
    {
        return $this->orchestrator->handleChat($user, $message, $conversationId);
    }
}
