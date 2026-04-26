<?php

namespace Tests\Feature;

use App\Models\Budget;
use App\Models\Category;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BudgetTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create();
        $this->actingAs($this->user, 'sanctum');
        $this->category = Category::factory()->create(['user_id' => $this->user->id, 'type' => 'expense']);
        $this->wallet = Wallet::factory()->create(['user_id' => $this->user->id]);
    }

    public function test_user_can_list_budgets()
    {
        Budget::factory()->create([
            'user_id' => $this->user->id,
            'category_id' => $this->category->id,
        ]);

        $response = $this->getJson('/api/budgets');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'amount', 'spent', 'period', 'start_date', 'end_date']
                ]
            ]);
    }

    public function test_user_can_create_budget()
    {
        $data = [
            'category_id' => $this->category->id,
            'amount' => 100000,
            'period' => 'monthly',
            'start_date' => now()->format('Y-m-d'),
            'end_date' => now()->addMonth()->format('Y-m-d'),
        ];

        $response = $this->postJson('/api/budgets', $data);

        $response->assertStatus(201)
            ->assertJsonFragment(['amount' => 100000, 'spent' => 0]);

        $this->assertDatabaseHas('budgets', [
            'user_id' => $this->user->id,
            'category_id' => $this->category->id,
            'amount' => 100000,
        ]);
    }

    public function test_user_can_update_own_budget()
    {
        $budget = Budget::factory()->create([
            'user_id' => $this->user->id,
            'category_id' => $this->category->id,
        ]);

        $response = $this->putJson("/api/budgets/{$budget->id}", [
            'amount' => 150000,
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('budgets', [
            'id' => $budget->id,
            'amount' => 150000,
        ]);
    }

    public function test_user_can_delete_own_budget()
    {
        $budget = Budget::factory()->create([
            'user_id' => $this->user->id,
            'category_id' => $this->category->id,
        ]);

        $response = $this->deleteJson("/api/budgets/{$budget->id}");

        $response->assertStatus(200);
        $this->assertDatabaseMissing('budgets', ['id' => $budget->id]);
    }

    public function test_user_cannot_create_budget_for_income_category()
    {
        $incomeCategory = Category::factory()->create(['user_id' => $this->user->id, 'type' => 'income']);

        $response = $this->postJson('/api/budgets', [
            'category_id' => $incomeCategory->id,
            'amount' => 100000,
            'period' => 'monthly',
            'start_date' => now()->format('Y-m-d'),
            'end_date' => now()->addMonth()->format('Y-m-d'),
        ]);

        $response->assertStatus(422);
    }

    public function test_user_cannot_access_another_users_budget()
    {
        $otherUser = User::factory()->create();
        $budget = Budget::factory()->create(['user_id' => $otherUser->id]);

        $response = $this->getJson("/api/budgets/{$budget->id}");

        $response->assertStatus(403);
    }
}
