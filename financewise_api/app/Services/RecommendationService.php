<?php

namespace App\Services;

use App\Models\Transaction;
use App\Models\Category;
use Illuminate\Support\Facades\Auth;

class RecommendationService
{
    public function generateRecommendations($userId)
    {
        $recommendations = [];

        // Analyser les dépenses par catégorie
        $categorySpending = $this->getCategorySpending($userId);
        $recommendations = array_merge($recommendations, $this->analyzeCategorySpending($categorySpending));

        // Analyser les tendances mensuelles
        $monthlyTrends = $this->getMonthlyTrends($userId);
        $recommendations = array_merge($recommendations, $this->analyzeMonthlyTrends($monthlyTrends));

        // Détecter les anomalies
        $anomalies = $this->detectAnomalies($userId);
        $recommendations = array_merge($recommendations, $this->analyzeAnomalies($anomalies));

        // Recommandations d'économie
        $recommendations = array_merge($recommendations, $this->generateSavingsRecommendations($userId));

        return array_unique($recommendations);
    }

    private function getCategorySpending($userId)
    {
        return Transaction::where('user_id', $userId)
            ->where('type', 'expense')
            ->selectRaw('category_id, SUM(amount) as total')
            ->with('category')
            ->groupBy('category_id')
            ->get();
    }

    private function analyzeCategorySpending($categorySpending)
    {
        $recommendations = [];
        $totalSpending = $categorySpending->sum('total');

        foreach ($categorySpending as $spending) {
            $percentage = ($spending->total / $totalSpending) * 100;

            // Catégories avec dépenses élevées
            if ($percentage > 30) {
                $recommendations[] = [
                    'type' => 'warning',
                    'message' => "Tu dépenses beaucoup en {$spending->category->name} ({$percentage}% du total). Essaie de réduire.",
                    'category' => $spending->category->name,
                ];
            }

            // Catégories avec dépenses très élevées
            if ($spending->total > 100000) {
                $recommendations[] = [
                    'type' => 'alert',
                    'message' => "Tes dépenses en {$spending->category->name} dépassent 100 000 XOF. Considère de réduire.",
                    'category' => $spending->category->name,
                ];
            }
        }

        return $recommendations;
    }

    private function getMonthlyTrends($userId)
    {
        return Transaction::where('user_id', $userId)
            ->where('type', 'expense')
            ->selectRaw('DATE_FORMAT(transaction_date, "%Y-%m") as month, SUM(amount) as total')
            ->groupBy('month')
            ->orderBy('month', 'desc')
            ->limit(6)
            ->get();
    }

    private function analyzeMonthlyTrends($monthlyTrends)
    {
        $recommendations = [];

        if ($monthlyTrends->count() < 2) {
            return $recommendations;
        }

        $currentMonth = $monthlyTrends->first();
        $previousMonth = $monthlyTrending[1];

        // Comparaison avec le mois précédent
        if ($currentMonth->total > $previousMonth->total) {
            $increase = (($currentMonth->total - $previousMonth->total) / $previousMonth->total) * 100;
            if ($increase > 20) {
                $recommendations[] = [
                    'type' => 'warning',
                    'message' => "Tes dépenses ont augmenté de {$increase}% par rapport au mois dernier.",
                ];
            }
        }

        // Tendance générale
        $trend = $this->calculateTrend($monthlyTrends);
        if ($trend > 10) {
            $recommendations[] = [
                'type' => 'alert',
                'message' => "Tes dépenses sont en hausse constante. Fais attention à tes finances.",
            ];
        }

        return $recommendations;
    }

    private function calculateTrend($monthlyTrends)
    {
        if ($monthlyTrends->count() < 3) return 0;

        $values = $monthlyTrends->pluck('total')->toArray();
        $increases = 0;

        for ($i = 1; $i < count($values); $i++) {
            if ($values[$i] > $values[$i - 1]) {
                $increases++;
            }
        }

        return ($increases / (count($values) - 1)) * 100;
    }

    private function detectAnomalies($userId)
    {
        return Transaction::where('user_id', $userId)
            ->where('type', 'expense')
            ->where('amount', '>', 50000)
            ->orderBy('amount', 'desc')
            ->limit(5)
            ->get();
    }

    private function analyzeAnomalies($anomalies)
    {
        $recommendations = [];

        foreach ($anomalies as $anomaly) {
            $recommendations[] = [
                'type' => 'info',
                'message' => "Transaction importante détectée: {$anomaly->description} ({$anomaly->amount} XOF). Vérifie si c'est normal.",
            ];
        }

        return $recommendations;
    }

    private function generateSavingsRecommendations($userId)
    {
        $recommendations = [];
        $transactions = Transaction::where('user_id', $userId)
            ->where('type', 'expense')
            ->get();

        // Fréquentation de restaurants
        $restaurantCount = $transactions->where('description', 'like', '%restaurant%')->count();
        if ($restaurantCount > 10) {
            $recommendations[] = [
                'type' => 'suggestion',
                'message' => "Tu vas souvent au restaurant. Cuisiner à la maison pourrait t'économiser.",
            ];
        }

        // Dépenses de transport
        $transportTotal = $transactions->where('description', 'like', '%taxi%')
            ->orWhere('description', 'like', '%bus%')
            ->sum('amount');
        if ($transportTotal > 50000) {
            $recommendations[] = [
                'type' => 'suggestion',
                'message' => "Tes dépenses de transport sont élevées. Considère le covoiturage.",
            ];
        }

        return $recommendations;
    }
}
