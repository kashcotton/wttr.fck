package com.wttrfck.wttr_fck

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wttr.fck/system_colors")
            .setMethodCallHandler { call, result ->
                if (call.method == "get") result.success(systemColors()) else result.notImplemented()
            }
    }

    private fun color(id: Int) = getColor(id)

    private fun systemColors(): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        val out = mutableMapOf<String, Any>("seed" to color(android.R.color.system_accent1_500))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            out["light"] = roles(light = true)
            out["dark"] = roles(light = false)
        }
        return out
    }

    private fun roles(light: Boolean): Map<String, Int> {
        val r = android.R.color::class.java
        val names = listOf(
            "primary", "on_primary", "primary_container", "on_primary_container",
            "secondary", "on_secondary", "secondary_container", "on_secondary_container",
            "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
            "error", "on_error", "error_container", "on_error_container",
            "surface", "on_surface", "on_surface_variant", "surface_dim", "surface_bright",
            "surface_container_lowest", "surface_container_low", "surface_container",
            "surface_container_high", "surface_container_highest",
            "outline", "outline_variant",
        )
        val suffix = if (light) "_light" else "_dark"
        val out = mutableMapOf<String, Int>()
        for (n in names) {
            val id = runCatching { r.getField("system_$n$suffix").getInt(null) }.getOrNull() ?: continue
            val key = n.split('_').mapIndexed { i, p -> if (i == 0) p else p.replaceFirstChar { it.uppercase() } }
                .joinToString("")
            out[key] = color(id)
        }
        return out
    }
}
