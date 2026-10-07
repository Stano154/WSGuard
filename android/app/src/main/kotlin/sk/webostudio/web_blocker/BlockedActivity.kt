package sk.webostudio.web_blocker

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/** Obrazovka, ktorá sa zobrazí namiesto zablokovanej stránky alebo aplikácie. */
class BlockedActivity : Activity() {

    companion object {
        const val EXTRA_URL = "url"
        const val EXTRA_KIND = "kind"
        const val KIND_SITE = "site"
        const val KIND_APP = "app"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val name = intent.getStringExtra(EXTRA_URL) ?: ""
        val isApp = intent.getStringExtra(EXTRA_KIND) == KIND_APP
        val en = BlockStore.language(this) == "en"
        val titleText = when {
            en && isApp -> "App is blocked"
            en -> "Site is blocked"
            isApp -> "Aplikácia je zablokovaná"
            else -> "Stránka je zablokovaná"
        }
        val hintText = when {
            en && isApp -> "This app is on your block list.\nMaybe do something else instead 🙂"
            en -> "This site is on your block list.\nMaybe do something else instead 🙂"
            isApp -> "Táto aplikácia je v tvojom zozname blokovaných.\nVenuj sa radšej niečomu inému 🙂"
            else -> "Táto stránka je v tvojom zozname blokovaných.\nVenuj sa radšej niečomu inému 🙂"
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#04397F"), Color.parseColor("#021A45"))
            )
        }

        val logo = ImageView(this).apply {
            setImageResource(R.drawable.wsguard_mark)
            clipToOutline = true
            outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
            background = GradientDrawable().apply { cornerRadius = dp(28).toFloat() }
            elevation = dp(8).toFloat()
        }
        val title = TextView(this).apply {
            text = titleText
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(28), 0, dp(8))
        }
        val subtitle = TextView(this).apply {
            text = name
            setTextColor(Color.parseColor("#7CC4FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val hint = TextView(this).apply {
            text = hintText
            setTextColor(Color.parseColor("#A9BEDF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, dp(40))
        }
        val button = Button(this).apply {
            text = if (en) "Got it" else "Rozumiem"
            isAllCaps = false
            setTextColor(Color.parseColor("#04397F"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                cornerRadius = dp(28).toFloat()
                setColor(Color.WHITE)
            }
            setPadding(dp(40), dp(14), dp(40), dp(14))
            setOnClickListener { goHome() }
        }

        root.addView(logo, LinearLayout.LayoutParams(dp(112), dp(112)))
        root.addView(title)
        root.addView(subtitle)
        root.addView(hint)
        root.addView(button, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ))
        setContentView(root)
    }

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() = goHome()

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics
    ).toInt()
}
