<?php

namespace App\Services\Ai;

use App\Models\Budget;
use App\Models\FinancialGoal;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Carbon\Carbon;

/**
 * Outils que l'assistant IA peut appeler via function calling.
 * Toutes les fonctions sont scopées à l'utilisateur courant — l'IA ne voit
 * jamais les données brutes d'un autre utilisateur.
 */
class AiTools
{
    public function __construct(protected User $user)
    {
    }

    /**
     * Déclarations Gemini (functionDeclarations) à exposer au modèle.
     */
    public static function declarations(): array
    {
        return [
            [
                'name' => 'get_monthly_summary',
                'description' => "Retourne le résumé financier du mois : revenus, dépenses, solde, top catégories. À utiliser pour donner une vue d'ensemble ou répondre à 'comment ça va ce mois ?'.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'month' => [
                            'type' => 'string',
                            'description' => "Mois au format YYYY-MM. Si omis, le mois en cours est utilisé.",
                        ],
                    ],
                ],
            ],
            [
                'name' => 'get_transactions_by_category',
                'description' => "Retourne les dépenses/revenus pour une catégorie spécifique. À utiliser quand l'utilisateur demande une catégorie précise (ex: 'combien en transport ?').",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'category' => ['type' => 'string', 'description' => "Nom de la catégorie (ex: Transport, Nourriture)."],
                        'month' => ['type' => 'string', 'description' => "Mois YYYY-MM. Optionnel."],
                    ],
                    'required' => ['category'],
                ],
            ],
            [
                'name' => 'get_budget_status',
                'description' => "Liste les budgets actifs avec montant prévu, dépensé, restant et %. À utiliser quand l'utilisateur demande 'budget' ou 'combien il me reste'. Si aucun budget n'existe pour la catégorie demandée, utilise get_category_spending.",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
            [
                'name' => 'get_goal_progress',
                'description' => "Liste les objectifs d'épargne avec progression. À utiliser quand l'utilisateur demande 'objectifs', 'épargne' ou 'où j'en suis'.",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
            [
                'name' => 'get_top_expenses',
                'description' => "Retourne les plus grosses dépenses. À utiliser pour identifier les dépenses impactantes ou répondre 'où part mon argent ?'.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'limit' => ['type' => 'number', 'description' => "Nombre max de résultats (défaut 5)."],
                        'month' => ['type' => 'string', 'description' => "Mois YYYY-MM. Optionnel."],
                    ],
                ],
            ],
            [
                'name' => 'get_category_spending',
                'description' => "Retourne les dépenses par catégorie du mois en cours. À utiliser si get_budget_status ne montre pas de budget pour la catégorie demandée, ou pour donner une vue globale des catégories.",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
            [
                'name' => 'get_upcoming_expenses',
                'description' => "Retourne les dépenses récurrentes et échéances dans les 30 prochains jours. À utiliser pour les prévisions, alertes proactives (ex: 'attention, ton abonnement arrive dans 9 jours').",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
            [
                'name' => 'detect_anomalies',
                'description' => "Détecte les dépenses inhabituelles (montants anormalement élevés, catégories rares). À utiliser pour alerter sur des comportements atypiques (ex: 'tes dépenses courses sont inhabituellement élevées cette semaine').",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
            [
                'name' => 'simulate_savings',
                'description' => "Simule l'impact d'un changement d'épargne sur les objectifs. À utiliser pour proposer des scénarios (ex: 'si tu économises 4€/jour de plus, tu atteindras ton fonds d'urgence 3 mois plus tôt').",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'daily_saving_fcfa' => ['type' => 'number', 'description' => "Montant d'épargne quotidien supplémentaire en FCFA"],
                        'category_reduction_fcfa' => ['type' => 'number', 'description' => "Montant de réduction mensuelle d'une catégorie en FCFA"],
                    ],
                ],
            ],
            [
                'name' => 'get_wallets',
                'description' => "Liste les portefeuilles avec leur solde. À utiliser quand l'utilisateur demande 'solde', 'combien j'ai' ou similaire.",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
        ];
    }

    /**
     * Dispatch d'un appel par nom.
     */
    public function call(string $name, array $args): array
    {
        return match ($name) {
            'get_monthly_summary'        => $this->getMonthlySummary($args['month'] ?? null),
            'get_transactions_by_category' => $this->getTransactionsByCategory($args['category'] ?? '', $args['month'] ?? null),
            'get_budget_status'          => $this->getBudgetStatus(),
            'get_goal_progress'          => $this->getGoalProgress(),
            'get_top_expenses'           => $this->getTopExpenses((int) ($args['limit'] ?? 5), $args['month'] ?? null),
            'get_category_spending'      => $this->getCategorySpending(),
            'get_upcoming_expenses'      => $this->getUpcomingExpenses(),
            'detect_anomalies'           => $this->detectAnomalies(),
            'simulate_savings'           => $this->simulateSavings($args),
            'get_wallets'                => $this->getWallets(),
            default                      => ['error' => "Fonction inconnue: {$name}"],
        };
    }

    public function getMonthlySummary(?string $month = null): array
    {
        [$start, $end, $label] = $this->resolveMonth($month);

        $stats = $this->user->transactions()
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw("
                COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
                COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense,
                COUNT(*) as count
            ")->first();

        $balance = (float) $this->user->wallets()->sum('balance');

        $top = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw('category_id, SUM(amount) as total')
            ->with('category:id,name')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($r) => [
                'category' => $r->category?->name ?? 'Non catégorisé',
                'total_fcfa' => (float) $r->total,
            ]);

        return [
            'month' => $label,
            'income_fcfa'  => (float) $stats->income,
            'expense_fcfa' => (float) $stats->expense,
            'net_fcfa'     => (float) $stats->income - (float) $stats->expense,
            'transactions_count' => (int) $stats->count,
            'current_balance_fcfa' => $balance,
            'top_categories' => $top,
        ];
    }

    public function getTransactionsByCategory(string $category, ?string $month = null): array
    {
        if ($category === '') return ['error' => 'Catégorie requise'];
        [$start, $end, $label] = $this->resolveMonth($month);

        $rows = $this->user->transactions()
            ->whereHas('category', fn ($q) => $q->whereRaw('LOWER(name) = ?', [mb_strtolower($category)]))
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw("
                COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense,
                COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
                COUNT(*) as count
            ")->first();

        return [
            'category' => $category,
            'month' => $label,
            'expense_fcfa' => (float) $rows->expense,
            'income_fcfa'  => (float) $rows->income,
            'count' => (int) $rows->count,
        ];
    }

    public function getBudgetStatus(): array
    {
        $now = now();
        $budgets = Budget::where('user_id', $this->user->id)
            ->where('is_active', true)
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now)
            ->with('category:id,name')
            ->get();

        return [
            'budgets' => $budgets->map(fn ($b) => [
                'category' => $b->category?->name,
                'amount_fcfa' => (float) $b->amount,
                'spent_fcfa' => (float) $b->spent,
                'remaining_fcfa' => max(0, (float) $b->amount - (float) $b->spent),
                'percentage' => $b->amount > 0 ? round(($b->spent / $b->amount) * 100, 1) : 0,
                'period' => $b->period,
            ])->all(),
        ];
    }

    public function getGoalProgress(): array
    {
        $goals = FinancialGoal::where('user_id', $this->user->id)->get();
        return [
            'goals' => $goals->map(fn ($g) => [
                'name' => $g->name,
                'target_fcfa' => (float) ($g->target_amount ?? 0),
                'current_fcfa' => (float) ($g->current_amount ?? 0),
                'remaining_fcfa' => max(0, (float) ($g->target_amount ?? 0) - (float) ($g->current_amount ?? 0)),
                'percentage' => ($g->target_amount ?? 0) > 0
                    ? round(($g->current_amount / $g->target_amount) * 100, 1)
                    : 0,
                'deadline' => optional($g->target_date)->toDateString(),
            ])->all(),
        ];
    }

    public function getTopExpenses(int $limit = 5, ?string $month = null): array
    {
        $limit = max(1, min(20, $limit));
        [$start, $end, $label] = $this->resolveMonth($month);

        $rows = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->orderByDesc('amount')
            ->limit($limit)
            ->with('category:id,name')
            ->get();

        return [
            'month' => $label,
            'expenses' => $rows->map(fn ($t) => [
                'description' => $t->description,
                'amount_fcfa' => (float) $t->amount,
                'category' => $t->category?->name,
                'date' => optional($t->transaction_date)->toDateString(),
            ])->all(),
        ];
    }

    public function getWallets(): array
    {
        return [
            'wallets' => Wallet::where('user_id', $this->user->id)->get()
                ->map(fn ($w) => [
                    'name' => $w->name,
                    'type' => $w->type,
                    'balance_fcfa' => (float) $w->balance,
                ])->all(),
            'total_balance_fcfa' => (float) Wallet::where('user_id', $this->user->id)->sum('balance'),
        ];
    }

    public function getCategorySpending(): array
    {
        [$start, $end, $label] = $this->resolveMonth(null);

        $categories = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw('category_id, SUM(amount) as total, COUNT(*) as count')
            ->with('category:id,name')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->get();

        return [
            'month' => $label,
            'categories' => $categories->map(fn ($c) => [
                'category' => $c->category?->name ?? 'Non catégorisé',
                'total_fcfa' => (float) $c->total,
                'count' => (int) $c->count,
            ])->all(),
        ];
    }

    public function getUpcomingExpenses(): array
    {
        $now = now();
        $in30Days = now()->addDays(30);

        // Récupérer les dépenses récurrentes du mois dernier comme estimation
        $lastMonthStart = now()->subMonth()->startOfMonth();
        $lastMonthEnd = now()->subMonth()->endOfMonth();

        $recurring = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$lastMonthStart, $lastMonthEnd])
            ->selectRaw('description, category_id, amount, COUNT(*) as occurrences')
            ->with('category:id,name')
            ->groupBy('description', 'category_id', 'amount')
            ->having('occurrences', '>=', 2) // Au moins 2 fois le mois dernier = potentiellement récurrent
            ->orderByDesc('amount')
            ->limit(10)
            ->get();

        // Récupérer les payment reminders (si existants)
        $reminders = \App\Models\PaymentReminder::where('user_id', $this->user->id)
            ->where('next_due_date', '<=', $in30Days)
            ->where('is_completed', false)
            ->orderBy('next_due_date')
            ->get();

        return [
            'next_30_days' => [
                'recurring_estimates' => $recurring->map(fn ($r) => [
                    'description' => $r->description,
                    'category' => $r->category?->name ?? 'Non catégorisé',
                    'amount_fcfa' => (float) $r->amount,
                    'occurrences_last_month' => (int) $r->occurrences,
                ])->all(),
                'payment_reminders' => $reminders->map(fn ($r) => [
                    'description' => $r->description,
                    'amount_fcfa' => (float) $r->amount,
                    'due_date' => optional($r->next_due_date)->toDateString(),
                ])->all(),
            ],
        ];
    }

    public function detectAnomalies(): array
    {
        [$start, $end, $label] = $this->resolveMonth(null);

        // Dépenses du mois en cours
        $currentMonth = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->with('category:id,name')
            ->orderByDesc('amount')
            ->get();

        // Calculer la moyenne par catégorie sur les 3 derniers mois
        $avgByCategory = $this->user->transactions()
            ->where('type', 'expense')
            ->where('transaction_date', '>=', now()->subMonths(3)->startOfMonth())
            ->selectRaw('category_id, AVG(amount) as avg_amount, COUNT(*) as count')
            ->with('category:id,name')
            ->groupBy('category_id')
            ->get()
            ->keyBy('category_id');

        $anomalies = [];
        foreach ($currentMonth as $t) {
            $catId = $t->category_id;
            $avg = $avgByCategory[$catId] ?? null;

            // Anomalie si le montant est > 2x la moyenne habituelle pour cette catégorie
            if ($avg && $t->amount > ($avg->avg_amount * 2) && $avg->count >= 3) {
                $anomalies[] = [
                    'description' => $t->description,
                    'category' => $t->category?->name ?? 'Non catégorisé',
                    'amount_fcfa' => (float) $t->amount,
                    'usual_average_fcfa' => (float) $avg->avg_amount,
                    'date' => optional($t->transaction_date)->toDateString(),
                    'reason' => 'Montant anormalement élevé pour cette catégorie',
                ];
            }
        }

        // Dépenses dans des catégories rarement utilisées
        $rareCategories = $currentMonth->groupBy('category_id')->filter(fn ($group) => $group->count() == 1);
        foreach ($rareCategories as $catId => $transactions) {
            $catName = $transactions->first()->category?->name ?? 'Non catégorisé';
            $total = $transactions->sum('amount');
            if ($total > 10000) { // Seuil de 10 000 FCFA
                $anomalies[] = [
                    'description' => $transactions->first()->description,
                    'category' => $catName,
                    'amount_fcfa' => (float) $total,
                    'reason' => 'Catégorie rarement utilisée ce mois',
                    'date' => optional($transactions->first()->transaction_date)->toDateString(),
                ];
            }
        }

        return [
            'month' => $label,
            'anomalies' => array_slice($anomalies, 0, 5), // Max 5 anomalies
        ];
    }

    public function simulateSavings(array $args): array
    {
        $dailySaving = (float) ($args['daily_saving_fcfa'] ?? 0);
        $categoryReduction = (float) ($args['category_reduction_fcfa'] ?? 0);

        // Calculer l'épargne mensuelle supplémentaire
        $monthlyExtraSaving = ($dailySaving * 30) + $categoryReduction;

        if ($monthlyExtraSaving <= 0) {
            return [
                'error' => 'Aucun changement à simuler',
                'monthly_extra_saving_fcfa' => 0,
            ];
        }

        // Récupérer les objectifs de l'utilisateur
        $goals = FinancialGoal::where('user_id', $this->user->id)
            ->where('target_amount', '>', 0)
            ->where('current_amount', '<', \DB::raw('target_amount'))
            ->get();

        $impact = [];
        foreach ($goals as $goal) {
            $remaining = (float) ($goal->target_amount - ($goal->current_amount ?? 0));
            if ($remaining <= 0) continue;

            $currentMonths = $remaining / max(1, $monthlyExtraSaving);
            $newMonths = $remaining / max(1, $monthlyExtraSaving + $monthlyExtraSaving * 0.1); // Estimation actuelle

            $impact[] = [
                'goal_name' => $goal->name,
                'remaining_fcfa' => $remaining,
                'months_to_complete_with_extra_saving' => round($currentMonths, 1),
                'deadline' => optional($goal->target_date)->toDateString(),
            ];
        }

        return [
            'monthly_extra_saving_fcfa' => $monthlyExtraSaving,
            'yearly_extra_saving_fcfa' => $monthlyExtraSaving * 12,
            'impact_on_goals' => $impact,
        ];
    }

    protected function resolveMonth(?string $month): array
    {
        try {
            $ref = $month ? Carbon::createFromFormat('Y-m', $month)->startOfMonth() : now()->startOfMonth();
        } catch (\Throwable) {
            $ref = now()->startOfMonth();
        }
        return [
            $ref->copy()->startOfMonth(),
            $ref->copy()->endOfMonth(),
            $ref->format('Y-m'),
        ];
    }
}
