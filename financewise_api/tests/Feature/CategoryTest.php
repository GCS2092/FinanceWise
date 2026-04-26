<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CategoryTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create();
        $this->actingAs($this->user, 'sanctum');
    }

    public function test_user_can_list_categories()
    {
        Category::factory()->create(['user_id' => $this->user->id]);
        
        $response = $this->getJson('/api/categories');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'name', 'type', 'is_system']
                ]
            ]);
    }

    public function test_user_can_create_category()
    {
        $data = [
            'name' => 'Test Category',
            'type' => 'expense',
        ];

        $response = $this->postJson('/api/categories', $data);

        $response->assertStatus(201)
            ->assertJsonFragment(['name' => 'Test Category']);
            
        $this->assertDatabaseHas('categories', [
            'name' => 'Test Category',
            'user_id' => $this->user->id,
            'is_system' => false,
        ]);
    }

    public function test_user_can_update_own_category()
    {
        $category = Category::factory()->create(['user_id' => $this->user->id, 'is_system' => false]);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => 'Updated Name',
            'type' => 'income',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('categories', [
            'id' => $category->id,
            'name' => 'Updated Name',
        ]);
    }

    public function test_user_cannot_update_system_category()
    {
        $category = Category::factory()->create(['is_system' => true]);

        $response = $this->putJson("/api/categories/{$category->id}", [
            'name' => 'Hacked Name',
        ]);

        $response->assertStatus(403);
    }

    public function test_user_cannot_delete_system_category()
    {
        $category = Category::factory()->create(['is_system' => true]);

        $response = $this->deleteJson("/api/categories/{$category->id}");

        $response->assertStatus(403);
    }

    public function test_user_cannot_delete_category_used_in_transactions()
    {
        $category = Category::factory()->create(['user_id' => $this->user->id]);
        
        // Create a transaction using this category
        $this->postJson('/api/transactions', [
            'category_id' => $category->id,
            'wallet_id' => \App\Models\Wallet::factory()->create(['user_id' => $this->user->id])->id,
            'type' => 'expense',
            'amount' => 1000,
            'description' => 'Test',
            'transaction_date' => now(),
        ]);

        $response = $this->deleteJson("/api/categories/{$category->id}");

        $response->assertStatus(409);
    }

    public function test_user_can_delete_own_unused_category()
    {
        $category = Category::factory()->create(['user_id' => $this->user->id, 'is_system' => false]);

        $response = $this->deleteJson("/api/categories/{$category->id}");

        $response->assertStatus(200);
        $this->assertDatabaseMissing('categories', ['id' => $category->id]);
    }
}
