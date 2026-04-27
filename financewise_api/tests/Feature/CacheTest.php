<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CacheTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_is_cached_on_second_call(): void
    {
        $user = User::factory()->create();
        Wallet::factory()->create(['user_id' => $user->id]);
        Sanctum::actingAs($user, ['*']);

        $cacheKey = "dashboard:{$user->id}";

        $this->assertFalse(Cache::has($cacheKey));

        $response1 = $this->getJson('/api/dashboard');
        $response1->assertStatus(200);

        $this->assertTrue(Cache::has($cacheKey));

        $response2 = $this->getJson('/api/dashboard');
        $response2->assertStatus(200);

        $this->assertEquals(
            $response1->json('balance'),
            $response2->json('balance')
        );
    }

    public function test_dashboard_cache_invalidated_after_transaction(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create(['user_id' => $user->id, 'balance' => 100000]);
        $category = Category::factory()->create(['user_id' => $user->id]);
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/dashboard')->assertStatus(200);

        $cacheKey = "dashboard:{$user->id}";
        $this->assertTrue(Cache::has($cacheKey));

        $this->postJson('/api/transactions', [
            'wallet_id' => $wallet->id,
            'category_id' => $category->id,
            'type' => 'expense',
            'amount' => 5000,
            'description' => 'Test',
            'transaction_date' => now()->toDateTimeString(),
        ])->assertStatus(201);

        $this->assertFalse(Cache::has($cacheKey));
    }

    public function test_categories_are_cached(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user, ['*']);

        $cacheKey = "categories:user:{$user->id}";

        $this->assertFalse(Cache::has($cacheKey));

        $this->getJson('/api/categories')->assertStatus(200);

        $this->assertTrue(Cache::has($cacheKey));
    }

    public function test_categories_cache_invalidated_on_create(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/categories')->assertStatus(200);

        $cacheKey = "categories:user:{$user->id}";
        $this->assertTrue(Cache::has($cacheKey));

        $this->postJson('/api/categories', [
            'name' => 'Nouvelle',
            'type' => 'expense',
        ])->assertStatus(201);

        $this->assertFalse(Cache::has($cacheKey));
    }

    public function test_wallets_are_cached(): void
    {
        $user = User::factory()->create();
        Wallet::factory()->create(['user_id' => $user->id]);
        Sanctum::actingAs($user, ['*']);

        $cacheKey = "wallets:user:{$user->id}";

        $this->assertFalse(Cache::has($cacheKey));

        $this->getJson('/api/wallets')->assertStatus(200);

        $this->assertTrue(Cache::has($cacheKey));
    }

    public function test_wallets_cache_invalidated_after_transaction(): void
    {
        $user = User::factory()->create();
        $wallet = Wallet::factory()->create(['user_id' => $user->id, 'balance' => 100000]);
        $category = Category::factory()->create(['user_id' => $user->id]);
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/wallets')->assertStatus(200);

        $cacheKey = "wallets:user:{$user->id}";
        $this->assertTrue(Cache::has($cacheKey));

        $this->postJson('/api/transactions', [
            'wallet_id' => $wallet->id,
            'category_id' => $category->id,
            'type' => 'expense',
            'amount' => 1000,
            'description' => 'Test',
            'transaction_date' => now()->toDateTimeString(),
        ])->assertStatus(201);

        $this->assertFalse(Cache::has($cacheKey));
    }
}
