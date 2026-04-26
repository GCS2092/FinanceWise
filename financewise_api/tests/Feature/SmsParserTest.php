<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\ParsedSms;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SmsParserTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create();
        $this->actingAs($this->user, 'sanctum');
        $this->wallet = Wallet::factory()->create(['user_id' => $this->user->id]);
        Category::factory()->create(['name' => 'nourriture', 'type' => 'expense', 'is_system' => true]);
    }

    public function test_user_can_parse_wave_sms()
    {
        $smsContent = 'Vous avez reçu 50000 FCFA de Jean Dupont le 25/04/2026 14:30';

        $response = $this->postJson('/api/sms/parse', [
            'provider' => 'wave',
            'raw_content' => $smsContent,
        ]);

        $response->assertStatus(200)
            ->assertJsonFragment(['status' => 'processed']);

        $this->assertDatabaseHas('parsed_sms', [
            'user_id' => $this->user->id,
            'provider' => 'wave',
            'status' => 'processed',
        ]);

        $this->assertDatabaseHas('transactions', [
            'user_id' => $this->user->id,
            'type' => 'income',
            'amount' => 50000,
            'source' => 'sms_wave',
        ]);
    }

    public function test_user_can_parse_orange_money_sms()
    {
        $smsContent = 'Transfert effectué: 25000 FCFA à Marie le 25/04/2026 10:15';

        $response = $this->postJson('/api/sms/parse', [
            'provider' => 'orange_money',
            'raw_content' => $smsContent,
        ]);

        $response->assertStatus(200);

        $this->assertDatabaseHas('transactions', [
            'user_id' => $this->user->id,
            'type' => 'expense',
            'amount' => 25000,
            'source' => 'sms_orange_money',
        ]);
    }

    public function test_user_can_parse_batch_sms()
    {
        $messages = [
            ['provider' => 'wave', 'raw_content' => 'Vous avez reçu 10000 FCFA'],
            ['provider' => 'orange_money', 'raw_content' => 'Paiement effectué: 5000 FCFA'],
        ];

        $response = $this->postJson('/api/sms/batch', ['messages' => $messages]);

        $response->assertStatus(200)
            ->assertJsonFragment(['message' => '2 SMS traités']);

        $this->assertDatabaseCount('parsed_sms', 2);
    }

    public function test_unparseable_sms_is_stored_as_failed()
    {
        $invalidSms = 'Random text without amount';

        $response = $this->postJson('/api/sms/parse', [
            'provider' => 'wave',
            'raw_content' => $invalidSms,
        ]);

        $response->assertStatus(200);

        $this->assertDatabaseHas('parsed_sms', [
            'user_id' => $this->user->id,
            'status' => 'failed',
        ]);
    }

    public function test_parser_detects_category_from_keywords()
    {
        $smsContent = 'Paiement restaurant nourriture: 5000 FCFA';

        $response = $this->postJson('/api/sms/parse', [
            'provider' => 'wave',
            'raw_content' => $smsContent,
        ]);

        $response->assertStatus(200);

        $transaction = \App\Models\Transaction::where('user_id', $this->user->id)->first();
        $this->assertNotNull($transaction->category_id);
        $category = Category::find($transaction->category_id);
        $this->assertEquals('nourriture', $category->name);
    }
}
