package com.example.expenso

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.res.ResourcesCompat

class BattleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return BattleWidgetFactory(this.applicationContext)
    }
}

class BattleWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    
    private var streak = "0"
    
    override fun onCreate() {
        // Initial setup
    }

    override fun onDataSetChanged() {
        // Reload data from SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        streak = prefs.getString("flutter.streak", "0") ?: "0"
    }

    override fun onDestroy() {}

    override fun getCount(): Int {
        return 2 // We have exactly 2 pages: Fire and Tea
    }

    override fun getViewAt(position: Int): RemoteViews {
        val rv: RemoteViews

        // FIX: Initialize 'rv' inside the if/else blocks
        if (position == 0) {
            // --- PAGE 1: FIRE ---
            // 1. Initialize the view with the Fire layout
            rv = RemoteViews(context.packageName, R.layout.item_page_fire)
            
            // 2. Generate Bitmap
            val bitmap = textAsBitmap(context, streak, 130f, Color.WHITE)
            rv.setImageViewBitmap(R.id.img_streak_text, bitmap)

            // 3. Set Click Listener for Fire Image
            val fillInIntent = Intent()
            rv.setOnClickFillInIntent(R.id.img_fire, fillInIntent)

        } else {
            // --- PAGE 2: TEA ---
            // 1. Initialize the view with the Tea layout
            rv = RemoteViews(context.packageName, R.layout.item_page_tea)
            
            // 2. Generate Bitmap
            val bitmap = textAsBitmap(context, "WithoutChaya", 50f, Color.WHITE)
            rv.setImageViewBitmap(R.id.img_caption_text, bitmap)

            // 3. Set Click Listener for Tea Image
            val fillInIntent = Intent()
            rv.setOnClickFillInIntent(R.id.img_tea, fillInIntent)
        }
        
        return rv
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 2
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    // Helper: Draw Text as Bitmap for Ndot Font
    private fun textAsBitmap(context: Context, text: String, textSize: Float, textColor: Int): Bitmap {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.textSize = textSize
        paint.color = textColor
        paint.textAlign = Paint.Align.CENTER
        
        try {
            val typeface = ResourcesCompat.getFont(context, R.font.ndot)
            paint.typeface = typeface
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val baseline = -paint.ascent()
        // Ensure width is at least 1 to avoid crash on empty string
        val measuredWidth = paint.measureText(text).toInt()
        val width = (measuredWidth + 20).coerceAtLeast(1)
        val height = (baseline + paint.descent() + 20).toInt().coerceAtLeast(1)
        
        val image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(image)
        canvas.drawText(text, width / 2f, baseline, paint)
        return image
    }
}