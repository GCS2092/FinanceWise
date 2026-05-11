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

        $categorySpending = $this->getCategorySpending($userId);
        $recommendations = array_merge($recommendations, $this->analyzeCategorySpending($categorySpending));

        $monthlyTrends = $this->getMonthlyTrends($userId);
        $recommendations = array_merge($recommendations, $this->analyzeMonthlyTrends($monthlyTrends));

        $anomalies = $this->detectAnomalies($userId);
        $recommendations = array_merge($recommendations, $this->analyzeAnomalies($anomalies));

        $recommendations = array_merge($recommendations, $this->generateSavingsRecommendations($userId));

        // Dédupliquer un tableau de tableaux par message
        $seen = [];
        $unique = [];
        foreach ($recommendations as $r) {
            $key = $r['message'] ?? json_encode($r);
            if (!isset($seen[$key])) {
                $seen[$key] = true;
                $unique[] = $r;
            }
        }
        return $unique;
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
        $totalSpending = (float) $categorySpending->sum('total');
        if ($totalSpending <= 0) return $recommendations;

        foreach ($categorySpending as $spending) {
            if (!$spending->category) continue;
            $percentage = ($spending->total / $totalSpending) * 100;
            $catName = $spending->category->name;

            if ($percentage > 30) {
                $recommendations[] = [
                    'type' => 'warning',
                    'message' => "Tu dépenses beaucoup en {$catName} (" . number_format($percentage, 0) . "% du total). Essaie de réduire.",
                    'category' => $catName,
                ];
            }

            if ($spending->total > 100000) {
                $recommendations[] = [
                    'type' => 'alert',
                    'message' => "Tes dépenses en {$catName} dépassent " . number_format($spending->total, 0, ',', ' ') . " FCFA. Considère de réduire.",
                    'category' => $catName,
                ];
            }
        }

        return $recommendations;
    }

    private function getMonthlyTrends($userId)
    {
        return Transaction::where('user_id', $userId)
            ->where('type', 'expense')
            ->selectRaw('TO_CHAR(transaction_date, \'YYYY-MM\') as month, SUM(amount) as total')
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
        $previousMonth = $monthlyTrends[1];

        // Comparaison avec le mois précédent
        if ($previousMonth->total > 0 && $currentMonth->total > $previousMonth->total) {
            $increase = (($currentMonth->total - $previousMonth->total) / $previousMonth->total) * 100;
            if ($increase > 20) {
                $recommendations[] = [
                    'type' => 'warning',
                    'message' => "Tes dépenses ont augmenté de " . number_format($increase, 0) . "% par rapport au mois dernier.",
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
                'message' => "Transaction importante détectée: {$anomaly->description} (" . number_format($anomaly->amount, 0, ',', ' ') . " FCFA). Vérifie si c'est normal.",
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
        $restaurantCount = $transactions->filter(fn($t) => str_contains(strtolower($t->description ?? ''), 'restaurant'))->count();
        if ($restaurantCount > 10) {
            $recommendations[] = [
                'type' => 'suggestion',
                'message' => "Tu vas souvent au restaurant. Cuisiner à la maison pourrait t'économiser.",
            ];
        }

        // Dépenses de transport
        $transportTotal = $transactions->filter(fn($t) => str_contains(strtolower($t->description ?? ''), 'taxi') || str_contains(strtolower($t->description ?? ''), 'bus'))
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
