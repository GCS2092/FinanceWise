<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiInsight extends Model
{
    protected $fillable = ['user_id', 'type', 'period', 'summary', 'highlights', 'suggestions', 'is_read'];

    protected $casts = [
        'highlights' => 'array',
        'suggestions' => 'array',
        'is_read' => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
