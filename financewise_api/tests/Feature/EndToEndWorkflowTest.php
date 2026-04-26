<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EndToEndWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_api_workflow(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create(['user_id' => $user->id, 'balance' => 0]);
        Sanctum::actingAs($user, ['*']);

        // 1. Get authenticated user
        $this->getJson('/api/user')
            ->assertStatus(200)
            ->assertJsonPath('email', $user->email);

        // 2. Create category
        $categoryResponse = $this->postJson('/api/categories', [
            'name' => 'Alimentation',
            'type' => 'expense',
            'icon' => 'food',
            'color' => '#ff0000',
        ]);
        $categoryResponse->assertStatus(201)
            ->assertJsonPath('data.name', 'Alimentation');
        $categoryId = $categoryResponse->json('data.id');

        // 3. List categories (system + user)
        $this->getJson('/api/categories')
            ->assertStatus(200);

        // 4. Default wallet exists
        $walletsResponse = $this->getJson('/api/wallets');
        $walletsResponse->assertStatus(200);
        $walletId = $walletsResponse->json('data')[0]['id'];

        // 5. Create expense transaction
        $transactionResponse = $this->postJson('/api/transactions', [
            'wallet_id' => $walletId,
            'category_id' => $categoryId,
            'type' => 'expense',
            'amount' => 5000,
            'description' => 'Courses',
            'transaction_date' => now()->toDateString(),
            'source' => 'manual',
        ]);
        $transactionResponse->assertStatus(201)
            ->assertJsonPath('data.amount', 5000)
            ->assertJsonPath('data.type', 'expense');
        $transactionId = $transactionResponse->json('data.id');

        // 6. Wallet balance should be -5000
        $this->getJson('/api/wallets/' . $walletId)
            ->assertStatus(200)
            ->assertJsonPath('data.balance', -5000);

        // 7. List transactions
        $this->getJson('/api/transactions')
            ->assertStatus(200)
            ->assertJsonCount(1, 'data');

        // 8. Update transaction amount 5000 -> 3000
        $this->putJson('/api/transactions/' . $transactionId, [
            'amount' => 3000,
        ])->assertStatus(200)
          ->assertJsonPath('data.amount', 3000);

        // 9. Wallet balance should be -3000
        $this->getJson('/api/wallets/' . $walletId)
            ->assertStatus(200)
            ->assertJsonPath('data.balance', -3000);

        // 10. Create income transaction
        $this->postJson('/api/transactions', [
            'wallet_id' => $walletId,
            'type' => 'income',
            'amount' => 10000,
            'description' => 'Salaire',
            'transaction_date' => now()->toDateString(),
        ])->assertStatus(201)
          ->assertJsonPath('data.type', 'income');

        // 11. Wallet balance: -3000 + 10000 = 7000
        $this->getJson('/api/wallets/' . $walletId)
            ->assertStatus(200)
            ->assertJsonPath('data.balance', 7000);

        // 12. Create budget
        $budgetResponse = $this->postJson('/api/budgets', [
            'category_id' => $categoryId,
            'amount' => 20000,
            'period' => 'monthly',
            'start_date' => now()->startOfMonth()->toDateString(),
            'end_date' => now()->endOfMonth()->toDateString(),
            'is_active' => true,
        ]);
        $budgetResponse->assertStatus(201)
            ->assertJsonPath('data.amount', 20000)
            ->assertJsonPath('data.spent', 0);
        $budgetId = $budgetResponse->json('data.id');

        // 13. Show budget (recalculated spent = 3000)
        $this->getJson('/api/budgets/' . $budgetId)
            ->assertStatus(200)
            ->assertJsonPath('data.spent', 3000)
            ->assertJsonPath('data.remaining', 17000)
            ->assertJsonPath('data.percentage', 15);

        // 14. Dashboard
        $this->getJson('/api/dashboard')
            ->assertStatus(200)
            ->assertJsonStructure([
                'balance',
                'monthly_income',
                'monthly_expense',
                'top_categories',
                'recent_transactions',
                'budgets',
                'alerts',
            ]);

        // 15. Delete transaction
        $this->deleteJson('/api/transactions/' . $transactionId)
            ->assertStatus(200)
            ->assertJsonPath('message', 'Transaction supprimée');

        // 16. Wallet balance restored: 7000 - (-3000) = 10000
        $this->getJson('/api/wallets/' . $walletId)
            ->assertStatus(200)
            ->assertJsonPath('data.balance', 10000);

        // 17. Logout
        $this->postJson('/api/logout')
            ->assertStatus(200)
            ->assertJsonPath('message', 'Déconnecté');
    }

    public function test_unauthorized_access_is_blocked(): void
    {
        $this->getJson('/api/user')->assertStatus(401);
        $this->getJson('/api/wallets')->assertStatus(401);
        $this->getJson('/api/transactions')->assertStatus(401);
        $this->getJson('/api/budgets')->assertStatus(401);
        $this->getJson('/api/dashboard')->assertStatus(401);
        $this->getJson('/api/categories')->assertStatus(401);
    }

    public function test_cannot_access_other_user_resources(): void
    {
        $userA = User::factory()->create();
        $walletA = Wallet::factory()->create(['user_id' => $userA->id]);

        $userB = User::factory()->create();
        Sanctum::actingAs($userB, ['*']);

        $this->getJson('/api/wallets/' . $walletA->id)
            ->assertStatus(403);

        $this->postJson('/api/transactions', [
            'wallet_id' => $walletA->id,
            'type' => 'expense',
            'amount' => 100,
            'transaction_date' => now()->toDateString(),
        ])->assertStatus(422);
    }
}
