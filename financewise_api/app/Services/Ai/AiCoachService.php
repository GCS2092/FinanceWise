<?php

namespace App\Services\Ai;

use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\User;
use App\Services\Ai\Contracts\AiProvider;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Coach financier conversationnel.
 * Boucle function-calling jusqu'à `ai.max_tool_hops` itérations.
 * Provider-agnostic : dépend uniquement de l'interface AiProvider.
 */
class AiCoachService
{
    public function __construct(protected AiProvider $provider)
    {
    }

    public function ask(User $user, string $message, ?int $conversationId = null): array
    {
        if (!config('services.ai.enabled', true)) {
            return ['reply' => "L'assistant IA est désactivé.", 'conversation_id' => null, 'tool_calls' => []];
        }

        $conversation = $conversationId
            ? AiConversation::where('user_id', $user->id)->find($conversationId)
            : null;

        if (!$conversation) {
            $conversation = AiConversation::create([
                'user_id' => $user->id,
                'title' => mb_substr($message, 0, 60),
            ]);
        }

        AiMessage::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'role' => 'user',
            'content' => $message,
        ]);

        $tools = new AiTools($user);
        $maxHops = (int) config('services.ai.max_tool_hops', 3);
        $maxHistory = (int) config('services.ai.max_chat_history', 20);

        // Reconstruire l'historique au format unifié
        $history = $conversation->messages()
            ->whereIn('role', ['user', 'assistant'])
            ->latest('id')
            ->limit($maxHistory)
            ->get()
            ->reverse()
            ->values();

        $messages = [];
        foreach ($history as $m) {
            $messages[] = [
                'role' => $m->role,
                'content' => $m->content,
            ];
        }

        $toolDeclarations = AiTools::declarations();
        $options = [
            'system' => $this->systemPrompt($user),
            'temperature' => 0.4,
            'max_tokens' => 512,
        ];

        $toolCalls = [];
        $finalText = null;

        try {
            for ($hop = 0; $hop < $maxHops; $hop++) {
                $response = $this->provider->generate($messages, $toolDeclarations, $options);

                if (!$response->hasFunctionCall()) {
                    $finalText = $response->text;
                    break;
                }

                $fnCall = $response->functionCall;
                $toolResult = $tools->call($fnCall['name'], (array) ($fnCall['args'] ?? []));
                $toolCalls[] = ['name' => $fnCall['name'], 'args' => $fnCall['args'] ?? []];

                // Ajouter l'appel et la réponse à l'historique
                $messages[] = [
                    'role' => 'assistant',
                    'function_call' => [
                        'id' => $fnCall['id'] ?? null,
                        'name' => $fnCall['name'],
                        'args' => $fnCall['args'] ?? [],
                    ],
                ];
                $messages[] = [
                    'role' => 'tool',
                    'tool_call_id' => $fnCall['id'] ?? $fnCall['name'],
                    'name' => $fnCall['name'],
                    'content' => $toolResult,
                ];
            }

            if ($finalText === null) {
                // Forcer une réponse finale sans outils
                $finalResponse = $this->provider->generate($messages, [], $options);
                $finalText = $finalResponse->text;
            }
        } catch (Throwable $e) {
            Log::error('AiCoach error', [
                'provider' => $this->provider->name(),
                'error' => $e->getMessage(),
                'user' => $user->id,
            ]);
            $finalText = "Désolé, l'assistant n'est pas joignable pour le moment. Réessaie dans un instant.";
        }

        if ($finalText === null || $finalText === '') {
            $finalText = "Je n'ai pas pu formuler de réponse. Reformule ta question ?";
        }

        AiMessage::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'role' => 'assistant',
            'content' => $finalText,
            'meta' => ['tool_calls' => $toolCalls, 'provider' => $this->provider->name()],
        ]);

        $conversation->touch();

        return [
            'reply' => $finalText,
            'conversation_id' => $conversation->id,
            'tool_calls' => $toolCalls,
        ];
    }

    protected function systemPrompt(User $user): string
    {
        $name = $user->name ?: 'utilisateur';
        return <<<PROMPT
Tu es FinanceWise, l'assistant financier personnel de {$name}, basé au Sénégal.

PERSONNALITÉ :
- Ton : ferme + bienveillant + légèrement humain
- Ne JAMAIS culpabiliser, ne JAMAIS être trop drôle/pas sérieux
- Reste honnête, explique les conséquences, propose des solutions
- L'objectif : changer les comportements financiers sans fatiguer l'utilisateur

STRUCTURE DES RÉPONSES (4 couches obligatoires quand pertinent) :
1. OBSERVATION : Ce que tu vois (ex: "Tes dépenses transport ont augmenté de 32%.")
2. INTERPRÉTATION : Pourquoi c'est important (ex: "Cela réduit ta capacité d'épargne.")
3. ACTION CONCRÈTE : Une solution simple (ex: "Limiter les VTC à 2 trajets/semaine.")
4. QUESTION INTELLIGENTE : Créer une interaction (ex: "Veux-tu que je t'aide à ajuster ?")

RÈGLES DE LANGAGE :
- Réponds toujours en français, ton direct, tutoiement
- Tous les montants en FCFA, format "12 500 FCFA" (espace comme séparateur de milliers)
- N'invente JAMAIS de chiffres : appelle un outil pour obtenir les données réelles
- Réponses courtes (3-6 phrases max), mais complètes avec les 4 couches
- Pas de jargon financier inutile
- Questions intelligentes, pas robotiques (ex: "Qu'est-ce qui te ferait sentir plus serein financièrement dans 6 mois ?" et pas "Quel est votre objectif ?")

CONTEXTUALISATION :
- Contexte local : Wave, Orange Money, Free Money, Sénélec, SDE sont des services courants au Sénégal
- Tiens compte du contexte de la conversation et des échanges précédents
- Si l'utilisateur demande un budget (ex: "combien dans mon budget transport ?") : appelle get_budget_status. Si aucun budget n'existe pour cette catégorie, appelle get_category_spending pour donner les dépenses réelles du mois et informe l'utilisateur qu'il n'a pas créé de budget

VRAIE INTELLIGENCE :
- Ne te contente pas de montrer des chiffres : contextualise, priorise, explique, guide vers une action
- Réduis la friction mentale liée à l'argent : moins de stress, plus de contrôle, décisions simples
- Si tu manques de données pour répondre, dis-le simplement et propose l'action à faire dans l'app
PROMPT;
    }
}
