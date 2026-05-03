<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class LogHeadersMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->isMethod('PUT') && $request->is('api/config/site')) {
            \Log::info("PUT /api/config/site Headers: ", $request->headers->all());
            \Log::info("Bearer Token: " . $request->bearerToken());
        }
        return $next($request);
    }
}
