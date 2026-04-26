<?php

namespace App\Services;

use App\Models\Category;
use App\Models\ParsedSms;
use Illuminate\Support\Facades\Log;

class SmsParserService
{
    public function __construct(protected TransactionService $transactionService)
    {
    }

    public function parse(array $data, int $userId): ParsedSms
    {
        $sms = ParsedSms::create([
            'user_id' => $userId,
            'provider' => $data['provider'],
            'raw_content' => $data['raw_content'],
            'status' => 'pending',
        ]);

        try {
            $parsed = $this->extractData($data['raw_content'], $data['provider']);

            $sms->update([
                'parsed_amount' => $parsed['amount'] ?? null,
                'parsed_phone' => $parsed['phone'] ?? null,
                'parsed_type' => $parsed['type'] ?? null,
                'parsed_at' => now(),
            ]);

            if (!empty($parsed['amount']) && !empty($parsed['type'])) {
                $category = $this->detectCategory($parsed, $userId);
                $wallet = \App\Models\Wallet::where('user_id', $userId)->first();

                $transaction = $this->transactionService->create([
                    'category_id' => $category?->id,
                    'wallet_id' => $wallet?->id,
                    'type' => $parsed['type'],
                    'amount' => $parsed['amount'],
                    'description' => $parsed['description'] ?? 'Transaction auto',
                    'transaction_date' => $parsed['date'] ?? now(),
                    'source' => $data['provider'] === 'wave' ? 'sms_wave' : 'sms_orange_money',
                    'status' => 'completed',
                ], $userId);

                $sms->update(['transaction_id' => $transaction->id, 'status' => 'processed']);
            } else {
                $sms->update(['status' => 'failed', 'error_message' => 'Unable to parse SMS']);
            }
        } catch (\Exception $e) {
            $sms->update(['status' => 'failed', 'error_message' => $e->getMessage()]);
            Log::error('SMS parse error', ['error' => $e->getMessage(), 'sms' => $data['raw_content']]);
        }

        return $sms;
    }

    protected function extractData(string $content, string $provider): array
    {
        $content = strtolower($content);
        $result = [];

        if ($provider === 'wave') {
            if (str_contains($content, 'retrait') || str_contains($content, 'paiement') || str_contains($content, 'transfert envoye')) {
                $result['type'] = 'expense';
            } elseif (str_contains($content, 'depot') || str_contains($content, 'transfert recu')) {
                $result['type'] = 'income';
            }
        } elseif ($provider === 'orange_money') {
            if (str_contains($content, 'retrait') || str_contains($content, 'paiement') || str_contains($content, 'transfert effectue')) {
                $result['type'] = 'expense';
            } elseif (str_contains($content, 'depot') || str_contains($content, 'transfert recu')) {
                $result['type'] = 'income';
            }
        }

        if (preg_match('/(\d{1,3}(?:\s?\d{3})*)\s*fcfa/i', $content, $matches)) {
            $amount = str_replace(' ', '', $matches[1]);
            $result['amount'] = (float) $amount;
        } elseif (preg_match('/(\d+(?:\.\d{1,2})?)\s*fcfa/i', $content, $matches)) {
            $result['amount'] = (float) $matches[1];
        }

        if (preg_match('/(\d{2}\/\d{2}\/\d{4}\s+\d{2}:\d{2})/', $content, $dateMatch)) {
            $result['date'] = \DateTime::createFromFormat('d/m/Y H:i', $dateMatch[1]) ?: now();
        }

        $result['description'] = 'Auto: ' . substr($content, 0, 100);

        return $result;
    }

    protected function detectCategory(array $parsed, int $userId): ?Category
    {
        $desc = strtolower($parsed['description'] ?? '');

        $mapping = [
            'nourriture' => ['nourriture', 'food', 'restaurant', 'alimentation'],
            'transport' => ['transport', 'taxi', 'yango', 'car rapide'],
            'internet / data' => ['internet', 'data', 'pass'],
            'mobile money' => ['transfert', 'wave', 'orange money', 'depot'],
            'école / université' => ['ecole', 'universite', 'scolarite', 'cours'],
            'santé' => ['sante', 'hopital', 'pharmacie', 'medicament'],
        ];

        foreach ($mapping as $name => $keywords) {
            foreach ($keywords as $keyword) {
                if (str_contains($desc, $keyword)) {
                    return Category::where('name', $name)
                        ->where(function ($q) use ($userId) {
                            $q->where('is_system', true)->orWhere('user_id', $userId);
                        })
                        ->first();
                }
            }
        }

        return Category::where('name', 'Dépenses personnelles')
            ->where(function ($q) use ($userId) {
                $q->where('is_system', true)->orWhere('user_id', $userId);
            })
            ->first();
    }
}
