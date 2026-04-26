<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AlertController;
use App\Http\Controllers\Api\AutoTransactionController;
use App\Http\Controllers\Api\BudgetController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\FinancialGoalController;
use App\Http\Controllers\Api\PaymentReminderController;
use App\Http\Controllers\Api\RecommendationController;
use App\Http\Controllers\Api\SmsParserController;
use App\Http\Controllers\Api\TransactionController;
use App\Http\Controllers\Api\WalletController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/dashboard', [DashboardController::class, 'index']);

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

    Route::post('/sms/parse', [SmsParserController::class, 'store']);
    Route::post('/sms/batch', [SmsParserController::class, 'batch']);
    
    // Auto-transaction endpoints
    Route::post('/auto/sms', [AutoTransactionController::class, 'receiveSms']);
    Route::get('/auto/suggestions/categories', [AutoTransactionController::class, 'getCategorySuggestions']);
    Route::get('/auto/suggestions/descriptions', [AutoTransactionController::class, 'getDescriptionSuggestions']);
});
