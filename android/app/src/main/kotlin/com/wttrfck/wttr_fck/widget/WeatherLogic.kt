package com.wttrfck.wttr_fck.widget

import com.wttrfck.wttr_fck.R
import kotlin.math.roundToInt

object WeatherLogic {
    enum class Sky { CLEAR, PARTLY, CLOUDY, FOG, DRIZZLE, RAIN, SNOW, STORM }

    fun sky(code: Int): Sky = when {
        code == 0 -> Sky.CLEAR
        code <= 2 -> Sky.PARTLY
        code == 3 -> Sky.CLOUDY
        code == 45 || code == 48 -> Sky.FOG
        code in 51..57 -> Sky.DRIZZLE
        code in 61..67 || code in 80..82 -> Sky.RAIN
        code in 71..77 || code == 85 || code == 86 -> Sky.SNOW
        code >= 95 -> Sky.STORM
        else -> Sky.CLOUDY
    }

    fun mood(w: Weather): String {
        val s = sky(w.code)
        return when {
            s == Sky.STORM -> "storm"
            s == Sky.SNOW -> "snow"
            s == Sky.RAIN -> "rain"
            s == Sky.DRIZZLE -> "drizzle"
            s == Sky.FOG -> "fog"
            w.gusts >= 55 || w.wind >= 40 -> "windy"
            w.feels >= 35 -> "scorching"
            w.feels >= 28 -> "hot"
            w.feels < 0 -> "freezing"
            w.feels < 11 -> "cold"
            !w.isDay && (s == Sky.CLEAR || s == Sky.PARTLY) -> "clearNight"
            s == Sky.CLEAR || s == Sky.PARTLY -> "nice"
            else -> "meh"
        }
    }

    fun describe(code: Int): String = when (code) {
        0 -> "Clear"
        1 -> "Mostly clear"
        2 -> "Partly cloudy"
        3 -> "Overcast"
        45, 48 -> "Fog"
        51, 53, 55 -> "Drizzle"
        56, 57 -> "Freezing drizzle"
        61 -> "Light rain"
        63 -> "Rain"
        65 -> "Heavy rain"
        66, 67 -> "Freezing rain"
        71 -> "Light snow"
        73 -> "Snow"
        75 -> "Heavy snow"
        77 -> "Snow grains"
        80, 81 -> "Showers"
        82 -> "Violent showers"
        85, 86 -> "Snow showers"
        95 -> "Thunderstorm"
        96, 99 -> "Thunderstorm with hail"
        else -> "Weather"
    }

    data class Weather(
        val temp: Double,
        val feels: Double,
        val high: Double,
        val low: Double,
        val wind: Double,
        val gusts: Double,
        val pop: Int,
        val uv: Double,
        val vis: Double,
        val code: Int,
        val isDay: Boolean,
    )

    data class Units(val fahrenheit: Boolean, val wind: String) {
        fun t(c: Double) = if (fahrenheit) c * 9 / 5 + 32 else c
        fun deg(c: Double) = "${t(c).roundToInt()}°"
        fun speed(kmh: Double) = when (wind) {
            "mph" -> "${(kmh * 0.621371).roundToInt()} mph"
            "ms" -> String.format("%.1f m/s", kmh / 3.6)
            else -> "${kmh.roundToInt()} km/h"
        }
        fun distance(m: Double): String = if (fahrenheit) {
            val mi = m / 1609.34
            if (mi >= 10) "${mi.roundToInt()} mi" else String.format("%.1f mi", mi)
        } else {
            val km = m / 1000
            if (km >= 10) "${km.roundToInt()} km" else String.format("%.1f km", km)
        }
    }

    fun fill(s: String, w: Weather, u: Units, city: String): String = s
        .replace("{temp}", u.deg(w.temp))
        .replace("{feels}", u.deg(w.feels))
        .replace("{high}", u.deg(w.high))
        .replace("{low}", u.deg(w.low))
        .replace("{wind}", u.speed(w.wind))
        .replace("{gusts}", u.speed(w.gusts))
        .replace("{pop}", "${w.pop}")
        .replace("{uv}", "${w.uv.roundToInt()}")
        .replace("{vis}", u.distance(w.vis))
        .replace("{city}", city)

    fun icon(code: Int, isDay: Boolean): Pair<Int, Int> = when (sky(code)) {
        Sky.CLEAR -> if (isDay) R.drawable.ic_w_sun to SUN else R.drawable.ic_w_moon to MOON
        Sky.PARTLY -> if (isDay) R.drawable.ic_w_partly to SUN else R.drawable.ic_w_partly_night to MOON
        Sky.CLOUDY -> R.drawable.ic_w_cloud to GRAY
        Sky.FOG -> R.drawable.ic_w_fog to GRAY
        Sky.DRIZZLE -> R.drawable.ic_w_drizzle to RAIN
        Sky.RAIN -> R.drawable.ic_w_rain to RAIN
        Sky.SNOW -> R.drawable.ic_w_snow to SNOW
        Sky.STORM -> R.drawable.ic_w_storm to STORM
    }

    private const val SUN = 0xFFF2A516.toInt()
    private const val MOON = 0xFFB9C4D6.toInt()
    private const val GRAY = 0xFF8A96A3.toInt()
    private const val RAIN = 0xFF4A8FD9.toInt()
    private const val SNOW = 0xFF8FC6E8.toInt()
    private const val STORM = 0xFFE0B13A.toInt()
}
