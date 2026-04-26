<?php

namespace App\Services;

use App\Models\Budget;
use App\Models\Transaction;

class BudgetService
{
    public function recalculateSpent(Budget $budget): void
    {
        $spent = Transaction::where('user_id', $budget->user_id)
            ->where('category_id', $budget->category_id)
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$budget->start_date, $budget->end_date])
            ->sum('amount');

        $budget->spent = $spent;
        $budget->save();
    }

    public function checkAlerts(Budget $budget): array
    {
        $alerts = [];

        if ($budget->percentage >= 100) {
            $alerts[] = 'Budget dépassé pour ' . $budget->category->name;
        } elseif ($budget->percentage >= 80) {
            $alerts[] = 'Budget à 80% pour ' . $budget->category->name;
        }

        return $alerts;
    }
}
