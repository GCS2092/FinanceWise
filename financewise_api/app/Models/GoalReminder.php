<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class GoalReminder extends Model
{
    use HasFactory;

    protected $fillable = [
        'financial_goal_id',
        'user_id',
        'type',
        'scheduled_at',
        'sent_at',
        'status',
        'message',
    ];

    protected $casts = [
        'scheduled_at' => 'datetime',
        'sent_at' => 'datetime',
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

    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeSent($query)
    {
        return $query->where('status', 'sent');
    }

    public function scopeDue($query)
    {
        return $query->where('scheduled_at', '<=', now())->where('status', 'pending');
    }
}
