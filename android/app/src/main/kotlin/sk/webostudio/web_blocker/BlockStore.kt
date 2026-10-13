package sk.webostudio.web_blocker

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs

/**
 * Spoločné úložisko pre aplikáciu, VPN službu aj službu prístupnosti.
 *
 * Pravidlá majú kľúče "site:<domena>", "app:<balik>" a "list:<id>".
 * Pravidlo je buď trvalé (dá sa vypnúť vypínačom), alebo časové – to sa do svojho konca
 * nedá vypnúť ani odstrániť, iba dočasne odblokovať (s denným limitom).
 * Kým beží akékoľvek časové blokovanie, je zamknutá aj celá ochrana.
 */
object BlockStore {
    private const val PREFS = "blocker"
    private const val KEY_ENTRIES = "entries"
    private const val KEY_APPS = "apps"
    private const val KEY_DISABLED_ENTRIES = "disabled_entries"
    private const val KEY_DISABLED_APPS = "disabled_apps"
    private const val KEY_DISABLED_LISTS = "disabled_lists"
    private const val KEY_LISTS = "lists"
    private const val KEY_TIMERS = "timers"
    private const val KEY_PAUSES = "pauses"
    private const val KEY_PAUSE_USAGE = "pause_usage"
    private const val KEY_VPN = "vpn_enabled"
    private const val KEY_ACCESSIBILITY = "accessibility_enabled"
    private const val KEY_UNINSTALL_PROTECTION = "uninstall_protection"
    private const val KEY_BLOCKED_COUNT = "blocked_count"
    private const val SETTING_PREFIX = "setting_"

    const val DEFAULT_UNBLOCK_MINUTES = 15
    const val DEFAULT_UNBLOCK_PER_DAY = 3

    fun siteKey(entry: String) = "site:$entry"
    fun appKey(pkg: String) = "app:$pkg"
    fun listKey(id: String) = "list:$id"

    class BlockList(
        val id: String,
        val name: String,
        val emoji: String,
        val sites: List<String>,
        val apps: List<String>,
    ) {
        fun toJson() = JSONObject()
            .put("id", id).put("name", name).put("emoji", emoji)
            .put("sites", JSONArray(sites)).put("apps", JSONArray(apps))

        fun toMap(): Map<String, Any> =
            mapOf("id" to id, "name" to name, "emoji" to emoji, "sites" to sites, "apps" to apps)

        companion object {
            fun fromJson(o: JSONObject) = BlockList(
                id = o.getString("id"),
                name = o.optString("name"),
                emoji = o.optString("emoji", "📋"),
                sites = o.optJSONArray("sites").toStringList(),
                apps = o.optJSONArray("apps").toStringList(),
            )
        }
    }

    private fun JSONArray?.toStringList(): List<String> =
        if (this == null) emptyList() else List(length()) { getString(it) }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---------------- cache aktívnych pravidiel ----------------

    /** Čo sa práve blokuje – počíta sa raz a platí do najbližšej časovej zmeny. */
    class Active(val sites: List<String>, val apps: Set<String>, val validUntil: Long)

    @Volatile
    private var activeCache: Active? = null

    private fun invalidate() {
        activeCache = null
    }

    fun active(context: Context): Active {
        val now = now(context)
        activeCache?.let { if (now < it.validUntil) return it }

        val timers = timers(context)
        val pauses = pauses(context)
        fun ruleActive(key: String, disabled: Boolean): Boolean {
            val until = timers[key]
            if (until != null) return until > now && (pauses[key] ?: 0L) <= now
            return !disabled
        }

        val disabledEntries = disabledEntries(context)
        val disabledApps = disabledApps(context)
        val disabledLists = disabledLists(context)
        val sites = entries(context).filter { ruleActive(siteKey(it), it in disabledEntries) }.toMutableList()
        val apps = apps(context).filter { ruleActive(appKey(it), it in disabledApps) }.toMutableSet()
        for (list in lists(context)) {
            if (ruleActive(listKey(list.id), list.id in disabledLists)) {
                sites += list.sites
                apps += list.apps
            }
        }

        // Výsledok platí do najbližšieho konca časovača alebo dočasného odblokovania.
        val next = (timers.values + pauses.values).filter { it > now }.minOrNull() ?: Long.MAX_VALUE
        val result = Active(sites.distinct(), apps, minOf(next, now + 60_000))
        activeCache = result
        return result
    }

    // ---------------- stránky ----------------

    @Volatile
    private var cache: List<String>? = null

    fun entries(context: Context): List<String> {
        cache?.let { return it }
        val loaded = prefs(context).getString(KEY_ENTRIES, "")!!
            .split('\n')
            .filter { it.isNotBlank() }
        cache = loaded
        return loaded
    }

    fun setEntries(context: Context, entries: List<String>) {
        val normalized = entries.mapNotNull { normalize(it) }.toMutableList()
        // Stránky s bežiacim časovým blokovaním sa nedajú odstrániť.
        entries(context).filter { isTimed(context, siteKey(it)) && it !in normalized }
            .forEach { normalized += it }
        val result = normalized.distinct()
        prefs(context).edit().putString(KEY_ENTRIES, result.joinToString("\n")).apply()
        cache = result
        setDisabledEntries(context, disabledEntries(context).filter { it in result })
        invalidate()
    }

    @Volatile
    private var disabledEntriesCache: Set<String>? = null

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
        invalidate()
    }

    // ---------------- aplikácie ----------------

    @Volatile
    private var appsCache: Set<String>? = null

    /** Názvy balíkov zablokovaných aplikácií (napr. com.instagram.android). */
    fun apps(context: Context): Set<String> {
        appsCache?.let { return it }
        val loaded = prefs(context).getStringSet(KEY_APPS, emptySet())!!.toSet()
        appsCache = loaded
        return loaded
    }

    fun setApps(context: Context, apps: List<String>) {
        val set = apps.filter { it.isNotBlank() && it != context.packageName }.toMutableSet()
        apps(context).filter { isTimed(context, appKey(it)) }.forEach { set += it }
        prefs(context).edit().putStringSet(KEY_APPS, set).apply()
        appsCache = set
        setDisabledApps(context, disabledApps(context).filter { it in set })
        invalidate()
    }

    @Volatile
    private var disabledAppsCache: Set<String>? = null

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
        invalidate()
    }

    fun isAppBlocked(context: Context, packageName: String) = packageName in active(context).apps

    // ---------------- zoznamy ----------------

    @Volatile
    private var listsCache: List<BlockList>? = null

    fun lists(context: Context): List<BlockList> {
        listsCache?.let { return it }
        val json = prefs(context).getString(KEY_LISTS, "[]")!!
        val arr = try {
            JSONArray(json)
        } catch (_: Exception) {
            JSONArray()
        }
        val loaded = List(arr.length()) { BlockList.fromJson(arr.getJSONObject(it)) }
        listsCache = loaded
        return loaded
    }

    /** Uloží zoznamy. Zoznam s bežiacim časovým blokovaním nemôže prísť o položky ani zaniknúť. */
    fun setLists(context: Context, newLists: List<BlockList>) {
        val result = newLists.toMutableList()
        for (old in lists(context)) {
            if (!isTimed(context, listKey(old.id))) continue
            val i = result.indexOfFirst { it.id == old.id }
            if (i < 0) {
                result += old
            } else {
                val n = result[i]
                result[i] = BlockList(
                    n.id, n.name, n.emoji,
                    (n.sites + old.sites).distinct(),
                    (n.apps + old.apps).distinct(),
                )
            }
        }
        val arr = JSONArray()
        result.forEach { arr.put(it.toJson()) }
        prefs(context).edit().putString(KEY_LISTS, arr.toString()).apply()
        listsCache = result
        val ids = result.map { it.id }.toSet()
        setDisabledLists(context, disabledLists(context).filter { it in ids })
        invalidate()
    }

    @Volatile
    private var disabledListsCache: Set<String>? = null

    fun disabledLists(context: Context): Set<String> {
        disabledListsCache?.let { return it }
        val loaded = prefs(context).getStringSet(KEY_DISABLED_LISTS, emptySet())!!.toSet()
        disabledListsCache = loaded
        return loaded
    }

    fun setDisabledLists(context: Context, disabled: Collection<String>) {
        val set = disabled.toSet()
        prefs(context).edit().putStringSet(KEY_DISABLED_LISTS, set).apply()
        disabledListsCache = set
        invalidate()
    }

    // ---------------- dôveryhodný čas ----------------
    //
    // Časové blokovanie sa nesmie dať obísť posunutím dátumu/času v nastaveniach telefónu.
    // Sledujeme rozdiel "systémový čas − čas od zapnutia telefónu" (elapsedRealtime sa zmenou
    // hodín nemení). Keď sa rozdiel náhle zmení, niekto posunul hodiny – posun si zapamätáme
    // (skew) a od systémového času ho odpočítavame. Všetky časy v úložisku sú v tomto
    // "dôveryhodnom" čase; aplikácii sa posielajú prepočítané späť na čas telefónu.

    private const val KEY_SKEW = "clock_skew"
    private const val KEY_CLOCK_BASE = "clock_base"
    private const val KEY_CLOCK_BOOT = "clock_boot"
    private const val KEY_CLOCK_ELAPSED = "clock_elapsed"

    private fun bootCount(context: Context): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
        } else -1

    private fun autoTimeOn(context: Context) =
        Settings.Global.getInt(context.contentResolver, Settings.Global.AUTO_TIME, 0) == 1

    /** Zistí, či sa od poslednej kontroly posunuli hodiny telefónu. */
    @Synchronized
    fun checkClock(context: Context) {
        val p = prefs(context)
        val elapsed = SystemClock.elapsedRealtime()
        val base = System.currentTimeMillis() - elapsed
        val boot = bootCount(context)
        val rebooted = !p.contains(KEY_CLOCK_BASE) ||
            boot != p.getInt(KEY_CLOCK_BOOT, -1) ||
            elapsed < p.getLong(KEY_CLOCK_ELAPSED, 0L)
        if (rebooted) {
            // Po reštarte sa čas od zapnutia nuluje – začneme sledovať odznova.
            // Ak sa čas nastavuje automaticky zo siete, je spoľahlivý a starý posun zahodíme.
            val edit = p.edit()
                .putLong(KEY_CLOCK_BASE, base)
                .putInt(KEY_CLOCK_BOOT, boot)
                .putLong(KEY_CLOCK_ELAPSED, elapsed)
            if (autoTimeOn(context)) edit.putLong(KEY_SKEW, 0L)
            edit.apply()
            invalidate()
            return
        }
        val diff = base - p.getLong(KEY_CLOCK_BASE, base)
        if (abs(diff) > 2_000) {
            p.edit()
                .putLong(KEY_SKEW, p.getLong(KEY_SKEW, 0L) + diff)
                .putLong(KEY_CLOCK_BASE, base)
                .putLong(KEY_CLOCK_ELAPSED, elapsed)
                .apply()
            invalidate()
        } else if (elapsed - p.getLong(KEY_CLOCK_ELAPSED, 0L) > 60_000) {
            p.edit().putLong(KEY_CLOCK_ELAPSED, elapsed).apply()
        }
    }

    /** O koľko ms sú hodiny telefónu posunuté oproti dôveryhodnému času. */
    fun skew(context: Context): Long {
        checkClock(context)
        return prefs(context).getLong(KEY_SKEW, 0L)
    }

    /** Dôveryhodný "teraz" – posunutie hodín v telefóne naň nemá vplyv. */
    fun now(context: Context): Long = System.currentTimeMillis() - skew(context)

    // ---------------- časové blokovanie ----------------

    private fun readMap(context: Context, key: String): MutableMap<String, Long> {
        val json = try {
            JSONObject(prefs(context).getString(key, "{}")!!)
        } catch (_: Exception) {
            JSONObject()
        }
        return json.keys().asSequence().associateWith { json.getLong(it) }.toMutableMap()
    }

    private fun writeMap(context: Context, key: String, map: Map<String, Long>) {
        prefs(context).edit().putString(key, JSONObject(map as Map<*, *>).toString()).apply()
        invalidate()
    }

    /** Konce časových blokovaní (kľúč pravidla -> čas v ms). */
    fun timers(context: Context): Map<String, Long> = readMap(context, KEY_TIMERS)

    /** Konce dočasných odblokovaní (kľúč pravidla -> čas v ms). */
    fun pauses(context: Context): Map<String, Long> = readMap(context, KEY_PAUSES)

    fun isTimed(context: Context, key: String) =
        (timers(context)[key] ?: 0L) > now(context)

    /** Do kedy je zamknutá ochrana (0 = nie je). */
    fun lockedUntil(context: Context): Long {
        val now = now(context)
        return timers(context).values.filter { it > now }.maxOrNull() ?: 0L
    }

    fun isLocked(context: Context) = lockedUntil(context) > now(context)

    /** Nastaví časové blokovanie. Bežiace blokovanie sa dá iba predĺžiť, nie skrátiť. */
    fun setTimer(context: Context, key: String, until: Long) {
        val now = now(context)
        val timers = readMap(context, KEY_TIMERS)
        val current = (timers[key] ?: 0L).takeIf { it > now } ?: 0L
        if (until <= current) return
        val wasDisabled = isDisabled(context, key)

        // Záznam pre zrušenie do 10 minút. Ak predlžujeme počas bežiacej lehoty, ostáva
        // pôvodná lehota aj pôvodný stav – opakovaným predlžovaním sa lehota nedá natiahnuť.
        val meta = readMeta(context)
        val old = meta.optJSONObject(key)
        if (old == null || old.getLong("start") + CANCEL_WINDOW <= now) {
            meta.put(
                key,
                JSONObject().put("start", now).put("prevUntil", current).put("prevDisabled", wasDisabled),
            )
            prefs(context).edit().putString(KEY_TIMER_META, meta.toString()).apply()
        }

        timers[key] = until
        writeMap(context, KEY_TIMERS, timers)
        // Počas časového blokovania sa trvalý vypínač ignoruje – po skončení ho nastaví housekeeping.
        setDisabled(context, key, false)
    }

    // ---------------- zrušenie do 10 minút ----------------

    /** Do koľkých minút od spustenia sa dá časové blokovanie ešte zrušiť (omyl, rozmyslenie si). */
    const val CANCEL_WINDOW = 10 * 60_000L
    private const val KEY_TIMER_META = "timer_meta"

    private fun readMeta(context: Context): JSONObject = try {
        JSONObject(prefs(context).getString(KEY_TIMER_META, "{}")!!)
    } catch (_: Exception) {
        JSONObject()
    }

    private fun isDisabled(context: Context, key: String): Boolean {
        val id = key.substringAfter(':')
        return when (key.substringBefore(':')) {
            "site" -> id in disabledEntries(context)
            "app" -> id in disabledApps(context)
            "list" -> id in disabledLists(context)
            else -> false
        }
    }

    private fun setDisabled(context: Context, key: String, disabled: Boolean) {
        val id = key.substringAfter(':')
        fun Set<String>.with() = if (disabled) this + id else this - id
        when (key.substringBefore(':')) {
            "site" -> setDisabledEntries(context, disabledEntries(context).with())
            "app" -> setDisabledApps(context, disabledApps(context).with())
            "list" -> setDisabledLists(context, disabledLists(context).with())
        }
    }

    /** Do kedy (dôveryhodný čas) sa dá časové blokovanie zrušiť – iba pre bežiace lehoty. */
    fun cancelDeadlines(context: Context): Map<String, Long> {
        val now = now(context)
        val timers = timers(context)
        val meta = readMeta(context)
        return meta.keys().asSequence()
            .filter { (timers[it] ?: 0L) > now }
            .associateWith { meta.getJSONObject(it).getLong("start") + CANCEL_WINDOW }
            .filterValues { it > now }
    }

    /**
     * Zruší časové blokovanie spustené pred menej ako 10 minútami – položka sa vráti do stavu
     * pred spustením (pri predĺžení na pôvodný koniec). Vráti false, ak je už neskoro.
     */
    fun cancelTimer(context: Context, key: String): Boolean {
        val now = now(context)
        val meta = readMeta(context)
        val m = meta.optJSONObject(key) ?: return false
        if (m.getLong("start") + CANCEL_WINDOW <= now || !isTimed(context, key)) return false

        val prevUntil = m.optLong("prevUntil", 0L)
        val timers = readMap(context, KEY_TIMERS)
        if (prevUntil > now) timers[key] = prevUntil else timers.remove(key)
        writeMap(context, KEY_TIMERS, timers)
        writeMap(context, KEY_PAUSES, readMap(context, KEY_PAUSES).filterKeys { it != key || prevUntil > now })
        if (prevUntil <= now) setDisabled(context, key, m.optBoolean("prevDisabled", false))

        meta.remove(key)
        prefs(context).edit().putString(KEY_TIMER_META, meta.toString()).apply()
        return true
    }

    class PauseResult(val ok: Boolean, val reason: String? = null)

    fun unblockMinutes(context: Context) =
        settings(context)["unblockMinutes"]?.toIntOrNull() ?: DEFAULT_UNBLOCK_MINUTES

    /** Počet dočasných odblokovaní za deň (0 = nikdy). Staré "bez limitu" (-1) sa už nepovoľuje. */
    fun unblockPerDay(context: Context): Int {
        val v = settings(context)["unblockPerDay"]?.toIntOrNull() ?: DEFAULT_UNBLOCK_PER_DAY
        return if (v < 0) DEFAULT_UNBLOCK_PER_DAY else v
    }

    private fun today(context: Context) = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now(context)))

    fun pauseUsedToday(context: Context, key: String): Int {
        val usage = try {
            JSONObject(prefs(context).getString(KEY_PAUSE_USAGE, "{}")!!)
        } catch (_: Exception) {
            JSONObject()
        }
        val value = usage.optString(key, "")
        return if (value.startsWith(today(context) + "|")) value.substringAfter('|').toIntOrNull() ?: 0 else 0
    }

    /** Dočasne odblokuje časové pravidlo (napr. na 15 min), najviac N-krát za deň. */
    fun pause(context: Context, key: String): PauseResult {
        if (!isTimed(context, key)) return PauseResult(false, "notTimed")
        val limit = unblockPerDay(context)
        val used = pauseUsedToday(context, key)
        if (used >= limit) return PauseResult(false, "limit")

        val pauses = readMap(context, KEY_PAUSES)
        pauses[key] = now(context) + unblockMinutes(context) * 60_000L
        writeMap(context, KEY_PAUSES, pauses)

        val usage = try {
            JSONObject(prefs(context).getString(KEY_PAUSE_USAGE, "{}")!!)
        } catch (_: Exception) {
            JSONObject()
        }
        usage.put(key, "${today(context)}|${used + 1}")
        prefs(context).edit().putString(KEY_PAUSE_USAGE, usage.toString()).apply()
        return PauseResult(true)
    }

    /**
     * Upratovanie po skončených časovačoch: pravidlo prejde do stavu "Povolené"
     * (ostane v zozname) a vráti sa zoznam práve skončených kľúčov.
     */
    fun housekeeping(context: Context): List<String> {
        val now = now(context)
        val timers = readMap(context, KEY_TIMERS)
        val expired = timers.filterValues { it <= now }.keys.toList()
        if (expired.isEmpty()) {
            val pauses = readMap(context, KEY_PAUSES)
            if (pauses.values.any { it <= now }) writeMap(context, KEY_PAUSES, pauses.filterValues { it > now })
            return emptyList()
        }
        expired.forEach { timers.remove(it) }
        writeMap(context, KEY_TIMERS, timers)
        val meta = readMeta(context)
        expired.forEach { meta.remove(it) }
        prefs(context).edit().putString(KEY_TIMER_META, meta.toString()).apply()
        writeMap(context, KEY_PAUSES, readMap(context, KEY_PAUSES).filterKeys { it !in expired }.filterValues { it > now })
        for (key in expired) {
            val id = key.substringAfter(':')
            when (key.substringBefore(':')) {
                "site" -> if (id in entries(context)) setDisabledEntries(context, disabledEntries(context) + id)
                "app" -> if (id in apps(context)) setDisabledApps(context, disabledApps(context) + id)
                "list" -> if (lists(context).any { it.id == id }) setDisabledLists(context, disabledLists(context) + id)
            }
        }
        return expired
    }

    // ---------------- stav a nastavenia ----------------

    fun isVpnEnabled(context: Context) = prefs(context).getBoolean(KEY_VPN, false)
    fun setVpnEnabled(context: Context, value: Boolean) =
        prefs(context).edit().putBoolean(KEY_VPN, value).apply()

    fun isAccessibilityEnabled(context: Context) = prefs(context).getBoolean(KEY_ACCESSIBILITY, false)
    fun setAccessibilityEnabled(context: Context, value: Boolean) =
        prefs(context).edit().putBoolean(KEY_ACCESSIBILITY, value).apply()

    fun isUninstallProtection(context: Context) = prefs(context).getBoolean(KEY_UNINSTALL_PROTECTION, false)
    fun setUninstallProtection(context: Context, value: Boolean) =
        prefs(context).edit().putBoolean(KEY_UNINSTALL_PROTECTION, value).apply()

    /** Krátka výnimka pre strážcu, keď nastavenia otvára samotný WSGuard (napr. aktivácia ochrany). */
    @Volatile
    var guardBypassUntil = 0L

    /** Majú sa strážiť systémové nastavenia WSGuard (odinštalovanie, vypnutie služieb)? */
    fun guardSettings(context: Context) =
        System.currentTimeMillis() > guardBypassUntil &&
            (isUninstallProtection(context) || isLocked(context))

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

    /** Nastavenia dočasného odblokovania sa počas časového blokovania meniť nedajú. */
    private val LOCKED_SETTINGS = setOf("unblockMinutes", "unblockPerDay")

    fun setSetting(context: Context, key: String, value: String?): Boolean {
        if (key in LOCKED_SETTINGS && isLocked(context)) return false
        val edit = prefs(context).edit()
        if (value == null) edit.remove(SETTING_PREFIX + key) else edit.putString(SETTING_PREFIX + key, value)
        edit.apply()
        return true
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
        return active(context).sites.any { entry ->
            if (entry.contains('/')) return@any false
            h == entry || h.endsWith(".$entry")
        }
    }

    /** Blokovanie podľa celej adresy (prístupnosť) – podporuje aj cesty. */
    fun isUrlBlocked(context: Context, url: String): Boolean {
        val target = normalize(url) ?: return false
        val host = target.substringBefore('/')
        val path = if (target.contains('/')) target.substring(target.indexOf('/')) else ""
        return active(context).sites.any { entry ->
            val eHost = entry.substringBefore('/')
            val ePath = if (entry.contains('/')) entry.substring(entry.indexOf('/')) else ""
            val hostMatches = host == eHost || host.endsWith(".$eHost")
            hostMatches && (ePath.isEmpty() || path == ePath || path.startsWith("$ePath/"))
        }
    }
}
