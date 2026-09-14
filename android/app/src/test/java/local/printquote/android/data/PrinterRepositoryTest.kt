package local.printquote.android.data

import local.printquote.android.model.Printer
import org.junit.Assert.*
import org.junit.Test

class PrinterRepositoryTest {
    @Test fun loadsAuthoritativeSharedProfile() {
        val json = checkNotNull(javaClass.classLoader!!.getResourceAsStream(PrinterRepository.FILE))
            .bufferedReader().use { it.readText() }
        val printers = PrinterRepository { json }.load()
        val prusa = printers.first { it.manufacturer == "Prusa" }
        assertEquals("Prusa XL 2-tool", prusa.model)
        assertEquals(2, prusa.toolheads)
        assertTrue(printers.all { it.toolheads in 1..12 })
    }

    @Test fun supportsTwelveToolheads() {
        assertEquals(12, Printer("Test", "Boundary", 12).toolheads)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsUnsupportedToolheadCount() { Printer("Test", "Invalid", 13) }
}
