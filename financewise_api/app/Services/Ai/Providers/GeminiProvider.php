<?php

namespace App\Services\Ai\Providers;

use App\Services\Ai\Contracts\AiProvider;
use App\Services\Ai\Contracts\AiResponse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Provider Google Gemini via REST API.
 * Doc : https://ai.google.dev/api/generate-content
 */
class GeminiProvider implements AiProvider
{
    public function __construct(
        protected ?string $apiKey = null,
        protected ?string $model = null,
        protected ?string $baseUrl = null,
        protected int $timeout = 25,
    ) {
        $this->apiKey  ??= (string) config('services.gemini.key');
        $this->model   ??= (string) config('services.gemini.model', 'gemini-2.0-flash');
        $this->baseUrl ??= rtrim((string) config('services.gemini.base_url', 'https://generativelanguage.googleapis.com/v1beta'), '/');
        $this->timeout = (int) (config('services.gemini.timeout') ?? $timeout);
    }

    public function name(): string { return 'gemini:' . $this->model; }
    public function isConfigured(): bool { return !empty($this->apiKey); }

    public function generate(array $messages, array $tools = [], array $options = []): AiResponse
    {
        if (!$this->isConfigured()) {
            throw new RuntimeException('GEMINI_API_KEY manquante.');
        }

        $payload = [
            'contents' => $this->convertMessages($messages),
            'generationConfig' => array_filter([
                'temperature' => $options['temperature'] ?? null,
                'maxOutputTokens' => $options['max_tokens'] ?? null,
                'responseMimeType' => ($options['json_mode'] ?? false) ? 'application/json' : null,
            ], fn ($v) => $v !== null),
        ];

        if (!empty($options['system'])) {
            $payload['systemInstruction'] = ['parts' => [['text' => $options['system']]]];
        }

        if (!empty($tools)) {
            $payload['tools'] = [['functionDeclarations' => $tools]];
        }

        $url = "{$this->baseUrl}/models/{$this->model}:generateContent";
        $response = Http::timeout($this->timeout)
            ->retry(2, 500, throw: false)
            ->withQueryParameters(['key' => $this->apiKey])
            ->acceptJson()
            ->asJson()
            ->post($url, $payload);

        if (!$response->successful()) {
            Log::warning('Gemini error', ['status' => $response->status(), 'body' => substr($response->body(), 0, 500)]);
            throw new RuntimeException("Erreur Gemini ({$response->status()}): " . $response->body());
        }

        $json = $response->json() ?? [];
        return new AiResponse(
            text: $this->extractText($json),
            functionCall: $this->extractFunctionCall($json),
            raw: $json,
        );
    }

    protected function convertMessages(array $messages): array
    {
        $contents = [];
        foreach ($messages as $m) {
            $role = $m['role'] ?? 'user';
            // Gemini ne connaît que 'user' et 'model'
            $geminiRole = match ($role) {
                'assistant' => 'model',
                'tool' => 'user', // function response → user role chez Gemini
                'system' => 'user', // system géré séparément via systemInstruction
                default => 'user',
            };

            if ($role === 'tool') {
                $contents[] = [
                    'role' => 'user',
                    'parts' => [[
                        'functionResponse' => [
                            'name' => $m['name'] ?? '',
                            'response' => ['result' => $m['content'] ?? []],
                        ],
                    ]],
                ];
                continue;
            }

            if ($role === 'assistant' && isset($m['function_call'])) {
                $contents[] = [
                    'role' => 'model',
                    'parts' => [[
                        'functionCall' => [
                            'name' => $m['function_call']['name'] ?? '',
                            'args' => (object) ($m['function_call']['args'] ?? []),
                        ],
                    ]],
                ];
                continue;
            }

            $text = is_string($m['content'] ?? '') ? $m['content'] : json_encode($m['content']);
            $contents[] = [
                'role' => $geminiRole,
                'parts' => [['text' => $text]],
            ];
        }
        return $contents;
    }

    protected function extractText(array $response): ?string
    {
        $parts = $response['candidates'][0]['content']['parts'] ?? [];
        $text = '';
        foreach ($parts as $p) {
            if (isset($p['text'])) $text .= $p['text'];
        }
        return $text === '' ? null : trim($text);
    }

    protected function extractFunctionCall(array $response): ?array
    {
        $parts = $response['candidates'][0]['content']['parts'] ?? [];
        foreach ($parts as $p) {
            if (isset($p['functionCall'])) {
                return [
                    'name' => $p['functionCall']['name'] ?? '',
                    'args' => (array) ($p['functionCall']['args'] ?? []),
                ];
            }
        }
        return null;
    }
}
