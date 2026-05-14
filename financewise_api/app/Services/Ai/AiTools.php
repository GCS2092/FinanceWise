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
            [
                'name' => 'get_transactions_sorted',
                'description' => "Retourne les transactions triées par montant ou date. À utiliser quand l'utilisateur demande 'trier', 'ordre', 'croissant', 'décroissant' ou veut voir les transactions dans un ordre spécifique.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'sort_by' => ['type' => 'string', 'description' => "Critère de tri : 'amount' (montant) ou 'date' (date). Défaut 'amount'."],
                        'order' => ['type' => 'string', 'description' => "Ordre : 'asc' (croissant) ou 'desc' (décroissant). Défaut 'desc'."],
                        'limit' => ['type' => 'number', 'description' => "Nombre max de résultats (défaut 10)."],
                        'month' => ['type' => 'string', 'description' => "Mois YYYY-MM. Optionnel."],
                    ],
                ],
            ],
            [
                'name' => 'create_transaction',
                'description' => "Crée une nouvelle transaction pour l'utilisateur. À utiliser quand l'utilisateur demande explicitement d'ajouter une dépense ou un revenu.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'amount' => ['type' => 'number', 'description' => "Montant en FCFA (positif)"],
                        'type' => ['type' => 'string', 'description' => "Type : 'expense' (dépense) ou 'income' (revenu)"],
                        'category' => ['type' => 'string', 'description' => "Nom de la catégorie (ex: Transport, Nourriture)"],
                        'description' => ['type' => 'string', 'description' => "Description de la transaction"],
                        'date' => ['type' => 'string', 'description' => "Date au format YYYY-MM-DD. Optionnel, utilise aujourd'hui si omis."],
                        'wallet_id' => ['type' => 'number', 'description' => "ID du portefeuille. Optionnel, utilise le portefeuille par défaut si omis."],
                    ],
                    'required' => ['amount', 'type', 'category', 'description'],
                ],
            ],
            [
                'name' => 'suggest_category_for_transaction',
                'description' => "Suggère une catégorie pour une transaction basée sur sa description et son montant. À utiliser pour aider l'utilisateur à catégoriser une transaction.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'description' => ['type' => 'string', 'description' => "Description de la transaction"],
                        'amount' => ['type' => 'number', 'description' => "Montant en FCFA"],
                        'type' => ['type' => 'string', 'description' => "Type : 'expense' ou 'income'"],
                    ],
                    'required' => ['description', 'amount'],
                ],
            ],
            [
                'name' => 'get_month_over_month_comparison',
                'description' => "Compare les dépenses/revenus du mois en cours avec le mois précédent et l'année dernière. À utiliser pour analyser l'évolution temporelle.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'months' => ['type' => 'number', 'description' => "Nombre de mois à comparer (2-12). Défaut 3."],
                    ],
                ],
            ],
            [
                'name' => 'create_budget',
                'description' => "Crée un nouveau budget pour une catégorie. À utiliser quand l'utilisateur demande explicitement de créer un budget.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'category' => ['type' => 'string', 'description' => "Nom de la catégorie"],
                        'amount' => ['type' => 'number', 'description' => "Montant mensuel en FCFA"],
                        'period' => ['type' => 'string', 'description' => "Période : 'monthly' (mensuel) ou 'weekly' (hebdomadaire). Défaut 'monthly'."],
                        'start_date' => ['type' => 'string', 'description' => "Date de début au format YYYY-MM-DD. Optionnel."],
                        'end_date' => ['type' => 'string', 'description' => "Date de fin au format YYYY-MM-DD. Optionnel."],
                    ],
                    'required' => ['category', 'amount'],
                ],
            ],
            [
                'name' => 'suggest_savings_opportunities',
                'description' => "Identifie les opportunités d'épargne basées sur les dépenses récentes. À utiliser pour proposer des économies concrètes.",
                'parameters' => ['type' => 'object', 'properties' => (object) []],
            ],
            [
                'name' => 'create_goal',
                'description' => "Crée un nouvel objectif d'épargne. À utiliser quand l'utilisateur demande explicitement de créer un objectif.",
                'parameters' => [
                    'type' => 'object',
                    'properties' => [
                        'name' => ['type' => 'string', 'description' => "Nom de l'objectif"],
                        'target_amount' => ['type' => 'number', 'description' => "Montant cible en FCFA"],
                        'target_date' => ['type' => 'string', 'description' => "Date cible au format YYYY-MM-DD. Optionnel."],
                        'description' => ['type' => 'string', 'description' => "Description de l'objectif. Optionnel."],
                    ],
                    'required' => ['name', 'target_amount'],
                ],
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
            'get_transactions_sorted'   => $this->getTransactionsSorted($args),
            'create_transaction'         => $this->createTransaction($args),
            'suggest_category_for_transaction' => $this->suggestCategoryForTransaction($args),
            'get_month_over_month_comparison' => $this->getMonthOverMonthComparison($args),
            'create_budget'              => $this->createBudget($args),
            'suggest_savings_opportunities' => $this->suggestSavingsOpportunities(),
            'create_goal'                => $this->createGoal($args),
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

    public function getTransactionsSorted(array $args): array
    {
        $sortBy = $args['sort_by'] ?? 'amount';
        $order = $args['order'] ?? 'desc';
        $limit = (int) ($args['limit'] ?? 10);
        $limit = max(1, min(50, $limit));
        [$start, $end, $label] = $this->resolveMonth($args['month'] ?? null);

        $query = $this->user->transactions()
            ->whereBetween('transaction_date', [$start, $end])
            ->with('category:id,name')
            ->limit($limit);

        if ($sortBy === 'amount') {
            $query->orderBy('amount', $order);
        } elseif ($sortBy === 'date') {
            $query->orderBy('transaction_date', $order);
        }

        $transactions = $query->get()->map(fn ($t) => [
            'description' => $t->description,
            'amount_fcfa' => (float) $t->amount,
            'category' => $t->category?->name ?? 'Non catégorisé',
            'date' => $t->transaction_date->toDateString(),
            'type' => $t->type,
        ])->all();

        return [
            'month' => $label,
            'sort_by' => $sortBy,
            'order' => $order,
            'transactions' => $transactions,
        ];
    }

    public function suggestCategoryForTransaction(array $args): array
    {
        $description = mb_strtolower($args['description'] ?? '');
        $amount = (float) ($args['amount'] ?? 0);
        $type = $args['type'] ?? 'expense';

        if ($description === '') {
            return ['error' => 'Description requise'];
        }

        // Mapping simple mots-clés vers catégories
        $keywordMap = [
            'transport' => ['taxi', 'bus', 'car', 'voiture', 'essence', 'gazole', 'moto', 'uber', 'bolt', 'yango', 'transport', 'déplacement'],
            'nourriture' => ['resto', 'restaurant', 'café', 'cafe', 'pain', 'viande', 'poisson', 'légume', 'fruit', 'marché', 'supermarché', 'aliment', 'manger', 'repas'],
            'santé' => ['pharmacie', 'médicament', 'médecin', 'hôpital', 'santé', 'clinique', 'consultation', 'soins'],
            'communication' => ['orange', 'wave', 'free', 'internet', 'wifi', 'data', 'appel', 'sms', 'credit', 'recharge', 'forfait'],
            'logement' => ['loyer', 'électricité', 'eau', 'électricité', 'facture', 'maison', 'appart', 'location'],
            'loisirs' => ['cinéma', 'film', 'sport', 'gym', 'salle', 'musique', 'concert', 'jeu', 'sortie'],
            'vêtements' => ['vêtement', 'vetement', 'habit', 'chaussure', 'boutique', 'mode'],
            'éducation' => ['école', 'université', 'cours', 'livre', 'formation', 'étude'],
            'shopping' => ['achat', 'magasin', 'boutique', 'shopping', 'cadeau'],
        ];

        $suggestions = [];
        foreach ($keywordMap as $category => $keywords) {
            foreach ($keywords as $keyword) {
                if (str_contains($description, $keyword)) {
                    $suggestions[] = $category;
                    break;
                }
            }
        }

        // Récupérer les catégories existantes de l'utilisateur
        $userCategories = \App\Models\Category::where('user_id', $this->user->id)
            ->where('type', $type)
            ->pluck('name')
            ->toArray();

        // Filtrer les suggestions qui correspondent aux catégories de l'utilisateur
        $matchedSuggestions = array_intersect($suggestions, $userCategories);

        if (!empty($matchedSuggestions)) {
            return [
                'suggestions' => array_values($matchedSuggestions),
                'primary_suggestion' => $matchedSuggestions[array_key_first($matchedSuggestions)],
            ];
        }

        // Si pas de correspondance, retourner les catégories existantes triées par fréquence d'utilisation
        $topCategories = $this->user->transactions()
            ->where('type', $type)
            ->selectRaw('category_id, COUNT(*) as count')
            ->with('category:id,name')
            ->groupBy('category_id')
            ->orderByDesc('count')
            ->limit(3)
            ->get()
            ->map(fn ($t) => $t->category?->name)
            ->filter()
            ->toArray();

        return [
            'suggestions' => $topCategories,
            'primary_suggestion' => $topCategories[0] ?? null,
            'note' => 'Pas de correspondance par mots-clés, suggère les catégories les plus utilisées',
        ];
    }

    public function createTransaction(array $args): array
    {
        $amount = (float) ($args['amount'] ?? 0);
        $type = $args['type'] ?? 'expense';
        $categoryName = $args['category'] ?? '';
        $description = $args['description'] ?? '';
        $dateStr = $args['date'] ?? now()->toDateString();
        $walletId = $args['wallet_id'] ?? null;

        if ($amount <= 0) {
            return ['error' => 'Le montant doit être positif'];
        }

        if (!in_array($type, ['expense', 'income'])) {
            return ['error' => 'Le type doit être expense ou income'];
        }

        if ($categoryName === '') {
            return ['error' => 'Catégorie requise'];
        }

        if ($description === '') {
            return ['error' => 'Description requise'];
        }

        try {
            $date = Carbon::createFromFormat('Y-m-d', $dateStr);
        } catch (\Throwable) {
            $date = now();
        }

        // Trouver ou créer la catégorie
        $category = \App\Models\Category::firstOrCreate(
            ['user_id' => $this->user->id, 'name' => $categoryName],
            [
                'type' => $type,
                'color' => '#6366f1',
                'icon' => 'category',
            ]
        );

        // Trouver le portefeuille
        if ($walletId) {
            $wallet = Wallet::where('user_id', $this->user->id)->find($walletId);
        } else {
            $wallet = Wallet::where('user_id', $this->user->id)->where('is_default', true)->first();
        }

        if (!$wallet) {
            return ['error' => 'Portefeuille non trouvé'];
        }

        // Créer la transaction
        $transaction = Transaction::create([
            'user_id' => $this->user->id,
            'wallet_id' => $wallet->id,
            'category_id' => $category->id,
            'amount' => $amount,
            'type' => $type,
            'description' => $description,
            'transaction_date' => $date,
        ]);

        // Mettre à jour le solde du portefeuille
        if ($type === 'income') {
            $wallet->balance += $amount;
        } else {
            $wallet->balance -= $amount;
        }
        $wallet->save();

        return [
            'success' => true,
            'transaction_id' => $transaction->id,
            'amount_fcfa' => $amount,
            'type' => $type,
            'category' => $category->name,
            'description' => $description,
            'date' => $date->toDateString(),
            'wallet_balance_fcfa' => (float) $wallet->balance,
        ];
    }

    public function getMonthOverMonthComparison(array $args): array
    {
        $months = max(2, min(12, (int) ($args['months'] ?? 3)));
        $comparisons = [];

        for ($i = 0; $i < $months; $i++) {
            $ref = now()->subMonths($i)->startOfMonth();
            $start = $ref->copy()->startOfMonth();
            $end = $ref->copy()->endOfMonth();
            $label = $ref->format('Y-m');

            $stats = $this->user->transactions()
                ->whereBetween('transaction_date', [$start, $end])
                ->selectRaw("
                    COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
                    COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expense,
                    COUNT(*) as count
                ")->first();

            $comparisons[] = [
                'month' => $label,
                'income_fcfa' => (float) $stats->income,
                'expense_fcfa' => (float) $stats->expense,
                'net_fcfa' => (float) $stats->income - (float) $stats->expense,
                'transactions_count' => (int) $stats->count,
            ];
        }

        // Calculer les variations
        $trend = [];
        for ($i = 1; $i < count($comparisons); $i++) {
            $current = $comparisons[$i];
            $previous = $comparisons[$i - 1];

            $expenseChange = $previous['expense_fcfa'] > 0
                ? (($current['expense_fcfa'] - $previous['expense_fcfa']) / $previous['expense_fcfa']) * 100
                : 0;
            $incomeChange = $previous['income_fcfa'] > 0
                ? (($current['income_fcfa'] - $previous['income_fcfa']) / $previous['income_fcfa']) * 100
                : 0;

            $trend[] = [
                'from_month' => $previous['month'],
                'to_month' => $current['month'],
                'expense_change_percent' => round($expenseChange, 1),
                'income_change_percent' => round($incomeChange, 1),
                'expense_direction' => $expenseChange > 0 ? 'increase' : ($expenseChange < 0 ? 'decrease' : 'stable'),
                'income_direction' => $incomeChange > 0 ? 'increase' : ($incomeChange < 0 ? 'decrease' : 'stable'),
            ];
        }

        return [
            'comparisons' => array_reverse($comparisons),
            'trend' => array_reverse($trend),
        ];
    }

    public function createBudget(array $args): array
    {
        $categoryName = $args['category'] ?? '';
        $amount = (float) ($args['amount'] ?? 0);
        $period = $args['period'] ?? 'monthly';
        $startDateStr = $args['start_date'] ?? now()->toDateString();
        $endDateStr = $args['end_date'] ?? now()->addMonths(3)->toDateString();

        if ($categoryName === '') {
            return ['error' => 'Catégorie requise'];
        }

        if ($amount <= 0) {
            return ['error' => 'Le montant doit être positif'];
        }

        if (!in_array($period, ['monthly', 'weekly'])) {
            return ['error' => 'La période doit être monthly ou weekly'];
        }

        try {
            $startDate = Carbon::createFromFormat('Y-m-d', $startDateStr);
            $endDate = Carbon::createFromFormat('Y-m-d', $endDateStr);
        } catch (\Throwable) {
            $startDate = now();
            $endDate = now()->addMonths(3);
        }

        // Trouver ou créer la catégorie
        $category = \App\Models\Category::firstOrCreate(
            ['user_id' => $this->user->id, 'name' => $categoryName],
            [
                'type' => 'expense',
                'color' => '#6366f1',
                'icon' => 'category',
            ]
        );

        // Vérifier si un budget existe déjà pour cette catégorie
        $existing = Budget::where('user_id', $this->user->id)
            ->where('category_id', $category->id)
            ->where('is_active', true)
            ->where('start_date', '<=', now())
            ->where('end_date', '>=', now())
            ->first();

        if ($existing) {
            return ['error' => 'Un budget existe déjà pour cette catégorie'];
        }

        // Créer le budget
        $budget = Budget::create([
            'user_id' => $this->user->id,
            'category_id' => $category->id,
            'amount' => $amount,
            'period' => $period,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'is_active' => true,
        ]);

        return [
            'success' => true,
            'budget_id' => $budget->id,
            'category' => $category->name,
            'amount_fcfa' => $amount,
            'period' => $period,
            'start_date' => $startDate->toDateString(),
            'end_date' => $endDate->toDateString(),
        ];
    }

    public function suggestSavingsOpportunities(): array
    {
        [$start, $end, $label] = $this->resolveMonth(null);

        // Analyser les dépenses par catégorie
        $categorySpending = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw('category_id, SUM(amount) as total, COUNT(*) as count')
            ->with('category:id,name')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->get();

        // Calculer le total des dépenses
        $totalExpenses = $categorySpending->sum('total');

        $opportunities = [];

        // Catégories avec dépenses élevées (> 15% du total)
        foreach ($categorySpending as $cat) {
            $percentage = $totalExpenses > 0 ? ($cat->total / $totalExpenses) * 100 : 0;
            if ($percentage > 15) {
                $potentialSavings = $cat->total * 0.1; // 10% d'économie potentielle
                $opportunities[] = [
                    'category' => $cat->category?->name ?? 'Non catégorisé',
                    'current_spending_fcfa' => (float) $cat->total,
                    'percentage_of_total' => round($percentage, 1),
                    'potential_monthly_savings_fcfa' => round($potentialSavings),
                    'potential_yearly_savings_fcfa' => round($potentialSavings * 12),
                    'suggestion' => "Réduire de 10% les dépenses dans cette catégorie pourrait t'économiser " . number_format($potentialSavings, 0, ',', ' ') . " FCFA/mois",
                ];
            }
        }

        // Dépenses fréquentes (petits montants répétés)
        $frequentSmall = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->selectRaw('description, amount, COUNT(*) as count')
            ->where('amount', '<', 5000)
            ->groupBy('description', 'amount')
            ->having('count', '>=', 5)
            ->orderByDesc('count')
            ->limit(5)
            ->get();

        foreach ($frequentSmall as $item) {
            $monthlyTotal = $item->amount * $item->count;
            $opportunities[] = [
                'type' => 'recurring_small',
                'description' => $item->description,
                'amount_fcfa' => (float) $item->amount,
                'frequency_month' => (int) $item->count,
                'monthly_total_fcfa' => (float) $monthlyTotal,
                'suggestion' => "Cette petite dépense de " . number_format($item->amount, 0, ',', ' ') . " FCFA apparaît {$item->count} fois ce mois. Total mensuel : " . number_format($monthlyTotal, 0, ',', ' ') . " FCFA",
            ];
        }

        // Comparaison avec le mois précédent
        $lastMonthStart = now()->subMonth()->startOfMonth();
        $lastMonthEnd = now()->subMonth()->endOfMonth();

        $lastMonthExpenses = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$lastMonthStart, $lastMonthEnd])
            ->sum('amount');

        $thisMonthExpenses = $this->user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$start, $end])
            ->sum('amount');

        if ($lastMonthExpenses > 0) {
            $change = (($thisMonthExpenses - $lastMonthExpenses) / $lastMonthExpenses) * 100;
            if ($change > 10) {
                $opportunities[] = [
                    'type' => 'trend_alert',
                    'change_percent' => round($change, 1),
                    'last_month_fcfa' => (float) $lastMonthExpenses,
                    'this_month_fcfa' => (float) $thisMonthExpenses,
                    'suggestion' => "Tes dépenses ont augmenté de " . round($change, 1) . "% par rapport au mois dernier. Analyse tes catégories principales.",
                ];
            }
        }

        return [
            'month' => $label,
            'total_expenses_fcfa' => (float) $totalExpenses,
            'opportunities' => array_slice($opportunities, 0, 5),
        ];
    }

    public function createGoal(array $args): array
    {
        $name = $args['name'] ?? '';
        $targetAmount = (float) ($args['target_amount'] ?? 0);
        $targetDateStr = $args['target_date'] ?? null;
        $description = $args['description'] ?? '';

        if ($name === '') {
            return ['error' => 'Nom requis'];
        }

        if ($targetAmount <= 0) {
            return ['error' => 'Le montant cible doit être positif'];
        }

        $targetDate = null;
        if ($targetDateStr) {
            try {
                $targetDate = Carbon::createFromFormat('Y-m-d', $targetDateStr);
            } catch (\Throwable) {
                $targetDate = null;
            }
        }

        // Créer l'objectif
        $goal = FinancialGoal::create([
            'user_id' => $this->user->id,
            'name' => $name,
            'target_amount' => $targetAmount,
            'current_amount' => 0,
            'target_date' => $targetDate,
            'description' => $description,
        ]);

        // Calculer le nombre de mois pour atteindre l'objectif
        $monthsToReach = null;
        if ($targetDate) {
            $monthsToReach = now()->diffInMonths($targetDate, false);
        }

        return [
            'success' => true,
            'goal_id' => $goal->id,
            'name' => $goal->name,
            'target_amount_fcfa' => (float) $goal->target_amount,
            'current_amount_fcfa' => 0,
            'target_date' => $targetDate?->toDateString(),
            'months_to_reach' => $monthsToReach,
            'monthly_savings_needed_fcfa' => $monthsToReach && $monthsToReach > 0 ? round($targetAmount / $monthsToReach) : null,
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
