<?php

namespace App\Providers;

use App\Services\Ai\Contracts\AiProvider;
use App\Services\Ai\Providers\FailoverAiProvider;
use App\Services\Ai\Providers\GeminiProvider;
use App\Services\Ai\Providers\GroqProvider;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AiServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(AiProvider::class, function () {
            $configured = (string) config('services.ai.provider', 'groq');

            // 'auto' = tous les providers disponibles, dans l'ordre groq > gemini
            // 'groq,gemini' = liste explicite (premier = primaire, suivants = fallback)
            // 'groq' = un seul provider, pas de failover
            $names = $configured === 'auto'
                ? ['groq', 'gemini']
                : array_map('trim', explode(',', $configured));

            $providers = [];
            foreach ($names as $name) {
                $provider = $this->build($name);
                // Ne conserver que les providers configurés (avec clé API)
                if ($provider->isConfigured()) {
                    $providers[] = $provider;
                }
            }

            if (empty($providers)) {
                throw new RuntimeException('Aucun provider IA configuré. Ajoutez au moins une clé API (GROQ_API_KEY ou GEMINI_API_KEY).');
            }

            return count($providers) === 1 ? $providers[0] : new FailoverAiProvider($providers);
        });
    }

    protected function build(string $name): AiProvider
    {
        return match ($name) {
            'groq'   => new GroqProvider(),
            'gemini' => new GeminiProvider(),
            default  => throw new RuntimeException("Provider IA inconnu: {$name}. Utilisez 'groq', 'gemini', 'auto' ou une liste 'groq,gemini'."),
        };
    }
}
