package com.wttrfck.wttr_fck.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import kotlin.random.Random

/**
 * Everything the widget knows, stored in the same SharedPreferences file the
 * home_widget Flutter plugin writes to. The app (lib/services/widget_sync.dart)
 * and WidgetRefreshWorker both write here; the widget only reads.
 *
 * All values are strings so Dart and Kotlin never disagree about types.
 * Raw weather values are metric; formatting happens at render time.
 */
class WidgetStore(context: Context) {
    val prefs: SharedPreferences =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    private fun s(k: String) = prefs.getString(k, null)
    private fun d(k: String, def: Double = 0.0) = s(k)?.toDoubleOrNull() ?: def

    val hasPlace get() = s("w_lat") != null && s("w_lon") != null
    val lat get() = d("w_lat")
    val lon get() = d("w_lon")
    val place get() = s("w_place") ?: "wttr.fck"
    val head get() = s("w_head")
    val sub get() = s("w_sub")
    val updatedAt get() = s("w_updated")?.toLongOrNull() ?: 0L

    val units get() = WeatherLogic.Units(
        fahrenheit = s("w_temp_unit") == "f",
        wind = s("w_wind_unit") ?: "kmh",
    )

    val weather: WeatherLogic.Weather?
        get() {
            if (s("r_temp") == null) return null
            return WeatherLogic.Weather(
                temp = d("r_temp"),
                feels = d("r_feels"),
                high = d("r_high"),
                low = d("r_low"),
                wind = d("r_wind"),
                gusts = d("r_gusts"),
                pop = d("r_pop").toInt(),
                uv = d("r_uv"),
                vis = d("r_vis", 10000.0),
                code = d("r_code").toInt(),
                isDay = s("r_isday") != "0",
            )
        }

    fun saveWeather(w: WeatherLogic.Weather) = prefs.edit()
        .putString("r_temp", "${w.temp}")
        .putString("r_feels", "${w.feels}")
        .putString("r_high", "${w.high}")
        .putString("r_low", "${w.low}")
        .putString("r_wind", "${w.wind}")
        .putString("r_gusts", "${w.gusts}")
        .putString("r_pop", "${w.pop}")
        .putString("r_uv", "${w.uv}")
        .putString("r_vis", "${w.vis}")
        .putString("r_code", "${w.code}")
        .putString("r_isday", if (w.isDay) "1" else "0")
        .putString("w_updated", "${System.currentTimeMillis()}")
        .apply()

    /**
     * Picks a fresh roast for the current weather from the pack the app
     * saved (already in the user's voice and language level), fills in the
     * numbers and stores it. Returns false if there's nothing to pick from.
     */
    fun reroll(): Boolean {
        val w = weather ?: return false
        val pack = s("w_pack")?.let { runCatching { JSONObject(it) }.getOrNull() } ?: return false
        val lines = pack.optJSONArray(WeatherLogic.mood(w)) ?: return false
        if (lines.length() == 0) return false
        val u = units
        val city = place
        val current = head
        var pick = lines.getJSONArray(Random.nextInt(lines.length()))
        // Avoid showing the same line twice in a row when there's a choice.
        var tries = 0
        while (lines.length() > 1 && tries++ < 5 &&
            WeatherLogic.fill(pick.getString(0), w, u, city) == current
        ) {
            pick = lines.getJSONArray(Random.nextInt(lines.length()))
        }
        prefs.edit()
            .putString("w_head", WeatherLogic.fill(pick.getString(0), w, u, city))
            .putString("w_sub", WeatherLogic.fill(pick.getString(1), w, u, city))
            .apply()
        return true
    }
}
