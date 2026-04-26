<?php

namespace App\Observers;

use App\Models\Transaction;
use App\Models\Budget;

class TransactionObserver
{
    public function created(Transaction $transaction)
    {
        if ($transaction->type === 'expense') {
            $this->updateRelatedBudgets($transaction);
            $this->checkBudgetAlerts($transaction);
        }
    }

    public function updated(Transaction $transaction)
    {
        $this->updateRelatedBudgets($transaction);
        $this->checkBudgetAlerts($transaction);
    }

    public function deleted(Transaction $transaction)
    {
        $this->updateRelatedBudgets($transaction);
    }

    private function updateRelatedBudgets(Transaction $transaction)
    {
        // Trouver tous les budgets actifs pour cette catégorie
        $budgets = Budget::where('category_id', $transaction->category_id)
            ->where('is_active', true)
            ->where('start_date', '<=', $transaction->transaction_date)
            ->where('end_date', '>=', $transaction->transaction_date)
            ->get();

        foreach ($budgets as $budget) {
            $budget->updateSpent();
        }
    }

    private function checkBudgetAlerts(Transaction $transaction)
    {
        // Trouver les budgets actifs pour cette catégorie
        $budgets = Budget::where('category_id', $transaction->category_id)
            ->where('is_active', true)
            ->where('start_date', '<=', $transaction->transaction_date)
            ->where('end_date', '>=', $transaction->transaction_date)
            ->get();

        foreach ($budgets as $budget) {
            $percentage = $budget->percentage;
            
            // Alerte si le budget est dépassé ou à 90%+
            if ($percentage >= 100) {
                $this->sendBudgetAlert($budget, 'Budget dépassé', "Tu as dépassé ton budget de {$budget->category->name} !");
            } elseif ($percentage >= 90 && $percentage < 100) {
                $this->sendBudgetAlert($budget, 'Budget presque atteint', "Tu as atteint {$percentage}% de ton budget de {$budget->category->name}");
            }
        }
    }

    private function sendBudgetAlert(Budget $budget, $title, $message)
    {
        // Stocker l'alerte dans la base de données
        \App\Models\Alert::create([
            'user_id' => $budget->user_id,
            'type' => 'budget',
            'title' => $title,
            'message' => $message,
            'is_read' => false,
        ]);

        // Envoyer notification push (si FCM token existe)
        $user = $budget->user;
        if ($user && $user->fcm_token) {
            // Ici tu pourrais utiliser Laravel FCM ou un autre service de push notifications
            // Pour l'instant, l'alerte est stockée en base de données
            // et sera récupérée par l'app Flutter via polling ou WebSocket
        }
    }
}
