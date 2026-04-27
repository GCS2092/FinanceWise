<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use App\Models\Wallet;
use App\Services\TransactionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WalletLockTest extends TestCase
{
    use RefreshDatabase;

    public function test_concurrent_transactions_maintain_correct_balance(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create([
            'user_id' => $user->id,
            'balance' => 100000,
        ]);
        $category = Category::factory()->create(['user_id' => $user->id]);

        $service = app(TransactionService::class);

        $service->create([
            'wallet_id' => $wallet->id,
            'category_id' => $category->id,
            'type' => 'expense',
            'amount' => 30000,
            'description' => 'Transaction 1',
            'transaction_date' => now()->toDateTimeString(),
        ], $user->id);

        $service->create([
            'wallet_id' => $wallet->id,
            'category_id' => $category->id,
            'type' => 'expense',
            'amount' => 20000,
            'description' => 'Transaction 2',
            'transaction_date' => now()->toDateTimeString(),
        ], $user->id);

        $service->create([
            'wallet_id' => $wallet->id,
            'type' => 'income',
            'amount' => 10000,
            'description' => 'Transaction 3',
            'transaction_date' => now()->toDateTimeString(),
        ], $user->id);

        $wallet->refresh();
        // 100000 - 30000 - 20000 + 10000 = 60000
        $this->assertEquals(60000, $wallet->balance);
    }

    public function test_update_transaction_reverts_and_applies_new_balance(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create([
            'user_id' => $user->id,
            'balance' => 100000,
        ]);

        $service = app(TransactionService::class);

        $transaction = $service->create([
            'wallet_id' => $wallet->id,
            'type' => 'expense',
            'amount' => 30000,
            'description' => 'Original',
            'transaction_date' => now()->toDateTimeString(),
        ], $user->id);

        $wallet->refresh();
        $this->assertEquals(70000, $wallet->balance);

        $service->update($transaction, ['amount' => 10000]);

        $wallet->refresh();
        $this->assertEquals(90000, $wallet->balance);
    }

    public function test_delete_transaction_restores_balance(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create([
            'user_id' => $user->id,
            'balance' => 100000,
        ]);

        $service = app(TransactionService::class);

        $transaction = $service->create([
            'wallet_id' => $wallet->id,
            'type' => 'expense',
            'amount' => 25000,
            'description' => 'To delete',
            'transaction_date' => now()->toDateTimeString(),
        ], $user->id);

        $wallet->refresh();
        $this->assertEquals(75000, $wallet->balance);

        $service->delete($transaction);

        $wallet->refresh();
        $this->assertEquals(100000, $wallet->balance);
    }
}
