<?php

namespace App\Services\Ai;

use App\Models\AiInsight;
use App\Models\User;
use App\Services\Ai\Contracts\AiProvider;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Brief mensuel : agrégats côté serveur → résumé narratif par le LLM.
 * Caché via la table ai_insights (1 brief par user/type/period).
 */
class AiInsightsService
{
    public function __construct(protected AiProvider $provider)
    {
    }

    public function getOrGenerateMonthlyBrief(User $user, ?string $period = null): AiInsight
    {
        $period ??= now()->subMonth()->format('Y-m');

        $existing = AiInsight::where('user_id', $user->id)
            ->where('type', 'monthly_brief')
            ->where('period', $period)
            ->first();

        if ($existing) return $existing;

        return $this->generateMonthlyBrief($user, $period);
    }

    public function generateMonthlyBrief(User $user, string $period): AiInsight
    {
        $tools = new AiTools($user);
        $current = $tools->getMonthlySummary($period);

        $previousPeriod = Carbon::createFromFormat('Y-m', $period)->subMonth()->format('Y-m');
        $previous = $tools->getMonthlySummary($previousPeriod);

        $budgets = $tools->getBudgetStatus();
        $goals = $tools->getGoalProgress();

        $aggregates = compact('current', 'previous', 'budgets', 'goals');

        $summary = "Voici un résumé pour {$period}.";
        $highlights = $this->buildHighlights($current, $previous);
        $suggestions = [];

        if (config('services.ai.enabled', true) && $this->provider->isConfigured()) {
            try {
                $response = $this->provider->generate(
                    messages: [[
                        'role' => 'user',
                        'content' => "Données agrégées :\n" . json_encode($aggregates, JSON_UNESCAPED_UNICODE),
                    ]],
                    tools: [],
                    options: [
                        'system' => $this->systemPrompt($user, $period),
                        'temperature' => 0.3,
                        'max_tokens' => 800,
                        'json_mode' => true,
                    ],
                );

                $raw = $response->text ?? '';
                $decoded = json_decode($raw, true);

                if (is_array($decoded)) {
                    $summary = (string) ($decoded['summary'] ?? $summary);
                    $highlights = $decoded['highlights'] ?? $highlights;
                    $suggestions = $decoded['suggestions'] ?? [];
                }
            } catch (Throwable $e) {
                Log::warning('AiInsights generation failed, fallback to heuristic', [
                    'provider' => $this->provider->name(),
                    'error' => $e->getMessage(),
                    'user' => $user->id,
                ]);
            }
        }

        return AiInsight::updateOrCreate(
            ['user_id' => $user->id, 'type' => 'monthly_brief', 'period' => $period],
            [
                'summary' => $summary,
                'highlights' => $highlights,
                'suggestions' => $suggestions,
                'is_read' => false,
            ]
        );
    }

    protected function buildHighlights(array $current, array $previous): array
    {
        $h = [];
        $h[] = "Dépenses : " . number_format($current['expense_fcfa'], 0, ',', ' ') . " FCFA";
        $h[] = "Revenus : " . number_format($current['income_fcfa'], 0, ',', ' ') . " FCFA";
        $h[] = "Solde net : " . number_format($current['net_fcfa'], 0, ',', ' ') . " FCFA";

        if (($previous['expense_fcfa'] ?? 0) > 0) {
            $diff = $current['expense_fcfa'] - $previous['expense_fcfa'];
            $pct = ($diff / $previous['expense_fcfa']) * 100;
            $sign = $diff >= 0 ? '+' : '';
            $h[] = "vs mois précédent : {$sign}" . number_format($pct, 0) . "% en dépenses";
        }
        return $h;
    }

    protected function systemPrompt(User $user, string $period): string
    {
        $name = $user->name ?: 'utilisateur';
        return <<<PROMPT
Tu es FinanceWise, assistant financier personnel pour {$name} (Sénégal).
On te fournit les données agrégées du mois {$period} et du mois précédent.
Génère un brief mensuel utile et chaleureux, en français, tutoiement.

Sortie : JSON strict avec ce schéma :
{
  "summary": string,        // 2-4 phrases, narratif, ton direct
  "highlights": string[],   // 3-5 points factuels courts (montants en FCFA, format "12 500 FCFA")
  "suggestions": string[]   // 2-3 conseils concrets, actionnables, basés UNIQUEMENT sur les chiffres fournis
}

Règles :
- Tous les montants en FCFA, format "12 500 FCFA".
- N'invente AUCUN chiffre absent des données.
- Si revenus/dépenses sont à 0, dis-le et invite à enregistrer ses transactions.
- Pas de blabla, pas de jargon, pas d'introduction.
- Réponds UNIQUEMENT le JSON, sans markdown ni texte autour.
PROMPT;
    }
}
