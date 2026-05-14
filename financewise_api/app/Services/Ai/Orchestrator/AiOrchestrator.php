<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\User;
use App\Services\Ai\AiTools;
use Illuminate\Support\Facades\Log;
use Throwable;

class AiOrchestrator
{
    public function __construct(
        protected ProviderManager $providers,
        protected MemoryManager $memory,
        protected PromptBuilder $promptBuilder,
        protected FinancialContextBuilder $financialContext,
        protected ConversationSummaryService $conversationSummary,
        protected IntentDetectionService $intentDetection,
        protected ResponseFormatter $responseFormatter,
    ) {
    }

    public function handleChat(User $user, string $message, ?int $conversationId = null): array
    {
        if (!config('services.ai.enabled', true)) {
            return $this->responseFormatter->formatDisabled();
        }

        Log::info('[AI_REQUEST]', [
            'user_id' => $user->id,
            'conversation_id' => $conversationId,
            'message_chars' => mb_strlen($message),
        ]);

        $conversation = $this->resolveConversation($user, $message, $conversationId);

        AiMessage::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'role' => 'user',
            'content' => $message,
        ]);

        $intent = $this->intentDetection->detect($user, $message);
        Log::info('[AI_INTENT]', [
            'intent' => $intent['intent'],
            'skip_llm' => $intent['skip_llm'],
        ]);

        if (!empty($intent['skip_llm']) && isset($intent['direct_reply'])) {
            $reply = $intent['direct_reply'];
            if (config('ai.orchestrator.reformulate_direct_answers') && $this->providers->isConfigured()) {
                $reply = $this->reformulateDirect($user, $message, $reply);
            }

            AiMessage::create([
                'conversation_id' => $conversation->id,
                'user_id' => $user->id,
                'role' => 'assistant',
                'content' => $reply,
                'meta' => [
                    'tool_calls' => [],
                    'provider' => 'laravel_direct',
                    'intent' => $intent['intent'],
                    'used_llm' => false,
                ],
            ]);
            $conversation->touch();

            return $this->responseFormatter->formatSuccess(
                $conversation,
                $reply,
                [],
                false,
                $intent['intent'],
                'laravel_direct',
            );
        }

        $this->conversationSummary->ensureSummaries($conversation, $user);

        $maxRecent = max(4, (int) config('ai.orchestrator.max_recent_messages', 8));
        $transcript = $this->memory->buildRecentTranscript($conversation, $maxRecent);
        $summaryText = $this->memory->combinedSummaryText($conversation);
        if ($summaryText !== '') {
            Log::info('[AI_SUMMARY]', ['attached_chars' => mb_strlen($summaryText)]);
        }

        $financial = $this->financialContext->build($user);
        $system = $this->promptBuilder->compileSystemPrompt($user, $financial, $summaryText);

        $messages = $transcript;
        $tools = AiTools::declarations();
        $maxHops = (int) config('services.ai.max_tool_hops', 3);
        $options = [
            'system' => $system,
            'temperature' => (float) config('ai.orchestrator.chat_temperature', 0.25),
            'max_tokens' => (int) config('ai.orchestrator.chat_max_tokens', 512),
        ];

        $toolCalls = [];
        $finalText = null;
        $providerUsed = $this->providers->name();
        $usedLlm = true;

        try {
            $toolsRunner = new AiTools($user);
            for ($hop = 0; $hop < $maxHops; $hop++) {
                $response = $this->providers->generate($messages, $tools, $options);

                if (!$response->hasFunctionCall()) {
                    $finalText = $response->text;
                    break;
                }

                $fnCall = $response->functionCall;
                $toolResult = $toolsRunner->call($fnCall['name'], (array) ($fnCall['args'] ?? []));
                $toolCalls[] = ['name' => $fnCall['name'], 'args' => $fnCall['args'] ?? []];

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
                $finalResponse = $this->providers->generate($messages, [], $options);
                $finalText = $finalResponse->text;
            }
        } catch (Throwable $e) {
            Log::error('[AI_ERROR]', [
                'message' => $e->getMessage(),
                'user_id' => $user->id,
                'conversation_id' => $conversation->id,
            ]);
            $finalText = $this->localFallbackMessage($user);
            $providerUsed = 'laravel_fallback';
            $usedLlm = false;
        }

        if ($finalText === null || $finalText === '') {
            $finalText = "Je n'ai pas pu formuler de réponse. Reformule ta question ?";
        }

        AiMessage::create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'role' => 'assistant',
            'content' => $finalText,
            'meta' => [
                'tool_calls' => $toolCalls,
                'provider' => $providerUsed,
                'intent' => $intent['intent'],
                'used_llm' => $usedLlm,
            ],
        ]);
        $conversation->touch();

        return $this->responseFormatter->formatSuccess(
            $conversation,
            $finalText,
            $toolCalls,
            $usedLlm,
            $intent['intent'],
            $providerUsed,
        );
    }

    protected function resolveConversation(User $user, string $message, ?int $conversationId): AiConversation
    {
        $conversation = $conversationId
            ? AiConversation::where('user_id', $user->id)->find($conversationId)
            : null;

        if (!$conversation) {
            $conversation = AiConversation::create([
                'user_id' => $user->id,
                'title' => mb_substr($message, 0, 60),
            ]);
        }

        return $conversation;
    }

    protected function reformulateDirect(User $user, string $userMessage, string $facts): string
    {
        try {
            $response = $this->providers->generate(
                messages: [[
                    'role' => 'user',
                    'content' => "Reformule en 2 à 4 phrases, tutoiement, français, ton FinanceWise. N'ajoute AUCUN chiffre ou fait qui n'est pas déjà dans les faits vérifiés ci-dessous.\n\nQuestion : {$userMessage}\n\nFaits vérifiés côté serveur :\n{$facts}",
                ]],
                tools: [],
                options: [
                    'system' => 'Tu es FinanceWise AI. Tu ne complètes pas les données.',
                    'temperature' => 0.2,
                    'max_tokens' => 220,
                ],
            );
            $text = trim((string) ($response->text ?? ''));

            return $text !== '' ? $text : $facts;
        } catch (Throwable) {
            return $facts;
        }
    }

    protected function localFallbackMessage(User $user): string
    {
        try {
            $m = (new AiTools($user))->getMonthlySummary(null);
            $exp = number_format((float) ($m['expense_fcfa'] ?? 0), 0, ',', ' ');

            return "Je n'arrive pas à joindre le service IA pour l'instant. Voici toutefois une donnée calculée localement sur tes enregistrements : en {$m['month']}, tes dépenses totalisent {$exp} FCFA. Réessaie l'assistant dans quelques instants pour une analyse plus complète.";
        } catch (Throwable) {
            return "Désolé, l'assistant n'est pas joignable pour le moment. Réessaie dans un instant.";
        }
    }
}
