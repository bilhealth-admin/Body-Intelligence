package com.bilhealth.bodyintelligencelog
import org.junit.Assert.*
import org.junit.Test
class BILIntegrityTokenLeaseTest {
    @Test fun exactObjectAndSingleUse() {
        val token = Any(); val lease = BILIntegrityTokenLease<Any>({ 1L })
        lease.put("current", token)
        assertSame(token, lease.take("current")); assertNull(lease.take("current"))
    }
    @Test fun wrongHandleCannotConsumeCurrent() {
        val token = Any(); val lease = BILIntegrityTokenLease<Any>({ 1L })
        lease.put("current", token)
        assertNull(lease.take("other")); assertSame(token, lease.take("current"))
    }
    @Test fun expiresAtExactMonotonicDeadline() {
        var clock = 100L; val lease = BILIntegrityTokenLease<Any>({ clock })
        lease.put("current", Any()); clock += 60_000L
        assertNull(lease.take("current"))
    }
    @Test fun validUntilDeadline() {
        var clock = 100L; val token = Any(); val lease = BILIntegrityTokenLease<Any>({ clock })
        lease.put("current", token); clock += 59_999L
        assertSame(token, lease.take("current"))
    }
    @Test fun newestTokenSupersedesOldExactResponse() {
        val token = Any(); val lease = BILIntegrityTokenLease<Any>({ 1L })
        lease.put("old", Any()); lease.put("new", token)
        assertNull(lease.take("old")); assertSame(token, lease.take("new"))
    }
    @Test fun releasingStaleLeaseCannotRetireNewToken() {
        val token = Any(); val lease = BILIntegrityTokenLease<Any>({ 1L })
        lease.put("new", token); lease.release("old")
        assertSame(token, lease.take("new"))
    }
    @Test fun currentReleaseAndDisposeClearExactResponse() {
        val lease = BILIntegrityTokenLease<Any>({ 1L })
        lease.put("current", Any()); lease.release("current"); assertNull(lease.take("current"))
        lease.put("current", Any()); lease.clear(); assertNull(lease.take("current"))
    }
    @Test fun unrelatedNonremediationResponseCannotOverwriteRecoveryResponse() {
        val first = Any(); val lease = BILIntegrityTokenLease<Any>({ 1L })
        lease.record("readiness-1", first, true)
        lease.record("unrelated-2", Any(), false)
        assertNull(lease.take("unrelated-2"))
        assertSame(first, lease.take("readiness-1"))
    }
}
