<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Budget extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'amount',
        'period',
        'start_date',
        'end_date',
        'spent',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'spent' => 'decimal:2',
            'start_date' => 'date',
            'end_date' => 'date',
            'is_active' => 'boolean',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function transactions()
    {
        return $this->hasManyThrough(Transaction::class, Category::class, 'id', 'category_id')
            ->where('type', 'expense')
            ->whereBetween('transaction_date', [$this->start_date, $this->end_date]);
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function getRemainingAttribute()
    {
        return $this->amount - $this->spent;
    }

    public function getPercentageAttribute()
    {
        if ($this->amount == 0) return 0;
        return min(100, round(($this->spent / $this->amount) * 100, 2));
    }

    public function updateSpent()
    {
        $this->spent = $this->transactions()->sum('amount');
        $this->save();
    }
}
