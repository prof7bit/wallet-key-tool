package prof7bit.bitcoin.wallettool.fileformats

import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.slf4j.LoggerFactory

class WalletDatHandler extends AbstractImportExportHandler {
    val log = LoggerFactory.getLogger(WalletDatHandler)

    // these are the only ones we support
    static val MAGIC   = 0x53162
    static val VERSION = 9
    static val NOT_YET = true

    // page types
    static val P_IBTREE    = 3   /* Btree internal. */
    static val P_LBTREE    = 5   /* Btree leaf. */
    static val P_BTREEMETA = 9   /* Btree metadata page. */

    var RandomAccessFile f
    val bb2 = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN)
    val bb4 = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)

    var long pagesize
    var int last_pgno

    /**
     * Try to parse keys from a wallet.dat file
     * with inspiration from libdb, for example here:
     * https://github.com/gburd/libdb/blob/master/src/dbinc/db_page.h
     * and a hex editor.
     */
    override load(File file, String password, String password2) throws Exception {

        if (NOT_YET){
            throw new UnsupportedOperationException("not yet implemented")
        }

        try {
            log.info("opening file {}", file)
            f = new RandomAccessFile(file, "r")
            val magic = readMagic
            val version = readVersion
            if (magic != MAGIC || version != VERSION) {
                throw new Exception("this is not a valid wallet.dat file")
            }
            pagesize = readPageSize
            last_pgno = readLastPgno
            readAllLeafPages
        } catch (Exception e) {
            log.info("exception", e)
        } finally {
            f.close
        }
    }

    static val START_TABLE = 26

    /**
     * Right after the header of a b-tree leaf page there is a
     * table with 16bit words, each data item has an entry in this
     * table. They are the offsets of the actual data (relative to
     * START_DATA). We look up the value and add START_DATA and
     * absolute page offset to this value so we get an absolute
     * offset from the start of the file.
     */
    def getDataOffset(int p, int index) throws IOException {
        val lookup_table_offs = p * pagesize + START_TABLE + 2 * index
        return readShortAt(lookup_table_offs) + p * pagesize
    }

    def readLeafPage(int p) throws IOException {
        val count_entries = p.readEntryCount
        for (i : 0..<count_entries){
            val o = getDataOffset(p, i)
            val size = readShortAt(o)
            val type = readByteAt(o + 2)
            val data = newByteArrayOfSize(size)
            f.seek(o + 3)
            f.read(data)
            println(size + " " + type)
        }
    }

    def readAllLeafPages(int p_start) throws IOException {
        var p = p_start
        while (p != 0){
            readLeafPage(p)
            p = p.readNextPgno
        }
    }

    def readAllLeafPages() throws IOException {
        for (p : 0..last_pgno) {
            if (p.readPageType ==  P_LBTREE){
                // find a leaf with prev=0
                if (p.readPrevPgno == 0){
                    readAllLeafPages(p)
                }
            }
        }
    }

    def readPrevPgno(int pgno) throws IOException {
        return readIntAt(pagesize * pgno + 12)
    }

    def readNextPgno(int pgno) throws IOException {
        return readIntAt(pagesize * pgno + 16)
    }

    def readEntryCount(int pgno) throws IOException {
        return readShortAt(pagesize * pgno + 20)
    }

    def readPageType(int pgno) throws IOException {
        return readByteAt(pagesize * pgno + 25)
    }

    /** this works only with type =  */
    def readRootPage(int pgno) throws IOException {
        return readByteAt(pagesize * pgno + 88)
    }

    def readLastPgno() throws IOException {
        return readIntAt(32)
    }

    def readMagic() throws IOException {
        return readIntAt(12)
    }

    def readVersion() throws IOException {
        return readIntAt(16)
    }

    def readPageSize() throws IOException {
        return readIntAt(20)
    }


    // *************


    def int readIntAt(long offset) throws IOException {
        f.seek(offset)
        bb4.clear
        f.channel.read(bb4)
        bb4.flip
        return bb4.int
    }

    def short readShortAt(long offset) throws IOException {
        f.seek(offset)
        bb2.clear
        f.channel.read(bb2)
        bb2.flip
        return bb2.short
    }

    def byte readByteAt(long offset) throws IOException {
        f.seek(offset)
        return f.readByte
    }


    // *************


    def xprintln(long n){
        println(String.format("0x%08X",n))
    }

    override save(File file, String password, String password2) throws Exception {
        throw new UnsupportedOperationException("Writing wallet.dat is not supported")
    }
}
