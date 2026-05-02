<?php

namespace App\Observers;

use App\Models\Budget;
use App\Models\Alert;
use App\Notifications\BudgetAlertNotification;

class BudgetObserver
{
    public function updated(Budget $budget)
    {
        // Vérifier si le budget a été dépassé
        if ($budget->spent > $budget->limit) {
            $percentage = ($budget->spent / $budget->limit) * 100;
            
            // Créer une alerte de dépassement de budget
            Alert::create([
                'user_id' => $budget->user_id,
                'type' => 'budget',
                'title' => 'Budget dépassé',
                'message' => sprintf(
                    "Catégorie %s: %s FCFA dépensés sur %s FCFA (%.0f%%)",
                    $budget->category->name,
                    number_format($budget->spent, 0, '', ' '),
                    number_format($budget->limit, 0, '', ' '),
                    $percentage
                ),
                'severity' => 'danger',
                'data' => [
                    'budget_id' => $budget->id,
                    'category_id' => $budget->category_id,
                    'spent' => $budget->spent,
                    'limit' => $budget->limit,
                    'percentage' => $percentage,
                ],
            ]);
        }
        
        // Alertes de progression (80%, 90%, 95%)
        $percentage = ($budget->spent / $budget->limit) * 100;
        
        if ($percentage >= 80 && $percentage < 90) {
            Alert::firstOrCreate([
                'user_id' => $budget->user_id,
                'type' => 'budget',
                'title' => 'Alerte Budget 80%',
                'message' => sprintf(
                    "Catégorie %s: Vous avez utilisé %.0f%% de votre budget",
                    $budget->category->name,
                    $percentage
                ),
                'severity' => 'warning',
                'data' => [
                    'budget_id' => $budget->id,
                    'category_id' => $budget->category_id,
                    'percentage' => 80,
                ],
            ], [
                'created_at' => now(),
            ]);
        } elseif ($percentage >= 90 && $percentage < 95) {
            Alert::firstOrCreate([
                'user_id' => $budget->user_id,
                'type' => 'budget',
                'title' => 'Alerte Budget 90%',
                'message' => sprintf(
                    "Catégorie %s: Vous avez utilisé %.0f%% de votre budget",
                    $budget->category->name,
                    $percentage
                ),
                'severity' => 'warning',
                'data' => [
                    'budget_id' => $budget->id,
                    'category_id' => $budget->category_id,
                    'percentage' => 90,
                ],
            ], [
                'created_at' => now(),
            ]);
        } elseif ($percentage >= 95 && $percentage < 100) {
            Alert::firstOrCreate([
                'user_id' => $budget->user_id,
                'type' => 'budget',
                'title' => 'Alerte Budget 95%',
                'message' => sprintf(
                    "Catégorie %s: Vous avez utilisé %.0f%% de votre budget",
                    $budget->category->name,
                    $percentage
                ),
                'severity' => 'danger',
                'data' => [
                    'budget_id' => $budget->id,
                    'category_id' => $budget->category_id,
                    'percentage' => 95,
                ],
            ], [
                'created_at' => now(),
            ]);
        }
    }
}
