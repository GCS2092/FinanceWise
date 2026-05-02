<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use App\Models\Budget;
use App\Models\FinancialGoal;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class OnboardingController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'monthly_income_target' => 'nullable|numeric|min:0',
            'wallets' => 'nullable|array',
            'wallets.*.name' => 'required|string|max:255',
            'wallets.*.balance' => 'nullable|numeric|min:0',
            'wallets.*.type' => 'required|string|in:cash,bank,mobile_money',
            'budgets' => 'nullable|array',
            'budgets.*.category_id' => 'nullable|exists:categories,id',
            'budgets.*.amount' => 'nullable|numeric|min:0',
            'budgets.*.period' => 'required|string|in:daily,weekly,monthly,yearly',
            'goals' => 'nullable|array',
            'goals.*.name' => 'required|string|max:255',
            'goals.*.target_amount' => 'nullable|numeric|min:0',
            'goals.*.icon' => 'nullable|string',
            'goals.*.color' => 'nullable|string',
        ]);

        $user = auth()->user();

        // Sauvegarder le revenu mensuel cible
        $user->update([
            'monthly_income_target' => $validated['monthly_income_target'] ?? 0,
            'onboarding_completed' => true,
        ]);

        // Créer les wallets par défaut
        if (isset($validated['wallets']) && is_array($validated['wallets'])) {
            foreach ($validated['wallets'] as $walletData) {
                Wallet::create([
                    'user_id' => $user->id,
                    'name' => !empty($walletData['name']) ? $walletData['name'] : 'Portefeuille',
                    'balance' => $walletData['balance'] ?? 0,
                    'type' => $walletData['type'] ?? 'cash',
                    'is_default' => false,
                ]);
            }
        }

        // Créer les budgets
        if (isset($validated['budgets']) && is_array($validated['budgets'])) {
            foreach ($validated['budgets'] as $budgetData) {
                if (!empty($budgetData['amount'])) {
                    $now = now();
                    Budget::create([
                        'user_id' => $user->id,
                        'category_id' => $budgetData['category_id'] ?? null,
                        'amount' => $budgetData['amount'],
                        'period' => $budgetData['period'] ?? 'monthly',
                        'start_date' => $now->copy()->startOfMonth(),
                        'end_date' => $now->copy()->endOfMonth(),
                        'spent' => 0,
                        'is_active' => true,
                    ]);
                }
            }
        }

        // Créer les objectifs financiers
        if (isset($validated['goals']) && is_array($validated['goals'])) {
            foreach ($validated['goals'] as $goalData) {
                if (!empty($goalData['name'])) {
                    FinancialGoal::create([
                        'user_id' => $user->id,
                        'name' => $goalData['name'],
                        'target_amount' => $goalData['target_amount'] ?? 0,
                        'current_amount' => 0,
                        'icon' => $goalData['icon'] ?? 'savings',
                        'color' => $goalData['color'] ?? '#4CAF50',
                        'status' => 'pending',
                    ]);
                }
            }
        }

        return response()->json([
            'message' => 'Onboarding complété avec succès',
            'user' => $user->fresh(),
            'wallets_created' => $request->has('wallets') ? count($request->wallets) : 0,
            'budgets_created' => $request->has('budgets') ? count(array_filter($request->budgets, fn($b) => !empty($b['amount']))) : 0,
            'goals_created' => $request->has('goals') ? count(array_filter($request->goals, fn($g) => !empty($g['name']))) : 0,
        ]);
    }

    public function checkStatus(): JsonResponse
    {
        $user = auth()->user();

        return response()->json([
            'onboarding_completed' => $user->onboarding_completed ?? false,
            'monthly_income_target' => $user->monthly_income_target,
        ]);
    }
}
