<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WalletAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_cannot_access_another_users_wallet(): void
    {
        $userA = User::factory()->create();
        $walletA = Wallet::factory()->create(['user_id' => $userA->id]);
        $tokenA = $userA->createToken('test')->plainTextToken;

        $userB = User::factory()->create();
        $tokenB = $userB->createToken('test')->plainTextToken;

        // User B tries to access User A wallet
        $response = $this->withHeader('Authorization', 'Bearer ' . $tokenB)
            ->getJson('/api/wallets/' . $walletA->id);

        $response->assertStatus(403);
    }
}
