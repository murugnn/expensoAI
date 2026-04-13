package com.example.expenso

import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.expenso/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgets") {
                val context = context
                
                // 1. Send Update Signal to Expense Graph Widget
                val intent = Intent(context, ExpenseGraphWidgetProvider::class.java)
                intent.action = "UPDATE_EXPENSE_DATA"
                val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, ExpenseGraphWidgetProvider::class.java))
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                context.sendBroadcast(intent)
                
                // 2. Send Update Signal to Battle Widget (if needed)
                val intentBattle = Intent(context, BattleWidgetProvider::class.java)
                intentBattle.action = "UPDATE_WIDGET_DATA"
                val idsBattle = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, BattleWidgetProvider::class.java))
                intentBattle.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, idsBattle)
                context.sendBroadcast(intentBattle)

                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}