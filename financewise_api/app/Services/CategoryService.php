<?php

namespace App\Services;

use App\Models\Category;
use Illuminate\Support\Facades\Cache;

class CategoryService
{
    public function getForUser(int $userId)
    {
        return Cache::remember("categories:user:{$userId}", 3600, function () use ($userId) {
            return Category::where('is_system', true)
                ->orWhere('user_id', $userId)
                ->orderBy('name')
                ->get();
        });
    }

    public function createForUser(array $data, int $userId): Category
    {
        $data['user_id'] = $userId;
        $data['is_system'] = false;
        $category = Category::create($data);

        self::clearCache($userId);

        return $category;
    }

    public static function clearCache(int $userId): void
    {
        Cache::forget("categories:user:{$userId}");
    }
}
