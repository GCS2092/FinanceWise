<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\ParseSmsJob;
use App\Models\ParsedSms;
use App\Services\SmsParserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SmsParserController extends Controller
{
    public function __construct(protected SmsParserService $service)
    {
    }

    public function show(ParsedSms $parsedSms): JsonResponse
    {
        if ($parsedSms->user_id !== auth()->id()) {
            return response()->json(['message' => 'Non autorisé'], 403);
        }

        return response()->json([
            'data' => [
                'id' => $parsedSms->id,
                'status' => $parsedSms->status,
                'error_message' => $parsedSms->error_message,
                'parsed_amount' => $parsedSms->parsed_amount,
                'parsed_type' => $parsedSms->parsed_type,
                'transaction_id' => $parsedSms->transaction_id,
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'provider' => ['required', 'in:wave,orange_money'],
            'raw_content' => ['required', 'string'],
        ]);

        $userId = auth()->id();
        $sms = $this->service->createPending($validated, $userId);

        ParseSmsJob::dispatch($sms->id, $validated, $userId);

        return response()->json([
            'message' => 'SMS reçu et en cours de traitement',
            'sms' => [
                'id' => $sms->id,
                'status' => 'pending',
            ],
        ], 202);
    }

    public function batch(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'messages' => ['required', 'array'],
            'messages.*.provider' => ['required', 'in:wave,orange_money'],
            'messages.*.raw_content' => ['required', 'string'],
        ]);

        $userId = auth()->id();
        $results = [];

        foreach ($validated['messages'] as $message) {
            $sms = $this->service->createPending($message, $userId);
            ParseSmsJob::dispatch($sms->id, $message, $userId);
            $results[] = [
                'id' => $sms->id,
                'status' => 'pending',
            ];
        }

        return response()->json([
            'message' => count($results) . ' SMS en cours de traitement',
            'results' => $results,
        ], 202);
    }
}
