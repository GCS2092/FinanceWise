<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RateLimitingTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_rate_limit_returns_429_after_5_attempts(): void
    {
        $payload = [
            'email' => 'nonexistent@test.com',
            'password' => 'wrongpassword',
        ];

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/login', $payload)->assertStatus(401);
        }

        $response = $this->postJson('/api/login', $payload);
        $response->assertStatus(429)
            ->assertJsonPath('message', 'Trop de tentatives de connexion. Réessayez dans 1 minute.');
    }

    public function test_register_rate_limit_returns_429_after_3_attempts(): void
    {
        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/register', [
                'name' => "User $i",
                'email' => "user{$i}@test.com",
                'password' => 'password123',
            ])->assertStatus(201);
        }

        $response = $this->postJson('/api/register', [
            'name' => 'User Extra',
            'email' => 'extra@test.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(429);
    }

    public function test_api_rate_limit_returns_429_after_60_requests(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'sanctum');

        for ($i = 0; $i < 60; $i++) {
            $this->getJson('/api/user')->assertStatus(200);
        }

        $response = $this->getJson('/api/user');
        $response->assertStatus(429);
    }
}
