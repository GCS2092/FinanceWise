<?php

namespace App\Observers;

use App\Models\FinancialGoal;
use App\Models\Alert;

class FinancialGoalObserver
{
    public function updated(FinancialGoal $goal)
    {
        // Calculer la progression
        if ($goal->target_amount > 0) {
            $percentage = ($goal->current_amount / $goal->target_amount) * 100;
            
            // Alertes de progression (25%, 50%, 75%)
            if ($percentage >= 25 && $percentage < 26) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Progression objectif 25%',
                    'message' => "Objectif '{$goal->name}': Vous avez atteint 25% de votre objectif",
                    'severity' => 'info',
                    'data' => [
                        'goal_id' => $goal->id,
                        'percentage' => 25,
                        'current_amount' => $goal->current_amount,
                        'target_amount' => $goal->target_amount,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            } elseif ($percentage >= 50 && $percentage < 51) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Progression objectif 50%',
                    'message' => "Objectif '{$goal->name}': Vous avez atteint 50% de votre objectif !",
                    'severity' => 'success',
                    'data' => [
                        'goal_id' => $goal->id,
                        'percentage' => 50,
                        'current_amount' => $goal->current_amount,
                        'target_amount' => $goal->target_amount,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            } elseif ($percentage >= 75 && $percentage < 76) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Progression objectif 75%',
                    'message' => "Objectif '{$goal->name}': Vous avez atteint 75% de votre objectif !",
                    'severity' => 'success',
                    'data' => [
                        'goal_id' => $goal->id,
                        'percentage' => 75,
                        'current_amount' => $goal->current_amount,
                        'target_amount' => $goal->target_amount,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            }
            
            // Alerte quand l'objectif est atteint
            if ($percentage >= 100 && $goal->status === 'completed') {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Objectif atteint !',
                    'message' => "Félicitations ! Vous avez atteint votre objectif '{$goal->name}'",
                    'severity' => 'success',
                    'data' => [
                        'goal_id' => $goal->id,
                        'current_amount' => $goal->current_amount,
                        'target_amount' => $goal->target_amount,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            }
        }

        // Alertes de date limite
        if ($goal->target_date && $goal->status !== 'completed') {
            $targetDate = \Carbon\Carbon::parse($goal->target_date);
            $now = \Carbon\Carbon::now();
            $daysRemaining = $now->diffInDays($targetDate, false);
            
            // Alerte 7 jours avant
            if ($daysRemaining == 7) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Date limite approche',
                    'message' => "Objectif '{$goal->name}': Il vous reste 7 jours pour atteindre votre objectif",
                    'severity' => 'warning',
                    'data' => [
                        'goal_id' => $goal->id,
                        'days_remaining' => 7,
                        'target_date' => $goal->target_date,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            }
            
            // Alerte 3 jours avant
            if ($daysRemaining == 3) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Date limite proche',
                    'message' => "Objectif '{$goal->name}': Il vous reste 3 jours pour atteindre votre objectif",
                    'severity' => 'warning',
                    'data' => [
                        'goal_id' => $goal->id,
                        'days_remaining' => 3,
                        'target_date' => $goal->target_date,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            }
            
            // Alerte jour J
            if ($daysRemaining == 0) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Date limite aujourd\'hui',
                    'message' => "Objectif '{$goal->name}': C'est aujourd'hui la date limite de votre objectif",
                    'severity' => 'danger',
                    'data' => [
                        'goal_id' => $goal->id,
                        'days_remaining' => 0,
                        'target_date' => $goal->target_date,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            }
            
            // Alerte retardé
            if ($daysRemaining < 0 && abs($daysRemaining) == 1) {
                Alert::firstOrCreate([
                    'user_id' => $goal->user_id,
                    'type' => 'goal',
                    'title' => 'Objectif en retard',
                    'message' => "Objectif '{$goal->name}': La date limite est passée de 1 jour",
                    'severity' => 'danger',
                    'data' => [
                        'goal_id' => $goal->id,
                        'days_overdue' => abs($daysRemaining),
                        'target_date' => $goal->target_date,
                    ],
                ], [
                    'created_at' => now(),
                ]);
            }
        }
    }
}
