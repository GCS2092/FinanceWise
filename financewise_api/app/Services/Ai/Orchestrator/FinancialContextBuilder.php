<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\User;
use App\Services\Ai\AiTools;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Contexte financier compact (données réelles) injecté dans le system prompt.
 * Réduit les allers-retours outils pour les questions générales tout en restant court.
 */
class FinancialContextBuilder
{
    public function build(User $user): string
    {
        $ttl = (int) config('ai.orchestrator.financial_context_ttl_seconds', 90);
        $key = 'ai_financial_context:' . $user->id;

        $payload = Cache::remember($key, $ttl, function () use ($user) {
            $tools = new AiTools($user);
            $month = $tools->getMonthlySummary(null);
            $budgets = $tools->getBudgetStatus();
            $goals = $tools->getGoalProgress();
            $wallets = $tools->getWallets();
            $top = $tools->getTopExpenses(3, null);

            $compact = [
                'month' => $month['month'] ?? null,
                'income_fcfa' => $month['income_fcfa'] ?? null,
                'expense_fcfa' => $month['expense_fcfa'] ?? null,
                'net_fcfa' => $month['net_fcfa'] ?? null,
                'transactions_count' => $month['transactions_count'] ?? null,
                'current_balance_fcfa' => $month['current_balance_fcfa'] ?? null,
                'top_categories' => array_slice($this->toArray($month['top_categories'] ?? []), 0, 5),
                'budgets_count' => count($budgets['budgets'] ?? []),
                'budgets_preview' => array_slice($this->toArray($budgets['budgets'] ?? []), 0, 4),
                'goals_preview' => array_slice($this->toArray($goals['goals'] ?? []), 0, 3),
                'wallets_total_fcfa' => $wallets['total_balance_fcfa'] ?? null,
                'top_expenses' => $top['expenses'] ?? [],
            ];

            return json_encode($compact, JSON_UNESCAPED_UNICODE);
        });

        Log::info('[AI_CONTEXT]', ['type' => 'financial_snapshot', 'user_id' => $user->id]);

        return <<<TXT
Contexte financier (données réelles agrégées côté serveur, ne pas inventer d’autres chiffres) :
{$payload}
TXT;
    }

    public function forget(User $user): void
    {
        Cache::forget('ai_financial_context:' . $user->id);
    }

    /**
     * Convertit une Collection ou un array en array PHP natif.
     */
    protected function toArray($value): array
    {
        if ($value instanceof \Illuminate\Support\Collection) {
            return $value->toArray();
        }
        return is_array($value) ? $value : [];
    }
}
