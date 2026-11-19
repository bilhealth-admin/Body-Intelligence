package com.bilhealth.bodyintelligencelog

internal class BILIntegrityTokenLease<T>(
    private val now: () -> Long,
    private val ttlMillis: Long = 60_000L,
) {
    private var handle: String? = null
    private var value: T? = null
    private var expiresAt = 0L

    fun record(nextHandle: String, nextValue: T, retainForRecovery: Boolean) {
        if (retainForRecovery) put(nextHandle, nextValue)
    }

    fun put(nextHandle: String, nextValue: T) {
        clear()
        handle = nextHandle
        value = nextValue
        expiresAt = now() + ttlMillis
    }

    fun take(expectedHandle: String): T? {
        if (now() >= expiresAt) { clear(); return null }
        if (handle != expectedHandle) return null
        val result = value
        clear() // Consume before opening any Google UI.
        return result
    }

    fun release(expectedHandle: String) {
        if (handle == expectedHandle) clear()
    }

    fun clear() { handle = null; value = null; expiresAt = 0L }
}
