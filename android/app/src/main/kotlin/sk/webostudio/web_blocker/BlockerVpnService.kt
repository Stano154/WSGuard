package sk.webostudio.web_blocker

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Lokálna VPN, ktorá zachytáva iba DNS požiadavky.
 * Systému nastaví falošný DNS server (10.111.222.2) a do tunela smeruje len premávku naň.
 * Zablokované domény dostanú odpoveď NXDOMAIN, ostatné sa prepošlú na verejný DNS.
 * Bežná premávka (web, video...) cez tunel vôbec nejde, takže nespomaľuje internet.
 */
class BlockerVpnService : VpnService() {

    companion object {
        const val ACTION_START = "sk.webostudio.web_blocker.START"
        const val ACTION_STOP = "sk.webostudio.web_blocker.STOP"
        private const val TAG = "BlockerVpn"
        private const val VPN_ADDRESS = "10.111.222.1"
        private const val VPN_DNS = "10.111.222.2"
        private val UPSTREAM_DNS = listOf("1.1.1.1", "8.8.8.8")

        @Volatile
        var isRunning = false
            private set

        fun start(context: Context) {
            context.startService(Intent(context, BlockerVpnService::class.java).setAction(ACTION_START))
        }

        fun stop(context: Context) {
            context.startService(Intent(context, BlockerVpnService::class.java).setAction(ACTION_STOP))
        }
    }

    private var tun: ParcelFileDescriptor? = null
    private var readerThread: Thread? = null
    private var executor: ExecutorService? = null
    private var output: FileOutputStream? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                shutdown()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> startTunnel()
        }
        return START_STICKY
    }

    private fun startTunnel() {
        if (tun != null) return
        val builder = Builder()
            .setSession("WSGuard")
            .addAddress(VPN_ADDRESS, 32)
            .addDnsServer(VPN_DNS)
            .addRoute(VPN_DNS, 32)
            .setBlocking(true)
        try {
            builder.addDisallowedApplication(packageName)
        } catch (_: Exception) {
        }
        val pfd = try {
            builder.establish()
        } catch (e: Exception) {
            Log.e(TAG, "Nepodarilo sa spustiť VPN", e)
            null
        } ?: run {
            // Používateľ ešte neudelil povolenie pre VPN.
            BlockStore.setVpnEnabled(this, false)
            stopSelf()
            return
        }

        tun = pfd
        output = FileOutputStream(pfd.fileDescriptor)
        executor = Executors.newFixedThreadPool(8)
        isRunning = true
        BlockStore.setVpnEnabled(this, true)

        readerThread = Thread({ readLoop(pfd) }, "dns-reader").also { it.start() }
    }

    private fun readLoop(pfd: ParcelFileDescriptor) {
        val input = FileInputStream(pfd.fileDescriptor)
        val buffer = ByteArray(32767)
        try {
            while (!Thread.currentThread().isInterrupted) {
                val length = input.read(buffer)
                if (length <= 0) continue
                val packet = buffer.copyOf(length)
                executor?.execute { handlePacket(packet) }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Čítanie z tunela skončilo: ${e.message}")
        }
    }

    private fun handlePacket(packet: ByteArray) {
        // Spracúvame len IPv4 + UDP na port 53.
        if (packet.size < 28 || (packet[0].toInt() shr 4) != 4) return
        val ihl = (packet[0].toInt() and 0x0F) * 4
        if (packet[9].toInt() != 17 || packet.size < ihl + 8) return
        val dstPort = u16(packet, ihl + 2)
        if (dstPort != 53) return

        val dns = packet.copyOfRange(ihl + 8, packet.size)
        if (dns.size < 12) return

        val question = parseQuestion(dns) ?: return
        val response = if (BlockStore.isHostBlocked(this, question.name)) {
            Log.d(TAG, "Zablokované: ${question.name}")
            BlockStore.incrementBlocked(this)
            nxDomain(dns, question.end)
        } else {
            forward(dns)
        } ?: return

        writeResponse(packet, ihl, response)
    }

    private class Question(val name: String, val end: Int)

    /** Prečíta prvú otázku z DNS správy (meno domény a koniec otázky). */
    private fun parseQuestion(dns: ByteArray): Question? {
        if (u16(dns, 4) < 1) return null
        var pos = 12
        val labels = mutableListOf<String>()
        while (pos < dns.size) {
            val len = dns[pos].toInt() and 0xFF
            if (len == 0) {
                pos++
                break
            }
            if (len and 0xC0 != 0 || pos + 1 + len > dns.size) return null
            labels.add(String(dns, pos + 1, len, Charsets.US_ASCII))
            pos += 1 + len
        }
        val end = pos + 4 // QTYPE + QCLASS
        if (end > dns.size) return null
        return Question(labels.joinToString("."), end)
    }

    private fun nxDomain(query: ByteArray, questionEnd: Int): ByteArray {
        val r = query.copyOf(questionEnd)
        val rd = r[2].toInt() and 0x01
        r[2] = (0x80 or (query[2].toInt() and 0x78) or rd).toByte() // QR=1, opcode, RD
        r[3] = 0x83.toByte() // RA=1, RCODE=3 (NXDOMAIN)
        // ANCOUNT, NSCOUNT, ARCOUNT = 0
        for (i in 6 until 12) r[i] = 0
        return r
    }

    private fun forward(query: ByteArray): ByteArray? {
        for (server in UPSTREAM_DNS) {
            try {
                DatagramSocket().use { socket ->
                    protect(socket)
                    socket.soTimeout = 4000
                    val address = InetAddress.getByName(server)
                    socket.send(DatagramPacket(query, query.size, address, 53))
                    val buf = ByteArray(4096)
                    val reply = DatagramPacket(buf, buf.size)
                    socket.receive(reply)
                    return buf.copyOf(reply.length)
                }
            } catch (e: Exception) {
                Log.d(TAG, "DNS $server zlyhal: ${e.message}")
            }
        }
        return null
    }

    /** Zabalí DNS odpoveď späť do IPv4/UDP paketu s vymenenými adresami a portami. */
    private fun writeResponse(request: ByteArray, ihl: Int, dns: ByteArray) {
        val total = 20 + 8 + dns.size
        val p = ByteArray(total)
        p[0] = 0x45
        put16(p, 2, total)
        p[6] = 0x40 // Don't fragment
        p[8] = 64 // TTL
        p[9] = 17 // UDP
        System.arraycopy(request, 16, p, 12, 4) // zdroj = pôvodný cieľ
        System.arraycopy(request, 12, p, 16, 4) // cieľ = pôvodný zdroj
        put16(p, 10, ipChecksum(p, 20))

        put16(p, 20, u16(request, ihl + 2)) // zdrojový port = 53
        put16(p, 22, u16(request, ihl)) // cieľový port = pôvodný zdrojový
        put16(p, 24, 8 + dns.size)
        // UDP checksum 0 = nepoužitý (povolené pre IPv4)
        System.arraycopy(dns, 0, p, 28, dns.size)

        val out = output ?: return
        synchronized(out) {
            try {
                out.write(p)
            } catch (e: Exception) {
                Log.d(TAG, "Zápis do tunela zlyhal: ${e.message}")
            }
        }
    }

    private fun ipChecksum(data: ByteArray, length: Int): Int {
        var sum = 0
        var i = 0
        while (i < length) {
            sum += u16(data, i)
            i += 2
        }
        while (sum shr 16 != 0) sum = (sum and 0xFFFF) + (sum shr 16)
        return sum.inv() and 0xFFFF
    }

    private fun u16(b: ByteArray, off: Int) =
        ((b[off].toInt() and 0xFF) shl 8) or (b[off + 1].toInt() and 0xFF)

    private fun put16(b: ByteArray, off: Int, value: Int) {
        b[off] = (value shr 8).toByte()
        b[off + 1] = value.toByte()
    }

    private fun shutdown() {
        isRunning = false
        readerThread?.interrupt()
        readerThread = null
        executor?.shutdownNow()
        executor = null
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
        output = null
    }

    override fun onRevoke() {
        // Používateľ vypol VPN v systéme alebo spustil inú VPN.
        BlockStore.setVpnEnabled(this, false)
        shutdown()
        stopSelf()
    }

    override fun onDestroy() {
        shutdown()
        super.onDestroy()
    }
}
