<?php

use App\Http\Controllers\Api\AiController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AlertController;
use App\Http\Controllers\Api\GoalHistoryController;
use App\Http\Controllers\Api\BudgetController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\FinancialGoalController;
use App\Http\Controllers\Api\OnboardingController;
use App\Http\Controllers\Api\PaymentReminderController;
use App\Http\Controllers\Api\RecommendationController;
use App\Http\Controllers\Api\SmsParserController;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\WalletController;
use Illuminate\Support\Facades\Route;

// Routes publiques avec throttle spécifique
Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:register');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');

// Routes protégées avec throttle global API (60/min par user)
Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
    Route::get('/user', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/dashboard', [DashboardController::class, 'index']);

    // Onboarding
    Route::post('/user/onboarding', [OnboardingController::class, 'store']);
    Route::get('/user/onboarding/status', [OnboardingController::class, 'checkStatus']);

    // Routes spécifiques avant la resource pour éviter les conflits de route binding
    Route::get('/wallets/default', [WalletController::class, 'getDefault']);
    Route::post('/wallets/{wallet}/set-default', [WalletController::class, 'setDefault']);
    Route::apiResource('/wallets', WalletController::class);
    Route::apiResource('/categories', CategoryController::class);
    Route::apiResource('/transactions', TransactionController::class);
    Route::apiResource('/budgets', BudgetController::class);
    
    // Routes spécifiques avant la resource pour éviter les conflits de route binding
    Route::get('/financial-goals/category-list', [FinancialGoalController::class, 'categories'])->name('financial-goals.categories');
    Route::get('/financial-goals/suggestions', [FinancialGoalController::class, 'suggestions'])->name('financial-goals.suggestions');
    Route::apiResource('/financial-goals', FinancialGoalController::class)->except(['index']);
    Route::get('/financial-goals', [FinancialGoalController::class, 'index'])->name('financial-goals.index');
    Route::post('/financial-goals/{financial_goal}/add-amount', [FinancialGoalController::class, 'addAmount']);
    Route::get('/financial-goals/{financial_goal}/monthly-savings', [FinancialGoalController::class, 'monthlySavingsRecommendation']);
    Route::get('/financial-goals/{financial_goal}/history', [GoalHistoryController::class, 'index']);
    Route::post('/goal-histories/{goal_history}/revert', [GoalHistoryController::class, 'revert']);
    
    Route::apiResource('/payment-reminders', PaymentReminderController::class);
    Route::get('/payment-reminders/upcoming', [PaymentReminderController::class, 'upcoming']);
    Route::post('/payment-reminders/{payment_reminder}/mark-completed', [PaymentReminderController::class, 'markCompleted']);
    
    Route::apiResource('/alerts', AlertController::class)->only(['index']);
    Route::post('/alerts/{alert}/mark-read', [AlertController::class, 'markAsRead']);
    Route::post('/alerts/mark-all-read', [AlertController::class, 'markAllAsRead']);
    Route::get('/alerts/unread-count', [AlertController::class, 'unreadCount']);
    
    Route::get('/recommendations', [RecommendationController::class, 'index']);

    // SMS avec throttle spécifique (30/min par user)
    Route::middleware('throttle:sms')->group(function () {
        Route::post('/sms/parse', [SmsParserController::class, 'store']);
        Route::post('/sms/batch', [SmsParserController::class, 'batch']);
        Route::get('/sms/parse/{parsedSms}', [SmsParserController::class, 'show']);
    });

    // IA - Assistant financier
    Route::prefix('ai')->group(function () {
        Route::get('/status', [AiController::class, 'status']);

        // Chat (rate-limit dédié pour contrôler les coûts)
        Route::middleware('throttle:ai')->group(function () {
            Route::post('/chat', [AiController::class, 'chat']);
            Route::post('/categorize', [AiController::class, 'categorize']);
        });

        Route::get('/conversations', [AiController::class, 'conversations']);
        Route::get('/conversations/{id}', [AiController::class, 'conversationMessages']);
        Route::delete('/conversations/{id}', [AiController::class, 'deleteConversation']);

        Route::get('/insights/monthly', [AiController::class, 'monthlyInsight']);
        Route::post('/insights/monthly/read', [AiController::class, 'markInsightRead']);

        Route::post('/categorize/learn', [AiController::class, 'learnCorrection']);
    });
});
