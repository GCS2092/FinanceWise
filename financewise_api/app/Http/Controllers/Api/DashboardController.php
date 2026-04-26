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

class DashboardController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = auth()->user();
        $now = now();
        $startOfMonth = $now->copy()->startOfMonth();
        $endOfMonth = $now->copy()->endOfMonth();

        $totalIncome = $user->transactions()
            ->where('type', 'income')
            ->whereBetween('transaction_date', [$startOfMonth, $endOfMonth])
            ->sum('amount');

        $totalExpense = $user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$startOfMonth, $endOfMonth])
            ->sum('amount');

        $balance = $user->wallets()->sum('balance');

        $monthlyIncomeTarget = $user->monthly_income_target ?? 0;
        $incomeProgress = $monthlyIncomeTarget > 0 ? ($totalIncome / $monthlyIncomeTarget) * 100 : 0;

        $topCategories = $user->transactions()
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$startOfMonth, $endOfMonth])
            ->selectRaw('category_id, SUM(amount) as total')
            ->groupBy('category_id')
            ->orderByDesc('total')
            ->limit(5)
            ->with('category')
            ->get();

        $recentTransactions = $user->transactions()
            ->with('category', 'wallet')
            ->latest('transaction_date')
            ->limit(10)
            ->get();

        $budgets = Budget::where('user_id', $user->id)
            ->where('is_active', true)
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now)
            ->with('category')
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

        // Alertes de revenu
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

        return response()->json([
            'balance' => (float) $balance,
            'monthly_income' => (float) $totalIncome,
            'monthly_expense' => (float) $totalExpense,
            'monthly_income_target' => (float) $monthlyIncomeTarget,
            'income_progress' => (float) $incomeProgress,
            'top_categories' => $topCategories->map(function ($item) {
                return [
                    'category' => new CategoryResource($item->category),
                    'total' => (float) $item->total,
                ];
            }),
            'recent_transactions' => TransactionResource::collection($recentTransactions),
            'budgets' => BudgetResource::collection($budgets),
            'alerts' => $alerts,
        ]);
    }
}
