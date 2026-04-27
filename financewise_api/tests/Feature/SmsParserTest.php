<?php

namespace Tests\Feature;

use App\Jobs\ParseSmsJob;
use App\Models\Category;
use App\Models\ParsedSms;
use App\Models\User;
use App\Models\Wallet;
use App\Services\SmsParserService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class SmsParserTest extends TestCase
{
    use RefreshDatabase;

    protected User $user;
    protected Wallet $wallet;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create();
        $this->actingAs($this->user, 'sanctum');
        $this->wallet = Wallet::factory()->create(['user_id' => $this->user->id]);
        Category::factory()->create(['name' => 'nourriture', 'type' => 'expense', 'is_system' => true]);
    }

    public function test_sms_parse_returns_202_and_dispatches_job()
    {
        Queue::fake();

        $response = $this->postJson('/api/sms/parse', [
            'provider' => 'wave',
            'raw_content' => 'Vous avez reçu 50000 FCFA de Jean Dupont le 25/04/2026 14:30',
        ]);

        $response->assertStatus(202)
            ->assertJsonStructure(['message', 'sms' => ['id', 'status']])
            ->assertJsonPath('sms.status', 'pending');

        $this->assertDatabaseHas('parsed_sms', [
            'user_id' => $this->user->id,
            'provider' => 'wave',
            'status' => 'pending',
        ]);

        Queue::assertPushed(ParseSmsJob::class);
    }

    public function test_sms_batch_returns_202_and_dispatches_multiple_jobs()
    {
        Queue::fake();

        $messages = [
            ['provider' => 'wave', 'raw_content' => 'Vous avez reçu 10000 FCFA'],
            ['provider' => 'orange_money', 'raw_content' => 'Paiement effectué: 5000 FCFA'],
        ];

        $response = $this->postJson('/api/sms/batch', ['messages' => $messages]);

        $response->assertStatus(202)
            ->assertJsonCount(2, 'results');

        $this->assertDatabaseCount('parsed_sms', 2);
        Queue::assertPushed(ParseSmsJob::class, 2);
    }

    public function test_sms_service_processes_wave_income()
    {
        $service = app(SmsParserService::class);

        $sms = $service->parse([
            'provider' => 'wave',
            'raw_content' => 'Vous avez reçu 50000 FCFA de Jean Dupont le 25/04/2026 14:30',
        ], $this->user->id);

        $this->assertEquals('processed', $sms->status);

        $this->assertDatabaseHas('transactions', [
            'user_id' => $this->user->id,
            'type' => 'income',
            'amount' => 50000,
            'source' => 'sms_wave',
        ]);
    }

    public function test_sms_service_processes_orange_money_expense()
    {
        $service = app(SmsParserService::class);

        $sms = $service->parse([
            'provider' => 'orange_money',
            'raw_content' => 'Transfert effectué: 25000 FCFA à Marie le 25/04/2026 10:15',
        ], $this->user->id);

        $this->assertEquals('processed', $sms->status);

        $this->assertDatabaseHas('transactions', [
            'user_id' => $this->user->id,
            'type' => 'expense',
            'amount' => 25000,
            'source' => 'sms_orange_money',
        ]);
    }

    public function test_unparseable_sms_is_stored_as_failed()
    {
        $service = app(SmsParserService::class);

        $sms = $service->parse([
            'provider' => 'wave',
            'raw_content' => 'Random text without amount',
        ], $this->user->id);

        $this->assertEquals('failed', $sms->status);

        $this->assertDatabaseHas('parsed_sms', [
            'user_id' => $this->user->id,
            'status' => 'failed',
        ]);
    }

    public function test_parser_detects_category_from_keywords()
    {
        $service = app(SmsParserService::class);

        $sms = $service->parse([
            'provider' => 'wave',
            'raw_content' => 'Paiement restaurant nourriture: 5000 FCFA',
        ], $this->user->id);

        $transaction = \App\Models\Transaction::where('user_id', $this->user->id)->first();
        $this->assertNotNull($transaction);
        $this->assertNotNull($transaction->category_id);
        $category = Category::find($transaction->category_id);
        $this->assertEquals('nourriture', $category->name);
    }
}
