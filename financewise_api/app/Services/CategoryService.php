<?php

namespace App\Services;

use App\Models\Category;

class CategoryService
{
    public function getForUser(int $userId)
    {
        return Category::where('is_system', true)
            ->orWhere('user_id', $userId)
            ->orderBy('name')
            ->get();
    }

    public function createForUser(array $data, int $userId): Category
    {
        $data['user_id'] = $userId;
        $data['is_system'] = false;
        return Category::create($data);
    }
}
