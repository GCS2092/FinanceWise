<?php

namespace App\Services\Ai;

use App\Models\AiCategoryCorrection;
use App\Models\Category;
use App\Models\User;
use App\Services\Ai\Contracts\AiProvider;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Catégorisation IA d'une description / SMS de transaction.
 * Combine : exemples appris (mémoire) + LLM + heuristique.
 */
class AiCategorizationService
{
    public function __construct(protected AiProvider $provider)
    {
    }

    /**
     * @return array{category_id: ?int, category_name: ?string, confidence: float, source: string}
     */
    public function categorize(User $user, string $description, ?string $type = null): array
    {
        $description = trim($description);
        if ($description === '') {
            return ['category_id' => null, 'category_name' => null, 'confidence' => 0, 'source' => 'empty'];
        }

        // 1. Match via mémoire
        $exact = $this->matchPastCorrection($user, $description);
        if ($exact) {
            return ['category_id' => $exact->id, 'category_name' => $exact->name, 'confidence' => 1.0, 'source' => 'memory'];
        }

        // 2. LLM
        if (config('services.ai.enabled', true) && $this->provider->isConfigured()) {
            try {
                $result = $this->classifyWithLlm($user, $description, $type);
                if ($result) return $result;
            } catch (Throwable $e) {
                Log::warning('AI categorization failed, fallback heuristic', [
                    'provider' => $this->provider->name(),
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // 3. Heuristique
        return $this->heuristic($user, $description);
    }

    public function learnFromCorrection(User $user, string $description, int $categoryId): void
    {
        AiCategoryCorrection::create([
            'user_id' => $user->id,
            'description' => mb_substr(trim($description), 0, 500),
            'category_id' => $categoryId,
        ]);
        Cache::forget("ai_categories:{$user->id}");
    }

    protected function matchPastCorrection(User $user, string $description): ?Category
    {
        $needle = mb_strtolower($description);
        $corrections = AiCategoryCorrection::where('user_id', $user->id)
            ->latest('id')
            ->limit(50)
            ->with('category:id,name')
            ->get();

        foreach ($corrections as $c) {
            $hay = mb_strtolower($c->description);
            if ($hay !== '' && (str_contains($needle, $hay) || str_contains($hay, $needle))) {
                return $c->category;
            }
        }
        return null;
    }

    protected function classifyWithLlm(User $user, string $description, ?string $type): ?array
    {
        $cats = $this->userCategories($user, $type);
        if ($cats->isEmpty()) return null;

        $names = $cats->pluck('name')->implode(', ');

        $examples = AiCategoryCorrection::where('user_id', $user->id)
            ->latest('id')
            ->limit(8)
            ->with('category:id,name')
            ->get()
            ->map(fn ($c) => "- \"{$c->description}\" → {$c->category?->name}")
            ->implode("\n");

        $prompt = <<<TXT
Classifie cette transaction dans UNE catégorie parmi cette liste exacte (réponds UNIQUEMENT le nom, identique à la liste, sans guillemets ni texte additionnel) :

CATÉGORIES : {$names}

EXEMPLES APPRIS DE L'UTILISATEUR :
{$examples}

TRANSACTION À CLASSER : "{$description}"

Si aucune ne correspond clairement, réponds "Autre".
TXT;

        $response = $this->provider->generate(
            messages: [['role' => 'user', 'content' => $prompt]],
            tools: [],
            options: ['temperature' => 0.1, 'max_tokens' => 30],
        );

        $text = trim((string) ($response->text ?? ''), " \t\n\r\0\x0B\"'");
        if ($text === '') return null;

        $needle = mb_strtolower($text);
        $match = $cats->first(fn ($c) => mb_strtolower($c->name) === $needle);
        if (!$match) {
            $match = $cats->first(fn ($c) => str_contains($needle, mb_strtolower($c->name)) || str_contains(mb_strtolower($c->name), $needle));
        }
        if (!$match) return null;

        return [
            'category_id' => $match->id,
            'category_name' => $match->name,
            'confidence' => 0.85,
            'source' => 'llm',
        ];
    }

    protected function heuristic(User $user, string $description): array
    {
        $cats = $this->userCategories($user);
        $desc = mb_strtolower($description);

        $rules = [
            'Transport' => ['taxi', 'yango', 'bolt', 'uber', 'bus', 'clando', 'car rapide', 'transport'],
            'Nourriture' => ['restaurant', 'resto', 'café', 'food', 'manger', 'repas'],
            'Internet / Data' => ['internet', 'data', 'pass', 'forfait', 'mb', 'go'],
            'Électricité' => ['senelec', 'sénélec', 'électricité'],
            'Eau' => ['sde', 'eau'],
            'Santé' => ['pharmacie', 'hôpital', 'clinique', 'médecin'],
            'Mobile Money' => ['wave', 'orange money', 'free money', 'wari', 'transfert'],
        ];

        foreach ($rules as $catName => $keywords) {
            foreach ($keywords as $kw) {
                if (str_contains($desc, $kw)) {
                    $match = $cats->first(fn ($c) => mb_strtolower($c->name) === mb_strtolower($catName));
                    if ($match) {
                        return [
                            'category_id' => $match->id,
                            'category_name' => $match->name,
                            'confidence' => 0.5,
                            'source' => 'heuristic',
                        ];
                    }
                }
            }
        }

        $autre = $cats->first(fn ($c) => mb_strtolower($c->name) === 'autre');
        return [
            'category_id' => $autre?->id,
            'category_name' => $autre?->name,
            'confidence' => 0.2,
            'source' => 'fallback',
        ];
    }

    protected function userCategories(User $user, ?string $type = null)
    {
        return Cache::remember("ai_categories:{$user->id}:" . ($type ?? 'all'), 300, function () use ($user, $type) {
            $q = Category::where(function ($q) use ($user) {
                $q->where('is_system', true)->orWhere('user_id', $user->id);
            });
            if ($type === 'expense' || $type === 'income') {
                $q->where(function ($qq) use ($type) {
                    $qq->where('type', $type)->orWhereNull('type');
                });
            }
            return $q->get(['id', 'name', 'type']);
        });
    }
}
