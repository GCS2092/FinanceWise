<?php

namespace App\Jobs;

use App\Models\ParsedSms;
use App\Services\SmsParserService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ParseSmsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 30;

    public function __construct(
        protected int $smsId,
        protected array $data,
        protected int $userId,
    ) {}

    public function handle(SmsParserService $service): void
    {
        $sms = ParsedSms::find($this->smsId);
        if (!$sms) return;

        try {
            $service->processExistingSms($sms, $this->data, $this->userId);
        } catch (\Exception $e) {
            Log::error('ParseSmsJob failed', [
                'sms_id' => $this->smsId,
                'error' => $e->getMessage(),
            ]);
            throw $e;
        }
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('ParseSmsJob permanently failed', [
            'sms_id' => $this->smsId,
            'error' => $exception->getMessage(),
        ]);

        $sms = ParsedSms::find($this->smsId);
        if ($sms) {
            $sms->update([
                'status' => 'failed',
                'error_message' => 'Job failed after 3 attempts: ' . $exception->getMessage(),
            ]);
        }
    }
}
