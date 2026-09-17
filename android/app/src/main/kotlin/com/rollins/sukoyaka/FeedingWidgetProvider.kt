package com.rollins.sukoyaka

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FeedingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.feeding_widget_layout).apply {
                val lastFedText = widgetData.getString("last_fed_text", "No feedings logged yet")
                val nextDueText = widgetData.getString("next_due_text", "")
                setTextViewText(R.id.last_fed_text, lastFedText)
                setTextViewText(R.id.next_due_text, nextDueText)

                val openAppIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.info_container, openAppIntent)

                val quickLogIntent = PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, QuickLogActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.quick_log_button, quickLogIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
