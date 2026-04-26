<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SmsParserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SmsParserController extends Controller
{
    public function __construct(protected SmsParserService $service)
    {
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'provider' => ['required', 'in:wave,orange_money'],
            'raw_content' => ['required', 'string'],
        ]);

        $sms = $this->service->parse($validated, auth()->id());

        return response()->json([
            'message' => $sms->status === 'processed' ? 'SMS traité et transaction créée' : 'SMS enregistré mais non traité',
            'sms' => $sms,
        ]);
    }

    public function batch(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'messages' => ['required', 'array'],
            'messages.*.provider' => ['required', 'in:wave,orange_money'],
            'messages.*.raw_content' => ['required', 'string'],
        ]);

        $results = [];
        foreach ($validated['messages'] as $message) {
            $results[] = $this->service->parse($message, auth()->id());
        }

        return response()->json([
            'message' => count($results) . ' SMS traités',
            'results' => $results,
        ]);
    }
}
