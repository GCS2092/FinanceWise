<?php

namespace App\Jobs;

use App\Models\Alert;
use App\Models\Budget;
use App\Models\Transaction;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class BudgetAlertJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 2;
    public int $timeout = 15;

    public function __construct(
        protected int $transactionId,
    ) {}

    public function handle(): void
    {
        $transaction = Transaction::find($this->transactionId);
        if (!$transaction || $transaction->type !== 'expense' || !$transaction->category_id) {
            return;
        }

        $budget = Budget::where('category_id', $transaction->category_id)
            ->where('user_id', $transaction->user_id)
            ->where('is_active', true)
            ->where('start_date', '<=', $transaction->transaction_date)
            ->where('end_date', '>=', $transaction->transaction_date)
            ->with('category')
            ->first();

        if (!$budget || !$budget->category) return;

        $percentage = $budget->percentage;

        if ($percentage >= 100) {
            $this->createAlert(
                $transaction->user_id,
                'danger',
                "Budget {$budget->category->name} depassé",
                "Votre budget {$budget->category->name} est à {$percentage}%. Vous avez dépassé la limite de " . number_format($budget->amount, 0, ',', ' ') . " FCFA."
            );
        } elseif ($percentage >= 80) {
            $this->createAlert(
                $transaction->user_id,
                'warning',
                "Budget {$budget->category->name} bientôt épuisé",
                "Votre budget {$budget->category->name} est à {$percentage}%. Attention à vos dépenses."
            );
        }
    }

    protected function createAlert(int $userId, string $type, string $title, string $message): void
    {
        try {
            Alert::create([
                'user_id' => $userId,
                'type' => $type,
                'title' => $title,
                'message' => $message,
                'is_read' => false,
            ]);
        } catch (\Exception $e) {
            Log::warning('Impossible de créer une alerte budget', [
                'user_id' => $userId,
                'error' => $e->getMessage(),
            ]);
        }
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('BudgetAlertJob failed', [
            'transaction_id' => $this->transactionId,
            'error' => $exception->getMessage(),
        ]);
    }
}
