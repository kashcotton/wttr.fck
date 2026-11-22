package com.wttrfck.wttr_fck.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import com.wttrfck.wttr_fck.MainActivity
import com.wttrfck.wttr_fck.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen widget. Three responsive layouts (2x2, 4x1, 4x2+),
 * Material You colors, tap to open the app, arrow button for a new roast.
 */
class WeatherWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
        // Stale or never fetched? Ask for a background refresh.
        val store = WidgetStore(context)
        val age = System.currentTimeMillis() - store.updatedAt
        if (store.hasPlace && age > 40 * 60 * 1000L) WidgetRefreshWorker.refreshNow(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshWorker.schedule(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetRefreshWorker.cancel(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REROLL) {
            if (WidgetStore(context).reroll()) updateAll(context)
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_REROLL = "com.wttrfck.wttr_fck.widget.REROLL"

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, WeatherWidget::class.java))
            for (id in ids) render(context, mgr, id)
        }

        fun render(context: Context, mgr: AppWidgetManager, id: Int) {
            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+: the launcher picks the best layout for the size.
                RemoteViews(
                    mapOf(
                        SizeF(100f, 100f) to build(context, R.layout.widget_small),
                        SizeF(220f, 50f) to build(context, R.layout.widget_short),
                        SizeF(220f, 140f) to build(context, R.layout.widget_medium),
                    ),
                )
            } else {
                val o = mgr.getAppWidgetOptions(id)
                val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
                val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 140)
                val layout = when {
                    h < 100 -> R.layout.widget_short
                    w < 220 -> R.layout.widget_small
                    else -> R.layout.widget_medium
                }
                build(context, layout)
            }
            mgr.updateAppWidget(id, views)
        }

        /** Which views each layout has. RemoteViews fails the whole widget
         *  ("Can't load widget") if we touch a view that isn't there. */
        private val VIEWS = mapOf(
            R.layout.widget_small to setOf(R.id.w_temp, R.id.w_icon, R.id.w_place, R.id.w_head),
            R.layout.widget_short to setOf(R.id.w_icon, R.id.w_temp, R.id.w_head, R.id.w_reroll),
            R.layout.widget_medium to setOf(
                R.id.w_place, R.id.w_temp, R.id.w_icon, R.id.w_cond,
                R.id.w_hilo, R.id.w_head, R.id.w_sub, R.id.w_reroll,
            ),
        )

        private fun build(context: Context, layout: Int): RemoteViews {
            val store = WidgetStore(context)
            val v = RemoteViews(context.packageName, layout)
            val has = VIEWS.getValue(layout)
            fun text(id: Int, value: CharSequence) {
                if (id in has) v.setTextViewText(id, value)
            }
            val w = store.weather
            val u = store.units

            text(R.id.w_place, store.place)
            if (w == null) {
                text(R.id.w_temp, "--°")
                text(R.id.w_cond, "")
                text(R.id.w_hilo, "")
                text(R.id.w_head, context.getString(R.string.widget_empty_head))
                text(R.id.w_sub, context.getString(R.string.widget_empty_sub))
                v.setImageViewResource(R.id.w_icon, R.drawable.ic_w_cloud)
            } else {
                val (icon, tint) = WeatherLogic.icon(w.code, w.isDay)
                val cond = WeatherLogic.describe(w.code)
                text(R.id.w_temp, u.deg(w.temp))
                text(R.id.w_cond, cond)
                text(R.id.w_hilo, "H ${u.deg(w.high)}  L ${u.deg(w.low)}")
                text(R.id.w_head, store.head ?: cond)
                text(R.id.w_sub, store.sub ?: "")
                v.setImageViewResource(R.id.w_icon, icon)
                v.setInt(R.id.w_icon, "setColorFilter", tint)
                v.setContentDescription(R.id.w_temp, "${u.deg(w.temp)}, $cond in ${store.place}")
            }

            // Tap anywhere: open the app.
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java)
                    .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            v.setOnClickPendingIntent(android.R.id.background, open)

            // Arrow: a new roast, no network needed.
            val reroll = PendingIntent.getBroadcast(
                context, 1,
                Intent(context, WeatherWidget::class.java).setAction(ACTION_REROLL),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (R.id.w_reroll in has) v.setOnClickPendingIntent(R.id.w_reroll, reroll)
            return v
        }
    }
}
