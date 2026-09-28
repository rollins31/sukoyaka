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

                setOnClickPendingIntent(R.id.feed_action_button, quickLogPendingIntent(context, "feeding", 1))
                setOnClickPendingIntent(R.id.sleep_action_button, quickLogPendingIntent(context, "sleep", 2))
                setOnClickPendingIntent(R.id.diaper_action_button, quickLogPendingIntent(context, "diaper", 3))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** [requestCode] must differ per log type — PendingIntents with equal
     *  Intent filters (action/component, ignoring extras) collapse into one,
     *  which would make every widget button trigger whichever type was
     *  wired up last. */
    private fun quickLogPendingIntent(context: Context, logType: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, QuickLogActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("logType", logType)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
