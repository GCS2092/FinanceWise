<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Alert extends Model
{
    protected $fillable = ['user_id', 'type', 'title', 'message', 'data', 'is_read', 'read_at', 'severity'];

    protected $casts = [
        'data' => 'array',
        'is_read' => 'boolean',
        'read_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function markAsRead()
    {
        $this->update([
            'is_read' => true,
            'read_at' => now(),
        ]);
    }

    public function scopeForUser($query)
    {
        return $query->where('user_id', auth()->id());
    }

    public function scopeUnread($query)
    {
        return $query->where('is_read', false);
    }
}
