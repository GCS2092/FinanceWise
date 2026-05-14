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

    public function createPending(array $data, int $userId): ParsedSms
    {
        return ParsedSms::create([
            'user_id' => $userId,
            'provider' => $data['provider'],
            'raw_content' => $data['raw_content'],
            'status' => 'pending',
        ]);
    }

    public function processExistingSms(ParsedSms $sms, array $data, int $userId): ParsedSms
    {
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

                try {
                    $wallet = \App\Models\Wallet::where('user_id', $userId)->firstOrFail();
                } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
                    $sms->update(['status' => 'failed', 'error_message' => 'Aucun wallet trouvé pour cet utilisateur']);
                    Log::warning('SMS parse failed: no wallet for user', ['user_id' => $userId, 'sms_id' => $sms->id]);
                    return $sms->refresh();
                }

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
                $sms->update(['status' => 'failed', 'error_message' => 'Impossible de parser le SMS']);
            }
        } catch (\Exception $e) {
            $sms->update(['status' => 'failed', 'error_message' => $e->getMessage()]);
            Log::error('SMS parse error', ['error' => $e->getMessage(), 'sms_id' => $sms->id]);
        }

        return $sms->refresh();
    }

    public function parse(array $data, int $userId): ParsedSms
    {
        $sms = $this->createPending($data, $userId);
        return $this->processExistingSms($sms, $data, $userId);
    }

    protected function extractData(string $content, string $provider): array
    {
        $content = strtolower($content);
        $result = [];

        // Détection du type - patterns plus larges
        if ($provider === 'wave') {
            if (str_contains($content, 'retrait') || str_contains($content, 'paiement') || str_contains($content, 'transfert envoye') || str_contains($content, 'transfert envoyé') || str_contains($content, 'achat') || str_contains($content, 'paye') || str_contains($content, 'payé') || str_contains($content, 'dépense') || str_contains($content, 'depense')) {
                $result['type'] = 'expense';
            } elseif (str_contains($content, 'depot') || str_contains($content, 'dépôt') || str_contains($content, 'transfert recu') || str_contains($content, 'transfert reçu') || str_contains($content, 'vous avez recu') || str_contains($content, 'vous avez reçu') || str_contains($content, 'reception') || str_contains($content, 'crédité') || str_contains($content, 'credite')) {
                $result['type'] = 'income';
            }
        } elseif ($provider === 'orange_money') {
            if (str_contains($content, 'retrait') || str_contains($content, 'paiement') || str_contains($content, 'transfert effectue') || str_contains($content, 'transfert effectué') || str_contains($content, 'achat') || str_contains($content, 'paye') || str_contains($content, 'payé') || str_contains($content, 'dépense') || str_contains($content, 'depense')) {
                $result['type'] = 'expense';
            } elseif (str_contains($content, 'depot') || str_contains($content, 'dépôt') || str_contains($content, 'transfert recu') || str_contains($content, 'transfert reçu') || str_contains($content, 'vous avez recu') || str_contains($content, 'vous avez reçu') || str_contains($content, 'reception') || str_contains($content, 'crédité') || str_contains($content, 'credite')) {
                $result['type'] = 'income';
            }
        }

        // Détection du montant - patterns plus flexibles
        // Format: "12 500 FCFA", "12500 FCFA", "12,500 FCFA", etc.
        if (preg_match('/(\d{1,3}(?:[,\s]\d{3})*)\s*fcfa/i', $content, $matches)) {
            $amount = str_replace([',', ' '], '', $matches[1]);
            $result['amount'] = (float) $amount;
        } elseif (preg_match('/(\d+(?:\.\d{1,2})?)\s*fcfa/i', $content, $matches)) {
            $result['amount'] = (float) $matches[1];
        } elseif (preg_match('/(\d{1,3}(?:[,\s]\d{3})*)\s*f/i', $content, $matches)) {
            $amount = str_replace([',', ' '], '', $matches[1]);
            $result['amount'] = (float) $amount;
        } elseif (preg_match('/(\d+(?:\.\d{1,2})?)\s*f/i', $content, $matches)) {
            $result['amount'] = (float) $matches[1];
        }

        // Détection de la date - patterns plus larges
        if (preg_match('/(\d{2}\/\d{2}\/\d{4}\s+\d{2}:\d{2})/', $content, $dateMatch)) {
            $result['date'] = \DateTime::createFromFormat('d/m/Y H:i', $dateMatch[1]) ?: now();
        } elseif (preg_match('/(\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2})/', $content, $dateMatch)) {
            $result['date'] = \DateTime::createFromFormat('d-m-Y H:i', $dateMatch[1]) ?: now();
        } elseif (preg_match('/(\d{4}\/\d{2}\/\d{2}\s+\d{2}:\d{2})/', $content, $dateMatch)) {
            $result['date'] = \DateTime::createFromFormat('Y/m/d H:i', $dateMatch[1]) ?: now();
        }

        $result['description'] = 'Auto: ' . substr($content, 0, 100);

        Log::info('SMS parsed', [
            'provider' => $provider,
            'content' => substr($content, 0, 200),
            'result' => $result,
        ]);

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
