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
        const val KIND_PROTECTED = "protected"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val name = intent.getStringExtra(EXTRA_URL) ?: ""
        val kind = intent.getStringExtra(EXTRA_KIND)
        val isApp = kind == KIND_APP
        val isProtected = kind == KIND_PROTECTED
        val en = BlockStore.language(this) == "en"
        val titleText = when {
            isProtected && en -> "WSGuard is protected"
            isProtected -> "WSGuard je chránený"
            en && isApp -> "App is blocked"
            en -> "Site is blocked"
            isApp -> "Aplikácia je zablokovaná"
            else -> "Stránka je zablokovaná"
        }
        // Koniec zobrazíme v čase telefónu (uložený je v dôveryhodnom čase).
        val lockedUntil = BlockStore.lockedUntil(this).let { if (it > 0) it + BlockStore.skew(this) else 0L }
        val untilText = if (lockedUntil > 0) {
            val pattern = if (en) "MMM d, HH:mm" else "d. M. HH:mm"
            java.text.SimpleDateFormat(pattern, if (en) java.util.Locale.ENGLISH else java.util.Locale("sk"))
                .format(java.util.Date(lockedUntil))
        } else ""
        val hintText = when {
            isProtected && lockedUntil > 0 && en ->
                "Timed blocking is running until $untilText.\nWSGuard can't be turned off or uninstalled until then."
            isProtected && lockedUntil > 0 ->
                "Časové blokovanie beží do $untilText.\nDovtedy sa WSGuard nedá vypnúť ani odinštalovať."
            isProtected && en ->
                "Uninstall protection is on.\nYou can turn it off in WSGuard settings with your password."
            isProtected ->
                "Ochrana proti odinštalovaniu je zapnutá.\nVypnúť ju môžeš v nastaveniach WSGuard heslom."
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
