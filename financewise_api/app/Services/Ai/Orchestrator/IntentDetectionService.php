<?php

namespace App\Services\Ai\Orchestrator;

use App\Models\User;
use App\Services\Ai\AiTools;

/**
 * Détection d’intention légère (heuristique + mots-clés).
 * Si une réponse peut être servie sans LLM, renvoie skip_llm + direct_reply.
 */
class IntentDetectionService
{
    public const INTENT_BUDGET_QUESTION = 'budget_question';

    public const INTENT_SPENDING_ANALYSIS = 'spending_analysis';

    public const INTENT_TRANSACTION_QUESTION = 'transaction_question';

    public const INTENT_ADVICE_QUESTION = 'advice_question';

    public const INTENT_GREETING = 'greeting';

    public const INTENT_FINANCIAL_GOAL = 'financial_goal';

    public const INTENT_STATISTICS_QUESTION = 'statistics_question';

    public const INTENT_CATEGORIZATION_REQUEST = 'categorization_request';

    public const INTENT_GENERAL = 'general';

    /**
     * @return array{intent: string, skip_llm: bool, direct_reply: ?string}
     */
    public function detect(User $user, string $message): array
    {
        $t = trim($message);
        $lower = mb_strtolower($t);

        if ($this->isGreeting($lower)) {
            return [
                'intent' => self::INTENT_GREETING,
                'skip_llm' => true,
                'direct_reply' => "Salut ! Je suis ton assistant FinanceWise. Dis-moi ce que tu veux savoir sur ton budget, tes dépenses du mois, tes objectifs ou tes portefeuilles — j’appuie mes réponses chiffrées sur tes vraies données.",
            ];
        }

        if ($this->isMonthlySpendQuestion($lower)) {
            $tools = new AiTools($user);
            $m = $tools->getMonthlySummary(null);
            $exp = number_format((float) ($m['expense_fcfa'] ?? 0), 0, ',', ' ');
            $inc = number_format((float) ($m['income_fcfa'] ?? 0), 0, ',', ' ');
            $net = number_format((float) ($m['net_fcfa'] ?? 0), 0, ',', ' ');

            return [
                'intent' => self::INTENT_STATISTICS_QUESTION,
                'skip_llm' => true,
                'direct_reply' => "Pour le mois {$m['month']}, d’après tes transactions enregistrées : dépenses {$exp} FCFA, revenus {$inc} FCFA, solde net du mois {$net} FCFA. Pour le détail par catégorie ou comparer avec un autre mois, demande-le moi.",
            ];
        }

        if ($this->isBudgetStatusQuestion($lower)) {
            $tools = new AiTools($user);
            $b = $tools->getBudgetStatus();
            $rows = $b['budgets'] ?? [];
            if ($rows === []) {
                return [
                    'intent' => self::INTENT_BUDGET_QUESTION,
                    'skip_llm' => true,
                    'direct_reply' => "Tu n’as pas encore de budget actif pour cette période dans l’app. Tu peux en créer un depuis l’écran Budgets — je pourrai ensuite te dire ce qu’il reste par catégorie.",
                ];
            }
            $lines = [];
            foreach (array_slice($rows, 0, 6) as $row) {
                $cat = $row['category'] ?? '?';
                $rem = number_format((float) ($row['remaining_fcfa'] ?? 0), 0, ',', ' ');
                $pct = $row['percentage'] ?? 0;
                $lines[] = "• {$cat} : il reste {$rem} FCFA (utilisation ~{$pct} %).";
            }

            return [
                'intent' => self::INTENT_BUDGET_QUESTION,
                'skip_llm' => true,
                'direct_reply' => "Voici l’état de tes budgets actifs :\n" . implode("\n", $lines),
            ];
        }

        if ($this->isGoalQuestion($lower)) {
            $tools = new AiTools($user);
            $g = $tools->getGoalProgress();
            $goals = $g['goals'] ?? [];
            if ($goals === []) {
                return [
                    'intent' => self::INTENT_FINANCIAL_GOAL,
                    'skip_llm' => true,
                    'direct_reply' => "Tu n’as pas encore d’objectif d’épargne enregistré. Tu peux en ajouter dans Objectifs — je pourrai suivre ta progression.",
                ];
            }
            $lines = [];
            foreach (array_slice($goals, 0, 5) as $row) {
                $name = $row['name'] ?? 'Objectif';
                $pct = $row['percentage'] ?? 0;
                $cur = number_format((float) ($row['current_fcfa'] ?? 0), 0, ',', ' ');
                $tgt = number_format((float) ($row['target_fcfa'] ?? 0), 0, ',', ' ');
                $lines[] = "• {$name} : {$cur} / {$tgt} FCFA (~{$pct} %).";
            }

            return [
                'intent' => self::INTENT_FINANCIAL_GOAL,
                'skip_llm' => true,
                'direct_reply' => "Tes objectifs :\n" . implode("\n", $lines),
            ];
        }

        if ($this->looksLikeCategorizationRequest($lower)) {
            return ['intent' => self::INTENT_CATEGORIZATION_REQUEST, 'skip_llm' => false, 'direct_reply' => null];
        }

        if ($this->looksLikeTransactionQuestion($lower)) {
            return ['intent' => self::INTENT_TRANSACTION_QUESTION, 'skip_llm' => false, 'direct_reply' => null];
        }

        if ($this->looksLikeAdvice($lower)) {
            return ['intent' => self::INTENT_ADVICE_QUESTION, 'skip_llm' => false, 'direct_reply' => null];
        }

        if ($this->looksLikeSpendingAnalysis($lower)) {
            return ['intent' => self::INTENT_SPENDING_ANALYSIS, 'skip_llm' => false, 'direct_reply' => null];
        }

        return ['intent' => self::INTENT_GENERAL, 'skip_llm' => false, 'direct_reply' => null];
    }

    protected function isGreeting(string $lower): bool
    {
        if (mb_strlen($lower) > 72) {
            return false;
        }
        if (str_contains($lower, 'combien')
            || str_contains($lower, 'dépens')
            || str_contains($lower, 'depens')
            || str_contains($lower, 'budget')
            || str_contains($lower, 'objectif')) {
            return false;
        }

        return (bool) preg_match('/^(bonjour|salut|coucou|hey|hello|bonsoir|yo)(\s|!|,|\.)*$/iu', trim($lower));
    }

    protected function isMonthlySpendQuestion(string $lower): bool
    {
        if (!str_contains($lower, 'combien')) {
            return false;
        }
        $hasSpend = str_contains($lower, 'dépens') || str_contains($lower, 'depens');
        $monthCtx = str_contains($lower, 'ce mois')
            || str_contains($lower, 'mois-ci')
            || str_contains($lower, 'mois ci')
            || str_contains($lower, 'ce mois-ci')
            || str_contains($lower, 'du mois')
            || str_contains($lower, 'en ce moment');

        return $hasSpend && $monthCtx;
    }

    protected function isBudgetStatusQuestion(string $lower): bool
    {
        if (!str_contains($lower, 'budget')) {
            return false;
        }

        return (bool) preg_match('/(respect|reste|restant|état|etat|status|dépasse|depasse|va mal|ça va)/u', $lower);
    }

    protected function isGoalQuestion(string $lower): bool
    {
        return str_contains($lower, 'objectif')
            && (bool) preg_match('/(où en|ou en|progression|atteint|épargne|epargne)/u', $lower);
    }

    protected function looksLikeCategorizationRequest(string $lower): bool
    {
        return str_contains($lower, 'catégor') || str_contains($lower, 'categor')
            || str_contains($lower, 'classer cette transaction');
    }

    protected function looksLikeTransactionQuestion(string $lower): bool
    {
        return str_contains($lower, 'transaction')
            || str_contains($lower, 'opération')
            || str_contains($lower, 'operation')
            || (str_contains($lower, 'liste') && str_contains($lower, 'dépense'));
    }

    protected function looksLikeAdvice(string $lower): bool
    {
        return (bool) preg_match('/(conseil|comment économ|comment faire pour|aide-moi|que ferais-tu|que ferais tu)/u', $lower);
    }

    protected function looksLikeSpendingAnalysis(string $lower): bool
    {
        return str_contains($lower, 'analys')
            || str_contains($lower, 'tendance')
            || str_contains($lower, 'compar')
            || str_contains($lower, 'évolution')
            || str_contains($lower, 'evolution');
    }
}
