<?php

namespace App\Services\Ai\Contracts;

/**
 * Réponse normalisée d'un provider IA.
 */
class AiResponse
{
    public function __construct(
        public readonly ?string $text = null,
        public readonly ?array $functionCall = null, // ['name' => string, 'args' => array, 'id' => ?string]
        public readonly array $raw = [],
    ) {
    }

    public function hasFunctionCall(): bool
    {
        return $this->functionCall !== null && !empty($this->functionCall['name']);
    }

    public function isEmpty(): bool
    {
        return ($this->text === null || $this->text === '') && !$this->hasFunctionCall();
    }
}
