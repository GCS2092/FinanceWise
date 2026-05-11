<?php

namespace App\Services;

use App\Http\Controllers\Api\WalletController;
use App\Jobs\BudgetAlertJob;
use App\Models\Transaction;
use App\Models\Wallet;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class TransactionService
{
    public function create(array $data, int $userId): Transaction
    {
        return DB::transaction(function () use ($data, $userId) {
            $data['user_id'] = $userId;

            // Si category_name est fourni, trouver le category_id correspondant
            if (isset($data['category_name']) && !isset($data['category_id'])) {
                $category = \App\Models\Category::where('name', $data['category_name'])
                    ->where(function ($query) {
                        $query->where('is_system', true)
                              ->orWhere('user_id', $userId);
                    })
                    ->first();
                
                if ($category) {
                    $data['category_id'] = $category->id;
                }
            }

            // Si wallet_id est null, créer un wallet Divers par défaut
            if (!isset($data['wallet_id']) || $data['wallet_id'] === null) {
                $diversWallet = Wallet::where('user_id', $userId)
                    ->where('name', 'Divers')
                    ->first();

                if (!$diversWallet) {
                    // Créer le wallet Divers s'il n'existe pas
                    $diversWallet = Wallet::create([
                        'user_id' => $userId,
                        'name' => 'Divers',
                        'balance' => 0,
                        'currency' => 'XOF',
                        'type' => 'cash',
                    ]);
                }

                $data['wallet_id'] = $diversWallet->id;
            }

            // Si la transaction est non catégorisée (category_id null ou category = "Autre"), assigner au wallet Divers
            $categoryId = $data['category_id'] ?? null;
            $isUncategorized = false;

            if ($categoryId === null) {
                $isUncategorized = true;
            } elseif ($categoryId) {
                $category = \App\Models\Category::find($categoryId);
                if ($category && $category->name === 'Autre') {
                    $isUncategorized = true;
                }
            }

            if ($isUncategorized && $data['type'] === 'expense') {
                // Trouver le wallet Divers de l'utilisateur (unique)
                $diversWallet = Wallet::where('user_id', $userId)
                    ->where('name', 'Divers')
                    ->first();

                if (!$diversWallet) {
                    // Créer le wallet Divers s'il n'existe pas
                    $diversWallet = Wallet::create([
                        'user_id' => $userId,
                        'name' => 'Divers',
                        'balance' => 0,
                        'currency' => 'XOF',
                        'type' => 'cash',
                    ]);
                }

                $data['wallet_id'] = $diversWallet->id;
            } elseif (isset($data['wallet_id'])) {
                // S'assurer que le wallet utilisé correspond à la période de la transaction
                $wallet = Wallet::find($data['wallet_id']);
                if ($wallet) {
                    $transactionDate = \Carbon\Carbon::parse($data['transaction_date']);
                    
                    // Si le wallet n'a pas de période définie, la définir
                    if (!$wallet->period_start || !$wallet->period_end) {
                        $wallet->period_start = $transactionDate->startOfMonth();
                        $wallet->period_end = $transactionDate->endOfMonth();
                        $wallet->save();
                    }
                }
            }

            $transaction = Transaction::create($data);

            $this->updateWalletBalance($transaction);
            $this->updateBudgetSpent($transaction);

            $this->invalidateCache($userId);

            BudgetAlertJob::dispatch($transaction->id);

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

            // Revert old wallet avec lockForUpdate (PostgreSQL)
            if ($oldWalletId) {
                $oldWallet = Wallet::lockForUpdate()->find($oldWalletId);
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

            $this->invalidateCache($transaction->user_id);

            return $transaction;
        });
    }

    public function delete(Transaction $transaction): void
    {
        $userId = $transaction->user_id;

        DB::transaction(function () use ($transaction) {
            $this->revertWalletBalance($transaction);
            $this->revertBudgetSpent($transaction);
            $transaction->delete();
        });

        $this->invalidateCache($userId);
    }

    protected function updateWalletBalance(Transaction $transaction): void
    {
        // lockForUpdate pour éviter les race conditions (PostgreSQL)
        $wallet = Wallet::lockForUpdate()->find($transaction->wallet_id);
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
        $wallet = Wallet::lockForUpdate()->find($transaction->wallet_id);
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

    protected function invalidateCache(int $userId): void
    {
        Cache::forget("dashboard:{$userId}");
        Cache::forget("wallets:user:{$userId}");
    }
}
