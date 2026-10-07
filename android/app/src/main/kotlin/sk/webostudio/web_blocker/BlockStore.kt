package sk.webostudio.web_blocker

import android.content.Context
import android.content.SharedPreferences

/**
 * Spoločné úložisko pre aplikáciu, VPN službu aj službu prístupnosti.
 * Položka zoznamu má tvar "domena.sk" alebo "domena.sk/cesta".
 * Položky aj aplikácie sa dajú dočasne vypnúť bez odstránenia zo zoznamu.
 */
object BlockStore {
    private const val PREFS = "blocker"
    private const val KEY_ENTRIES = "entries"
    private const val KEY_APPS = "apps"
    private const val KEY_DISABLED_ENTRIES = "disabled_entries"
    private const val KEY_DISABLED_APPS = "disabled_apps"
    private const val KEY_VPN = "vpn_enabled"
    private const val KEY_ACCESSIBILITY = "accessibility_enabled"
    private const val KEY_BLOCKED_COUNT = "blocked_count"
    private const val SETTING_PREFIX = "setting_"

    @Volatile
    private var cache: List<String>? = null

    @Volatile
    private var appsCache: Set<String>? = null

    @Volatile
    private var disabledEntriesCache: Set<String>? = null

    @Volatile
    private var disabledAppsCache: Set<String>? = null

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---------------- stránky ----------------

    fun entries(context: Context): List<String> {
        cache?.let { return it }
        val loaded = prefs(context).getString(KEY_ENTRIES, "")!!
            .split('\n')
            .filter { it.isNotBlank() }
        cache = loaded
        return loaded
    }

    fun setEntries(context: Context, entries: List<String>) {
        val normalized = entries.mapNotNull { normalize(it) }.distinct()
        prefs(context).edit().putString(KEY_ENTRIES, normalized.joinToString("\n")).apply()
        cache = normalized
        // Vypnuté položky, ktoré už v zozname nie sú, zabudneme.
        setDisabledEntries(context, disabledEntries(context).filter { it in normalized })
    }

    fun disabledEntries(context: Context): Set<String> {
        disabledEntriesCache?.let { return it }
        val loaded = prefs(context).getStringSet(KEY_DISABLED_ENTRIES, emptySet())!!.toSet()
        disabledEntriesCache = loaded
        return loaded
    }

    fun setDisabledEntries(context: Context, disabled: Collection<String>) {
        val set = disabled.toSet()
        prefs(context).edit().putStringSet(KEY_DISABLED_ENTRIES, set).apply()
        disabledEntriesCache = set
    }

    /** Stránky, ktoré sa majú naozaj blokovať (bez dočasne vypnutých). */
    private fun activeEntries(context: Context): List<String> {
        val disabled = disabledEntries(context)
        return entries(context).filter { it !in disabled }
    }

    // ---------------- aplikácie ----------------

    /** Názvy balíkov zablokovaných aplikácií (napr. com.instagram.android). */
    fun apps(context: Context): Set<String> {
        appsCache?.let { return it }
        val loaded = prefs(context).getStringSet(KEY_APPS, emptySet())!!.toSet()
        appsCache = loaded
        return loaded
    }

    fun setApps(context: Context, apps: List<String>) {
        val set = apps.filter { it.isNotBlank() && it != context.packageName }.toSet()
        prefs(context).edit().putStringSet(KEY_APPS, set).apply()
        appsCache = set
        setDisabledApps(context, disabledApps(context).filter { it in set })
    }

    fun disabledApps(context: Context): Set<String> {
        disabledAppsCache?.let { return it }
        val loaded = prefs(context).getStringSet(KEY_DISABLED_APPS, emptySet())!!.toSet()
        disabledAppsCache = loaded
        return loaded
    }

    fun setDisabledApps(context: Context, disabled: Collection<String>) {
        val set = disabled.toSet()
        prefs(context).edit().putStringSet(KEY_DISABLED_APPS, set).apply()
        disabledAppsCache = set
    }

    fun isAppBlocked(context: Context, packageName: String) =
        packageName in apps(context) && packageName !in disabledApps(context)

    // ---------------- stav a nastavenia ----------------

    fun isVpnEnabled(context: Context) = prefs(context).getBoolean(KEY_VPN, false)
    fun setVpnEnabled(context: Context, value: Boolean) =
        prefs(context).edit().putBoolean(KEY_VPN, value).apply()

    fun isAccessibilityEnabled(context: Context) = prefs(context).getBoolean(KEY_ACCESSIBILITY, false)
    fun setAccessibilityEnabled(context: Context, value: Boolean) =
        prefs(context).edit().putBoolean(KEY_ACCESSIBILITY, value).apply()

    fun blockedCount(context: Context) = prefs(context).getInt(KEY_BLOCKED_COUNT, 0)
    fun incrementBlocked(context: Context) {
        val p = prefs(context)
        p.edit().putInt(KEY_BLOCKED_COUNT, p.getInt(KEY_BLOCKED_COUNT, 0) + 1).apply()
    }

    /** Nastavenia aplikácie (jazyk, téma, heslo…) ako textové hodnoty. */
    fun settings(context: Context): Map<String, String> =
        prefs(context).all
            .filterKeys { it.startsWith(SETTING_PREFIX) }
            .mapKeys { it.key.removePrefix(SETTING_PREFIX) }
            .mapValues { it.value.toString() }

    fun setSetting(context: Context, key: String, value: String?) {
        val edit = prefs(context).edit()
        if (value == null) edit.remove(SETTING_PREFIX + key) else edit.putString(SETTING_PREFIX + key, value)
        edit.apply()
    }

    /** "sk" alebo "en" – podľa nastavenia v aplikácii, predvolene slovenčina. */
    fun language(context: Context): String = settings(context)["language"] ?: "sk"

    // ---------------- porovnávanie adries ----------------

    /** "https://www.Facebook.com/" -> "facebook.com", "youtube.com/shorts/" -> "youtube.com/shorts" */
    fun normalize(raw: String): String? {
        var s = raw.trim().lowercase()
        s = s.substringAfter("://")
        s = s.substringBefore('?').substringBefore('#')
        if (s.startsWith("www.")) s = s.removePrefix("www.")
        s = s.trimEnd('/')
        val host = s.substringBefore('/').substringBefore(':')
        if (host.isEmpty() || !host.contains('.')) return null
        val path = if (s.contains('/')) s.substring(s.indexOf('/')) else ""
        return host + path
    }

    /** Blokovanie podľa domény (VPN) – cesta sa ignoruje, lebo DNS vidí iba doménu. */
    fun isHostBlocked(context: Context, host: String): Boolean {
        val h = host.lowercase().trimEnd('.')
        return activeEntries(context).any { entry ->
            if (entry.contains('/')) return@any false
            h == entry || h.endsWith(".$entry")
        }
    }

    /** Blokovanie podľa celej adresy (prístupnosť) – podporuje aj cesty. */
    fun isUrlBlocked(context: Context, url: String): Boolean {
        val target = normalize(url) ?: return false
        val host = target.substringBefore('/')
        val path = if (target.contains('/')) target.substring(target.indexOf('/')) else ""
        return activeEntries(context).any { entry ->
            val eHost = entry.substringBefore('/')
            val ePath = if (entry.contains('/')) entry.substring(entry.indexOf('/')) else ""
            val hostMatches = host == eHost || host.endsWith(".$eHost")
            hostMatches && (ePath.isEmpty() || path == ePath || path.startsWith("$ePath/"))
        }
    }
}
