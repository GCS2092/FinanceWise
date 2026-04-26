<?php

namespace App\Services;

use App\Models\Transaction;
use App\Models\Wallet;
use Illuminate\Support\Facades\DB;

class TransactionService
{
    public function create(array $data, int $userId): Transaction
    {
        return DB::transaction(function () use ($data, $userId) {
            $data['user_id'] = $userId;
            $transaction = Transaction::create($data);

            $this->updateWalletBalance($transaction);
            $this->updateBudgetSpent($transaction);

            return $transaction;
        });
    }

    public function update(Transaction $transaction, array $data): Transaction
    {
        return DB::transaction(function () use ($transaction, $data) {
            $oldWalletId = $transaction->wallet_id;
            $oldAmount = $transaction->amount;
            $oldType = $transaction->type;
            $oldCategoryId = $transaction->category_id;
            $oldDate = $transaction->transaction_date;

            $transaction->update($data);
            $transaction->refresh();

            // Revert old wallet
            if ($oldWalletId) {
                $oldWallet = Wallet::find($oldWalletId);
                if ($oldWallet) {
                    if ($oldType === 'income') {
                        $oldWallet->balance -= $oldAmount;
                    } elseif ($oldType === 'expense') {
                        $oldWallet->balance += $oldAmount;
                    }
                    $oldWallet->save();
                }
            }

            // Revert old budget
            if ($oldCategoryId && $oldType === 'expense') {
                $oldBudget = \App\Models\Budget::where('category_id', $oldCategoryId)
                    ->where('user_id', $transaction->user_id)
                    ->where('start_date', '<=', $oldDate)
                    ->where('end_date', '>=', $oldDate)
                    ->first();
                if ($oldBudget) {
                    $oldBudget->spent = max(0, $oldBudget->spent - $oldAmount);
                    $oldBudget->save();
                }
            }

            // Apply new wallet and budget
            $this->updateWalletBalance($transaction);
            $this->updateBudgetSpent($transaction);

            return $transaction;
        });
    }

    public function delete(Transaction $transaction): void
    {
        DB::transaction(function () use ($transaction) {
            $this->revertWalletBalance($transaction);
            $this->revertBudgetSpent($transaction);
            $transaction->delete();
        });
    }

    protected function updateWalletBalance(Transaction $transaction): void
    {
        $wallet = Wallet::find($transaction->wallet_id);
        if (!$wallet) return;

        if ($transaction->type === 'income') {
            $wallet->balance += $transaction->amount;
        } elseif ($transaction->type === 'expense') {
            $wallet->balance -= $transaction->amount;
        }

        $wallet->save();
    }

    protected function revertWalletBalance(Transaction $transaction): void
    {
        $wallet = Wallet::find($transaction->wallet_id);
        if (!$wallet) return;

        if ($transaction->type === 'income') {
            $wallet->balance -= $transaction->amount;
        } elseif ($transaction->type === 'expense') {
            $wallet->balance += $transaction->amount;
        }

        $wallet->save();
    }

    protected function updateBudgetSpent(Transaction $transaction): void
    {
        if ($transaction->type !== 'expense' || !$transaction->category_id) return;

        $budget = \App\Models\Budget::where('category_id', $transaction->category_id)
            ->where('user_id', $transaction->user_id)
            ->where('is_active', true)
            ->where('start_date', '<=', $transaction->transaction_date)
            ->where('end_date', '>=', $transaction->transaction_date)
            ->first();

        if ($budget) {
            $budget->spent += $transaction->amount;
            $budget->save();
        }
    }

    protected function revertBudgetSpent(Transaction $transaction): void
    {
        if ($transaction->type !== 'expense' || !$transaction->category_id) return;

        $budget = \App\Models\Budget::where('category_id', $transaction->category_id)
            ->where('user_id', $transaction->user_id)
            ->where('start_date', '<=', $transaction->transaction_date)
            ->where('end_date', '>=', $transaction->transaction_date)
            ->first();

        if ($budget) {
            $budget->spent = max(0, $budget->spent - $transaction->amount);
            $budget->save();
        }
    }
}
