package com.wttrfck.wttr_fck.widget

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Keeps the widget fresh while the app is closed: fetches the current
 * weather for the last place the app showed (no background location access
 * needed), picks a new roast and redraws. Plain native code, so it never
 * has to start the Flutter engine. Cheap on battery.
 */
class WidgetRefreshWorker(context: Context, params: WorkerParameters) :
    Worker(context, params) {

    override fun doWork(): Result {
        val store = WidgetStore(applicationContext)
        if (!store.hasPlace) return Result.success()
        return try {
            val url = URL(
                String.format(
                    Locale.US,
                    "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f" +
                        "&current=temperature_2m,apparent_temperature,is_day,weather_code," +
                        "wind_speed_10m,wind_gusts_10m,uv_index,visibility" +
                        "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
                        "&forecast_days=1&timezone=auto",
                    store.lat, store.lon,
                ),
            )
            val conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 15000
                setRequestProperty("User-Agent", "wttr.fck-widget/1.0")
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            conn.disconnect()

            val j = JSONObject(body)
            val c = j.getJSONObject("current")
            val d = j.getJSONObject("daily")
            store.saveWeather(
                WeatherLogic.Weather(
                    temp = c.optDouble("temperature_2m"),
                    feels = c.optDouble("apparent_temperature"),
                    high = d.getJSONArray("temperature_2m_max").optDouble(0),
                    low = d.getJSONArray("temperature_2m_min").optDouble(0),
                    wind = c.optDouble("wind_speed_10m", 0.0),
                    gusts = c.optDouble("wind_gusts_10m", 0.0),
                    pop = d.getJSONArray("precipitation_probability_max").optInt(0),
                    uv = c.optDouble("uv_index", 0.0),
                    vis = c.optDouble("visibility", 10000.0),
                    code = c.optInt("weather_code"),
                    isDay = c.optInt("is_day", 1) == 1,
                ),
            )
            store.reroll()
            WeatherWidget.updateAll(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    companion object {
        private const val PERIODIC = "wttr_widget_refresh"
        private const val ONE_SHOT = "wttr_widget_refresh_now"

        private val online = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                PERIODIC,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<WidgetRefreshWorker>(30, TimeUnit.MINUTES)
                    .setConstraints(online)
                    .build(),
            )
        }

        fun refreshNow(context: Context) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                ONE_SHOT,
                ExistingWorkPolicy.KEEP,
                OneTimeWorkRequestBuilder<WidgetRefreshWorker>().setConstraints(online).build(),
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).apply {
                cancelUniqueWork(PERIODIC)
                cancelUniqueWork(ONE_SHOT)
            }
        }
    }
}
