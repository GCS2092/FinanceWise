<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use App\Models\Budget;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class OnboardingController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $user = auth()->user();

        // Sauvegarder le revenu mensuel cible
        $user->update([
            'monthly_income_target' => $request->monthly_income_target,
            'onboarding_completed' => true,
        ]);

        // Créer les wallets par défaut
        if ($request->has('wallets') && is_array($request->wallets)) {
            foreach ($request->wallets as $walletData) {
                if (!empty($walletData['name'])) {
                    Wallet::create([
                        'user_id' => $user->id,
                        'name' => $walletData['name'],
                        'balance' => $walletData['balance'] ?? 0,
                        'type' => $walletData['type'] ?? 'cash',
                        'is_default' => false,
                    ]);
                }
            }
        }

        // Créer les budgets
        if ($request->has('budgets') && is_array($request->budgets)) {
            foreach ($request->budgets as $budgetData) {
                if (!empty($budgetData['amount']) && !empty($budgetData['category_id'])) {
                    $now = now();
                    Budget::create([
                        'user_id' => $user->id,
                        'category_id' => $budgetData['category_id'],
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

        return response()->json([
            'message' => 'Onboarding complété avec succès',
            'user' => $user->fresh(),
            'wallets_created' => $request->has('wallets') ? count($request->wallets) : 0,
            'budgets_created' => $request->has('budgets') ? count(array_filter($request->budgets, fn($b) => !empty($b['amount']) && !empty($b['category_id']))) : 0,
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
