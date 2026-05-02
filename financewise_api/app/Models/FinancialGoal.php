<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FinancialGoal extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'name',
        'description',
        'target_amount',
        'current_amount',
        'target_date',
        'icon',
        'color',
        'status',
        'category_id',
        'reminder_frequency',
        'last_reminder_sent_at',
    ];

    protected $casts = [
        'target_amount' => 'decimal:2',
        'current_amount' => 'decimal:2',
        'target_date' => 'date',
        'last_reminder_sent_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function histories()
    {
        return $this->hasMany(GoalHistory::class);
    }

    public function reminders()
    {
        return $this->hasMany(GoalReminder::class);
    }

    public function getProgressAttribute()
    {
        if ($this->target_amount == 0) return 0;
        return ($this->current_amount / $this->target_amount) * 100;
    }

    public function getRemainingAmountAttribute()
    {
        return max(0, $this->target_amount - $this->current_amount);
    }

    public function getDaysRemainingAttribute()
    {
        if (!$this->target_date) return null;
        return now()->diffInDays($this->target_date, false);
    }

    public function getIsOverdueAttribute()
    {
        if (!$this->target_date) return false;
        return now()->gt($this->target_date) && $this->status !== 'completed';
    }

    public function getIsNearDeadlineAttribute()
    {
        if (!$this->target_date || $this->status === 'completed') return false;
        $days = $this->days_remaining;
        return $days >= 0 && $days <= 7;
    }

    public function scopeForUser($query)
    {
        return $query->where('user_id', auth()->id());
    }

    public function scopeActive($query)
    {
        return $query->where('status', '!=', 'completed');
    }
}
