package com.jaae.nutrifyngo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FitProgressWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.fit_progress_widget).apply {
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("title", "Progreso de hoy") ?: "Progreso de hoy",
                )
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("subtitle", "Fuera de la app") ?: "Fuera de la app",
                )
                setTextViewText(
                    R.id.widget_status,
                    widgetData.getString("status", "Toca para abrir NutrifynGo")
                        ?: "Toca para abrir NutrifynGo",
                )

                setTextViewText(
                    R.id.calories_value,
                    widgetData.getString("calories_value", "0 / 2000 kcal"),
                )
                setTextViewText(
                    R.id.calories_hint,
                    widgetData.getString("calories_hint", "Sin datos"),
                )
                setTextViewText(
                    R.id.water_value,
                    widgetData.getString("water_value", "0.00 / 2.00 L"),
                )
                setTextViewText(
                    R.id.water_hint,
                    widgetData.getString("water_hint", "Sin datos"),
                )
                setTextViewText(
                    R.id.steps_value,
                    widgetData.getString("steps_value", "0 / 10000"),
                )
                setTextViewText(
                    R.id.steps_hint,
                    widgetData.getString("steps_hint", "Sin datos"),
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}