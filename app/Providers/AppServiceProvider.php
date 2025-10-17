<?php

namespace App\Providers;

use Illuminate\Pagination\Paginator;

use Illuminate\Support\Facades\URL;  // Add this import
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        Paginator::useBootstrap();
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void  // Add return type
    {
        if (env('FORCE_HTTPS', false)) {
            URL::forceScheme('https');
        }
    }

}
