<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\BudgetResource;
use App\Http\Resources\CategoryResource;
use App\Http\Resources\TransactionResource;
use App\Models\Budget;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = auth()->user();
        $cacheKey = "dashboard:{$user->id}";

        // Cache réduit à 60 secondes pour plus de fraîcheur des données
        $data = Cache::remember($cacheKey, 60, function () use ($user) {
            return $this->buildDashboard($user);
        });

        return response()->json($data);
    }

    protected function buildDashboard($user): array
    {
        $now = now();
        $startOfMonth = $now->copy()->startOfMonth();
        $endOfMonth = $now->copy()->endOfMonth();

        // Optimisation: une seule requête pour revenus + dépenses + solde
        $stats = $user->transactions()
            ->whereBetween('transaction_date', [$startOfMonth, $endOfMonth])
            ->selectRaw("
                COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income,
                COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense
            ")
            ->first();

        $totalIncome = (float) $stats->total_income;
        $totalExpense = (float) $stats->total_expense;

        // Optimisation: solde calculé directement depuis wallets (cache côté DB)
        $balance = (float) $user->wallets()->sum('balance');

        $monthlyIncomeTarget = $user->monthly_income_target ?? 0;
        $incomeProgress = $monthlyIncomeTarget > 0 ? ($totalIncome / $monthlyIncomeTarget) * 100 : 0;

        // Compter les transactions non catégorisées
        $uncategorizedCount = $user->transactions()
            ->where('type', 'expense')
            ->where(function ($query) {
                $query->whereNull('category_id')
                    ->orWhereHas('category', function ($q) {
                        $q->where('name', 'Autre');
                    });
            })
            ->count();

        // Optimisation: limité à 3 catégories au lieu de 5 pour réduire la charge
        $topCategories = $user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$startOfMonth, $endOfMonth])
            ->selectRaw('category_id, SUM(amount) as total')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->limit(3)
            ->with('category')
            ->get();

        // Optimisation: limité à 5 transactions au lieu de 10
        $recentTransactions = $user->transactions()
            ->with('category:id,name', 'wallet:id,name,balance')
            ->latest('transaction_date')
            ->limit(5)
            ->get();

        // Optimisation: budgets avec eager loading minimal
        $budgets = Budget::where('user_id', $user->id)
            ->where('is_active', true)
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now)
            ->with('category:id,name,icon')
            ->get();

        $alerts = [];
        foreach ($budgets as $budget) {
            if ($budget->percentage >= 100) {
                $alerts[] = [
                    'type' => 'danger',
                    'message' => "Budget {$budget->category->name} dépassé ({$budget->percentage}%)",
                ];
            } elseif ($budget->percentage >= 80) {
                $alerts[] = [
                    'type' => 'warning',
                    'message' => "Budget {$budget->category->name} à {$budget->percentage}%",
                ];
            }
        }

        if ($monthlyIncomeTarget > 0) {
            if ($incomeProgress >= 100) {
                $alerts[] = [
                    'type' => 'success',
                    'message' => "Objectif de revenu atteint ! (" . number_format($incomeProgress, 0) . "%)",
                ];
            } elseif ($incomeProgress >= 80) {
                $alerts[] = [
                    'type' => 'info',
                    'message' => "Vous êtes à " . number_format($incomeProgress, 0) . "% de votre objectif de revenu",
                ];
            }
        }

        // Ajouter une alerte pour les transactions non catégorisées
        if ($uncategorizedCount > 0) {
            $alerts[] = [
                'type' => 'warning',
                'message' => "Vous avez $uncategorizedCount transaction(s) non catégorisée(s) dans le wallet Divers. Consultez vos wallets pour voir les détails.",
                'action' => 'view_divers_wallet',
            ];
        }

        return [
            'balance' => $balance,
            'monthly_income' => $totalIncome,
            'monthly_expense' => $totalExpense,
            'monthly_income_target' => (float) $monthlyIncomeTarget,
            'income_progress' => (float) $incomeProgress,
            'uncategorized_count' => $uncategorizedCount,
            'top_categories' => $topCategories->map(function ($item) {
                return [
                    'category' => $item->category ? new CategoryResource($item->category) : null,
                    'total' => (float) $item->total,
                ];
            }),
            'recent_transactions' => TransactionResource::collection($recentTransactions),
            'budgets' => BudgetResource::collection($budgets),
            'alerts' => $alerts,
        ];
    }
}
