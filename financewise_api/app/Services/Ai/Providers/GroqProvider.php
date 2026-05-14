<?php

namespace App\Services\Ai\Providers;

use App\Services\Ai\Contracts\AiProvider;
use App\Services\Ai\Contracts\AiResponse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Provider Groq via API compatible OpenAI.
 * Doc : https://console.groq.com/docs/api-reference
 *
 * Modèles recommandés (gratuits) :
 * - llama-3.3-70b-versatile (qualité max, 30 req/min)
 * - llama-3.1-8b-instant    (ultra rapide, 30 req/min)
 * - mixtral-8x7b-32768      (long contexte)
 */
class GroqProvider implements AiProvider
{
    public function __construct(
        protected ?string $apiKey = null,
        protected ?string $model = null,
        protected ?string $baseUrl = null,
        protected int $timeout = 25,
    ) {
        $this->apiKey  ??= (string) config('services.groq.key');
        $this->model   ??= (string) config('services.groq.model', 'llama-3.3-70b-versatile');
        $this->baseUrl ??= rtrim((string) config('services.groq.base_url', 'https://api.groq.com/openai/v1'), '/');
        $this->timeout = (int) (config('services.groq.timeout') ?? $timeout);
    }

    public function name(): string { return 'groq:' . $this->model; }
    public function isConfigured(): bool { return !empty($this->apiKey); }

    public function generate(array $messages, array $tools = [], array $options = []): AiResponse
    {
        if (!$this->isConfigured()) {
            throw new RuntimeException('GROQ_API_KEY manquante.');
        }

        $payload = [
            'model' => $this->model,
            'messages' => $this->convertMessages($messages, $options['system'] ?? null),
            'temperature' => $options['temperature'] ?? 0.25,
            'max_tokens' => $options['max_tokens'] ?? 1024,
        ];

        if (!empty($options['json_mode'])) {
            $payload['response_format'] = ['type' => 'json_object'];
        }

        if (!empty($tools)) {
            $payload['tools'] = array_map(fn ($t) => [
                'type' => 'function',
                'function' => [
                    'name' => $t['name'],
                    'description' => $t['description'] ?? '',
                    'parameters' => $t['parameters'] ?? ['type' => 'object', 'properties' => (object) []],
                ],
            ], $tools);
            $payload['tool_choice'] = 'auto';
        }

        $response = Http::timeout($this->timeout)
            ->retry(2, 500, throw: false)
            ->withToken($this->apiKey)
            ->acceptJson()
            ->asJson()
            ->post("{$this->baseUrl}/chat/completions", $payload);

        if (!$response->successful()) {
            Log::warning('Groq error', ['status' => $response->status(), 'body' => substr($response->body(), 0, 500)]);
            throw new RuntimeException("Erreur Groq ({$response->status()}): " . $response->body());
        }

        $json = $response->json() ?? [];
        $message = $json['choices'][0]['message'] ?? [];

        $functionCall = null;
        if (!empty($message['tool_calls'][0]['function'])) {
            $fn = $message['tool_calls'][0]['function'];
            $args = is_string($fn['arguments'] ?? '')
                ? (json_decode($fn['arguments'], true) ?: [])
                : ($fn['arguments'] ?? []);
            $functionCall = [
                'name' => $fn['name'] ?? '',
                'args' => $args,
                'id' => $message['tool_calls'][0]['id'] ?? null,
            ];
        }

        $text = isset($message['content']) && is_string($message['content']) && $message['content'] !== ''
            ? trim($message['content'])
            : null;

        return new AiResponse(text: $text, functionCall: $functionCall, raw: $json);
    }

    protected function convertMessages(array $messages, ?string $system): array
    {
        $out = [];
        if ($system) {
            $out[] = ['role' => 'system', 'content' => $system];
        }

        foreach ($messages as $m) {
            $role = $m['role'] ?? 'user';

            if ($role === 'tool') {
                $content = is_string($m['content'] ?? '')
                    ? $m['content']
                    : json_encode($m['content']);
                $out[] = [
                    'role' => 'tool',
                    'tool_call_id' => $m['tool_call_id'] ?? ($m['name'] ?? 'call_1'),
                    'name' => $m['name'] ?? 'tool',
                    'content' => $content,
                ];
                continue;
            }

            if ($role === 'assistant' && isset($m['function_call'])) {
                $out[] = [
                    'role' => 'assistant',
                    'content' => null,
                    'tool_calls' => [[
                        'id' => $m['function_call']['id'] ?? 'call_1',
                        'type' => 'function',
                        'function' => [
                            'name' => $m['function_call']['name'] ?? '',
                            'arguments' => json_encode($m['function_call']['args'] ?? new \stdClass()),
                        ],
                    ]],
                ];
                continue;
            }

            $out[] = [
                'role' => $role === 'system' ? 'system' : ($role === 'assistant' ? 'assistant' : 'user'),
                'content' => is_string($m['content'] ?? '') ? $m['content'] : json_encode($m['content']),
            ];
        }
        return $out;
    }
}
