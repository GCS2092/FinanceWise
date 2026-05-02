<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('alerts', function (Blueprint $table) {
            $table->string('severity')->default('info')->after('message');
        });
    }

    public function down()
    {
        Schema::table('alerts', function (Blueprint $table) {
            $table->dropColumn('severity');
        });
    }
};
