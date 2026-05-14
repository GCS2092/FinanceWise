<?php

namespace App\Services\Ai\Providers;

use App\Services\Ai\Contracts\AiProvider;
use App\Services\Ai\Contracts\AiResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

/**
 * Provider composite qui essaie plusieurs providers dans l'ordre.
 * Si le premier échoue (timeout, rate-limit, erreur HTTP), on bascule sur le suivant.
 *
 * Un provider en échec est mis en quarantaine pendant 60 s pour éviter de retenter
 * en boucle un service indisponible.
 */
class FailoverAiProvider implements AiProvider
{
    /**
     * @param AiProvider[] $providers Liste ordonnée par préférence
     */
    public function __construct(
        protected array $providers,
        protected int $cooldownSeconds = 30,
    ) {
        if (empty($this->providers)) {
            throw new RuntimeException('FailoverAiProvider nécessite au moins un provider.');
        }
    }

    public function name(): string
    {
        return 'failover[' . implode('|', array_map(fn ($p) => $p->name(), $this->providers)) . ']';
    }

    public function isConfigured(): bool
    {
        foreach ($this->providers as $p) {
            if ($p->isConfigured()) return true;
        }
        return false;
    }

    public function generate(array $messages, array $tools = [], array $options = []): AiResponse
    {
        $errors = [];

        foreach ($this->providers as $provider) {
            if (!$provider->isConfigured()) {
                $errors[] = $provider->name() . ': non configuré';
                continue;
            }

            // Quarantaine réactivée avec cooldown de 30s pour éviter boucles d'échec
            $cooldownKey = 'ai_failover_cooldown:' . $provider->name();
            if (Cache::has($cooldownKey)) {
                $errors[] = $provider->name() . ': en quarantaine';
                continue;
            }

            try {
                $response = $provider->generate($messages, $tools, $options);
                if (!$response->isEmpty()) {
                    return $response;
                }
                $errors[] = $provider->name() . ': réponse vide';
            } catch (Throwable $e) {
                $errors[] = $provider->name() . ': ' . $this->shortError($e->getMessage());
                Log::warning('[AI_FALLBACK]', [
                    'failed_provider' => $provider->name(),
                    'error' => $e->getMessage(),
                    'message' => 'Bascule ou fin de chaîne failover',
                ]);
                // Quarantaine réactivée avec cooldown de 30s pour éviter boucles d'échec
                if ($this->shouldQuarantine($e->getMessage())) {
                    Cache::put($cooldownKey, true, $this->cooldownSeconds);
                }
            }
        }

        throw new RuntimeException('Tous les providers IA ont échoué : ' . implode(' | ', $errors));
    }

    protected function shortError(string $message): string
    {
        $message = preg_replace('/\s+/', ' ', $message);
        return mb_substr($message, 0, 120);
    }

    protected function shouldQuarantine(string $message): bool
    {
        $patterns = ['429', 'quota', 'RESOURCE_EXHAUSTED', '500', '502', '503', '504', 'timeout', 'cURL'];
        foreach ($patterns as $p) {
            if (stripos($message, $p) !== false) return true;
        }
        return false;
    }
}
