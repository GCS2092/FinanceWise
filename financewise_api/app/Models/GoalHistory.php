<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class GoalHistory extends Model
{
    use HasFactory;

    protected $fillable = [
        'financial_goal_id',
        'user_id',
        'amount',
        'balance_before',
        'balance_after',
        'type',
        'notes',
        'is_reverted',
        'reverted_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'balance_before' => 'decimal:2',
        'balance_after' => 'decimal:2',
        'is_reverted' => 'boolean',
        'reverted_at' => 'datetime',
    ];

    public function financialGoal()
    {
        return $this->belongsTo(FinancialGoal::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function scopeForUser($query)
    {
        return $query->where('user_id', auth()->id());
    }

    public function scopeNotReverted($query)
    {
        return $query->where('is_reverted', false);
    }

    public function scopeReverted($query)
    {
        return $query->where('is_reverted', true);
    }
}
