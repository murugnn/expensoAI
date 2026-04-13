package com.example.expenso

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import androidx.core.content.res.ResourcesCompat
import kotlin.math.max

class ExpenseGraphWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "UPDATE_EXPENSE_DATA" || intent.action == "UPDATE_WIDGET_DATA") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, ExpenseGraphWidgetProvider::class.java.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // ✅ FIX 1: Add "flutter." prefix so we can find the keys
        // ✅ FIX 2: Use getLong() because Flutter saves integers as Longs
        val lastMonthRaw = prefs.getLong("flutter.expense_last_month", 0L).toFloat()
        val thisMonthRaw = prefs.getLong("flutter.expense_this_month", 0L).toFloat()

        // ✅ FIX 3: Add "flutter." prefix for strings too
        val lastMonthLabel = prefs.getString("flutter.label_last_month", "PREV") ?: "PREV"
        val thisMonthLabel = prefs.getString("flutter.label_this_month", "CURR") ?: "CURR"

        val views = RemoteViews(context.packageName, R.layout.widget_expense_graph)

        val bitmap = drawGraph(context, lastMonthRaw, thisMonthRaw, lastMonthLabel, thisMonthLabel)
        views.setImageViewBitmap(R.id.graph_image, bitmap)

        val appIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, appIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.click_overlay, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun drawGraph(context: Context, valLast: Float, valThis: Float, labelLast: String, labelThis: String): Bitmap {
        val width = 500
        val height = 500
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            try { typeface = ResourcesCompat.getFont(context, R.font.ndot) } catch (e: Exception) {}
        }

        val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        val axisPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#44FFFFFF")
            strokeWidth = 3f
        }

        // TITLE
        textPaint.textSize = 50f
        textPaint.color = Color.WHITE
        canvas.drawText("EXPENSO", width / 2f, 60f, textPaint)

        // GRAPH LOGIC
        val maxVal = max(valLast, valThis).coerceAtLeast(1f)
        val graphBottom = height - 80f
        val graphTop = 180f
        val maxBarHeight = graphBottom - graphTop

        val barWidth = 100f
        val spacing = 80f
        val totalGroupWidth = (barWidth * 2) + spacing
        val startX = (width - totalGroupWidth) / 2

        // BAR 1 (LAST)
        barPaint.color = Color.parseColor("#66FFFFFF")
        val heightLast = (valLast / maxVal) * maxBarHeight
        val left1 = startX
        val top1 = graphBottom - heightLast
        val rect1 = RectF(left1, top1, left1 + barWidth, graphBottom)
        canvas.drawRoundRect(rect1, 16f, 16f, barPaint)

        textPaint.color = Color.WHITE
        textPaint.textSize = 45f
        canvas.drawText(formatMoney(valLast), left1 + (barWidth/2), top1 - 15f, textPaint)
        
        textPaint.textSize = 30f
        textPaint.color = Color.parseColor("#AAAAAA")
        canvas.drawText(labelLast, left1 + (barWidth/2), graphBottom + 40f, textPaint)

        // BAR 2 (THIS)
        barPaint.color = Color.WHITE
        val heightThis = (valThis / maxVal) * maxBarHeight
        val left2 = left1 + barWidth + spacing
        val top2 = graphBottom - heightThis
        val rect2 = RectF(left2, top2, left2 + barWidth, graphBottom)
        canvas.drawRoundRect(rect2, 16f, 16f, barPaint)

        textPaint.color = Color.WHITE
        textPaint.textSize = 45f
        canvas.drawText(formatMoney(valThis), left2 + (barWidth/2), top2 - 15f, textPaint)

        textPaint.textSize = 30f
        textPaint.color = Color.parseColor("#AAAAAA")
        canvas.drawText(labelThis, left2 + (barWidth/2), graphBottom + 40f, textPaint)

        // BASELINE
        canvas.drawLine(40f, graphBottom, width - 40f, graphBottom, axisPaint)

        return bitmap
    }

    private fun formatMoney(value: Float): String {
        return if (value >= 1000) {
            String.format("%.1fk", value / 1000)
        } else {
            String.format("%.0f", value)
        }
    }
}