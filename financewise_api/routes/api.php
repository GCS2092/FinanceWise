<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AlertController;
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

    Route::apiResource('/wallets', WalletController::class);
    Route::apiResource('/categories', CategoryController::class);
    Route::apiResource('/transactions', TransactionController::class);
    Route::apiResource('/budgets', BudgetController::class);
    Route::apiResource('/financial-goals', FinancialGoalController::class);
    Route::post('/financial-goals/{financial_goal}/add-amount', [FinancialGoalController::class, 'addAmount']);
    
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
});
