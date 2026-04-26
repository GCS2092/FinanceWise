<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TransactionTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_list_transactions(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create(['user_id' => $user->id]);
        $category = Category::factory()->create(['user_id' => $user->id]);
        Transaction::factory()->count(5)->create([
            'user_id' => $user->id,
            'wallet_id' => $wallet->id,
            'category_id' => $category->id,
        ]);

        $token = $user->createToken('test')->plainTextToken;
        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->getJson('/api/transactions');

        $response->assertStatus(200)
            ->assertJsonCount(5, 'data');
    }

    public function test_can_create_transaction(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create(['user_id' => $user->id, 'balance' => 100000]);
        $category = Category::factory()->create(['user_id' => $user->id]);

        $token = $user->createToken('test')->plainTextToken;
        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/transactions', [
                'wallet_id' => $wallet->id,
                'category_id' => $category->id,
                'type' => 'expense',
                'amount' => 5000,
                'description' => 'Test transaction',
                'transaction_date' => now()->toDateTimeString(),
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.amount', 5000);

        $this->assertDatabaseHas('transactions', [
            'amount' => 5000,
            'description' => 'Test transaction',
        ]);
    }
}
