<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class ForceJsonResponse
{
    public function handle(Request $request, Closure $next)
    {
        // Force Laravel à traiter toutes les requêtes API comme JSON
        $request->headers->set('Accept', 'application/json');
        return $next($request);
    }
}