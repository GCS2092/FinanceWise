<?php

namespace App\Http\Controllers;

use App\Models\Transaction;
use App\Models\Category;
use App\Models\Wallet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AutoTransactionController extends Controller
{
    /**
     * Recevoir un SMS parsé depuis l'application mobile
     */
    public function receiveSms(Request $request)
    {
        $validated = $request->validate([
            'sender' => 'required|string',
            'body' => 'required|string',
            'provider' => 'required|string',
            'amount' => 'required|numeric',
            'type' => 'required|in:income,expense',
            'category' => 'nullable|string',
            'description' => 'nullable|string',
        ]);

        // Catégorisation intelligente basée sur l'historique
        $category = $this->smartCategorize($validated['body'], $validated['category'] ?? null);

        // Récupérer le wallet par défaut
        $wallet = Wallet::where('user_id', Auth::id())->first();
        if (!$wallet) {
            return response()->json(['error' => 'Aucun wallet disponible'], 404);
        }

        // Récupérer ou créer la catégorie
        $categoryModel = Category::where('name', $category)->first();
        if (!$categoryModel) {
            $categoryModel = Category::create([
                'name' => $category,
                'type' => $validated['type'],
                'user_id' => Auth::id(),
                'is_system' => false,
            ]);
        }

        // Créer la transaction
        $transaction = Transaction::create([
            'wallet_id' => $wallet->id,
            'category_id' => $categoryModel->id,
            'type' => $validated['type'],
            'amount' => $validated['amount'],
            'description' => $validated['description'] ?? "Transaction {$validated['provider']}",
            'transaction_date' => now()->toDateString(),
            'source' => "auto_{$validated['provider']}",
        ]);

        return response()->json([
            'success' => true,
            'transaction' => $transaction,
            'category' => $category,
        ]);
    }

    /**
     * Catégorisation intelligente basée sur l'historique et règles
     */
    private function smartCategorize(string $smsBody, ?string $suggestedCategory): string
    {
        // Si une catégorie est suggérée, vérifier si elle existe
        if ($suggestedCategory) {
            $exists = Category::where('name', $suggestedCategory)->exists();
            if ($exists) {
                return $suggestedCategory;
            }
        }

        // Analyser l'historique des transactions similaires
        $similarTransactions = Transaction::where('user_id', Auth::id())
            ->where('description', 'like', '%' . substr($smsBody, 0, 20) . '%')
            ->with('category')
            ->get();

        if ($similarTransactions->isNotEmpty()) {
            // Utiliser la catégorie la plus fréquente
            $categoryCounts = $similarTransactions->pluck('category.name')->countBy();
            return $categoryCounts->sortDesc()->keys()->first();
        }

        // Règles basées sur mots-clés
        $keywords = [
            'nourriture' => ['restaurant', 'café', 'bar', 'food', 'manger', 'nourriture'],
            'transport' => ['taxi', 'bus', 'transport', 'essence', 'station', 'car'],
            'shopping' => ['achat', 'shopping', 'magasin', 'boutique', 'supermarché'],
            'facture' => ['facture', 'eau', 'électricité', 'internet', 'sénélec', 'sde'],
            'santé' => ['pharmacie', 'hôpital', 'santé', 'médicament', 'clinique'],
            'éducation' => ['école', 'cours', 'formation', 'livre', 'éducation'],
            'communication' => ['airtel', 'orange', 'expresso', 'credit', 'appel', 'internet'],
        ];

        $lowerBody = strtolower($smsBody);
        foreach ($keywords as $category => $words) {
            foreach ($words as $word) {
                if (strpos($lowerBody, $word) !== false) {
                    return $category;
                }
            }
        }

        // Catégorie par défaut
        return 'divers';
    }

    /**
     * Obtenir des suggestions de catégories basées sur l'historique
     */
    public function getCategorySuggestions(Request $request)
    {
        $description = $request->input('description', '');
        
        if (empty($description)) {
            return response()->json(['suggestions' => []]);
        }

        // Chercher des transactions similaires dans l'historique
        $similar = Transaction::where('user_id', Auth::id())
            ->where('description', 'like', '%' . substr($description, 0, 15) . '%')
            ->with('category')
            ->limit(5)
            ->get();

        $suggestions = $similar->pluck('category.name')->unique()->values();

        return response()->json(['suggestions' => $suggestions]);
    }

    /**
     * Obtenir des suggestions de descriptions basées sur l'historique
     */
    public function getDescriptionSuggestions(Request $request)
    {
        $categoryId = $request->input('category_id');
        
        if (!$categoryId) {
            return response()->json(['suggestions' => []]);
        }

        // Chercher des descriptions fréquentes pour cette catégorie
        $descriptions = Transaction::where('user_id', Auth::id())
            ->where('category_id', $categoryId)
            ->selectRaw('description, COUNT(*) as count')
            ->groupBy('description')
            ->orderByDesc('count')
            ->limit(5)
            ->get();

        $suggestions = $descriptions->pluck('description')->values();

        return response()->json(['suggestions' => $suggestions]);
    }
}
