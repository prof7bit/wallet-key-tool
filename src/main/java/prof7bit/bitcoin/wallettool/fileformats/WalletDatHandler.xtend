package prof7bit.bitcoin.wallettool.fileformats

import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.io.UnsupportedEncodingException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.ArrayList
import java.util.Arrays
import java.util.Formatter
import java.util.HashMap
import java.util.List
import java.util.Map
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.InvalidCipherTextException
import org.spongycastle.crypto.digests.SHA256Digest
import org.spongycastle.crypto.digests.SHA512Digest
import org.spongycastle.crypto.engines.AESFastEngine
import org.spongycastle.crypto.modes.CBCBlockCipher
import org.spongycastle.crypto.paddings.PaddedBufferedBlockCipher
import org.spongycastle.crypto.params.KeyParameter
import org.spongycastle.crypto.params.ParametersWithIV
import prof7bit.bitcoin.wallettool.exceptions.FormatFoundNeedPasswordException

class WalletDatHandler extends AbstractImportExportHandler {
    val log = LoggerFactory.getLogger(WalletDatHandler)

    // these are the only ones we support
    static val MAGIC   = 0x53162
    static val VERSION = 9

    static val NOT_YET = true

    // page types
    static val P_LBTREE    = 5   /* Btree leaf. */

    var RandomAccessFile f
    val bb2 = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN)
    val bb4 = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)

    var long pagesize
    var int last_pgno

    val List<ByteBuffer> items = new ArrayList
    val rawKeyList = new WalletDatRawKeyDataList

    // encrypted master key
    var int mkey_nID
    var byte[] mkey_encrypted_key
    var byte[] mkey_salt
    var int mkey_nDerivationMethod
    var int mkey_nDerivationIterations
    var String mkey_other_params

    /**
     * Try to parse keys from a bitcoin-core wallet.dat file.
     * Reverse engineered with inspiration from pywallet.py,
     * db_page.h, db_dump and a hex editor.
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
            parseAllItems
            decrypt(password)

        } catch (Exception e) {
            log.error("exception", e)
        } finally {
            f.close
        }
    }

    //
    // ************* decrypt and import
    //

    private def decrypt(String password) throws Exception {
        if (mkey_encrypted_key == null){
            return
        }
        if (password == null){
            throw new FormatFoundNeedPasswordException
        }
        val crypter = new WalletDatCrypter

        // first we decrypt the encrypted master key...
        crypter.setKeyFromPassphrase(
            password,
            mkey_salt,
            mkey_nDerivationIterations,
            mkey_nDerivationMethod
        )
        val mkey = crypter.decrypt(mkey_encrypted_key)

        // ...then we use that to decrypt the individual keys
        for (key : rawKeyList.keys.values){
            if (key.encrypted_private_key != null){
                val enc = key.encrypted_private_key
                val pub = key.public_key
                val iv = crypter.doubleHash(pub).take(16)
                crypter.setKeyAndIV(mkey, iv)
                val dec = crypter.decrypt(enc)
                xprintln(dec)
            }
        }
    }


    //
    // ************* parsing the wallet contents from the ByteBuffers
    //

    private def parseAllItems(){
        rawKeyList.clear
        var i = 0
        while (i < items.length - 1) {
            val key = items.get(i)
            val value = items.get(i + 1)
            parseKeyValuePair(key, value)
            i = i + 2
        }
    }

    private def parseKeyValuePair(ByteBuffer key, ByteBuffer value) {
        if (Arrays.equals(key.array, "main".bytes)){
            // ignore this key, it appears on page #1
            // as the only item and seems to be some
            // bdb internal thing.
            return
        }

        // The keys are composed of a prefix string (type) and optional
        // additional data. This prefix ultimately determines how to parse
        // and interpret the rest of the key and the value. These are
        // bitcoin specific structures, all variable length objects are
        // prefixed by a compact size followed by the data as it is usual
        // for bitcoin internal structures. Numbers are little endian.
        // I am trying to use the same variable names used in pywallet
        // in the parseXxx() methods below to make it easier to follow.
        val type = key.readString
        switch(type){
            case "name": parseName(key, value)
            case "key": parseKey(key, value)
            case "wkey": parseWkey(key, value)
            case "ckey": parseCkey(key, value)
            case "mkey": parseMkey(key, value)  // encrypted master key

            // ignoring a lot of other types (see pywallet)
            // because we are only interested in keys, not
            // in tx or other stuff
            default: return
        }
    }

    private def parseName(ByteBuffer key, ByteBuffer value) {
        val hash = key.readString
        val name = value.readString
        rawKeyList.addName(hash, name)
    }

    private def parseKey(ByteBuffer key, ByteBuffer value) {
        val public_key = key.readSizePrefixedByteArray
        val private_key = value.readSizePrefixedByteArray
        rawKeyList.addUnencrypted(public_key, private_key)
    }

    private def parseWkey(ByteBuffer key, ByteBuffer value) {
        val public_key = key.readSizePrefixedByteArray
        val private_key = value.readSizePrefixedByteArray
        val created = value.getLong
        /*
        val expires = value.getLong
        val comment = value.readString
        */
        rawKeyList.addUnencrypted(public_key, private_key)
        rawKeyList.keys.get(public_key).created = created
    }

    private def parseCkey(ByteBuffer key, ByteBuffer value) {
        val public_key = key.readSizePrefixedByteArray
        val encrypted_private_key = value.readSizePrefixedByteArray
        rawKeyList.addEncrypted(public_key, encrypted_private_key)
    }

    private def parseMkey(ByteBuffer key, ByteBuffer value) {
        mkey_nID = key.getInt
        mkey_encrypted_key = value.readSizePrefixedByteArray
        mkey_salt = value.readSizePrefixedByteArray
        mkey_nDerivationMethod = value.getInt
        mkey_nDerivationIterations = value.getInt
        mkey_other_params = value.readString
    }

    //
    // ************* reading stuff from a ByteBuffer in the way bitcoin likes to encode it
    //

    private def readString(ByteBuffer buf) {
        return new String(buf.readSizePrefixedByteArray)
    }

    private def readSizePrefixedByteArray(ByteBuffer buf){
        val size = buf.readCompactSize
        return buf.readByteArray(size)
    }

    private def readByteArray(ByteBuffer buf, int size){
        val result = newByteArrayOfSize(size)
        buf.get(result)
        return result
    }

    private def readCompactSize(ByteBuffer buf){
        val b = buf.get().bitwiseAnd(0xff)
        if (b < 253) {
            return b
        } else if (b < 254) {
            // next two bytes are the size
            return buf.short.bitwiseAnd(0xffff)
        } else {
            // 254 would be int and 255 would be long.
            // These exist theoretically but we don't
            // expect such large byte arrays in a wallet file.
            // Sizes that need int would already exceed the
            // b-tree page size which I have not yet
            // implemented anyways and sizes of long
            // wouldn't even fit into the ByteBufer.
            throw new RuntimeException("size value unreasonably large")
        }
    }

    //
    // ************* reading Berkeley-specific structures from the file
    //

    /**
     * parse all leaf pages in the file and put
     * all their items into the items list. Begin
     * with every root leaf and then follow the
     * next_pgno until there is no next page.
     */
    private def readAllLeafPages() throws IOException {
        items.clear
        for (p : 0..last_pgno) {
            // find a root leaf
            if (p.readPageType ==  P_LBTREE && p.readPrevPgno == 0){
                readAllLeafPages(p)
            }
        }
    }

    /**
     * parse this leaf page and all next pages
     * as indicated by next_pgno and add all their
     * items into the items list until there is
     * no next page anymore.
     */
    private def readAllLeafPages(int p_start) throws IOException {
        var p = p_start
        while (p != 0){
            readLeafPage(p)
            p = p.readNextPgno
        }
    }

    /**
     * parse this leaf page and add all
     * its items to the items list
     */
    private def readLeafPage(int p) throws IOException {
        val count_entries = p.readEntryCount
        for (i : 0..<count_entries){
            val o = p.getDataOffset(i)
            val size = readShortAt(o).bitwiseAnd(0xffff)
            val type = readByteAt(o + 2)
            if (type == 1) {
                val data = readByteArrayAt(o + 3, size)
                items.add(ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN))
            }
        }
    }

    static val START_TABLE = 26

    /**
     * Right after the header of a b-tree leaf page there is a
     * table with 16bit words, each data item has an entry in this
     * table. They are the offsets of the actual data (relative to
     * the start of the page). Given a page number of a b-tree
     * page and an item index this function will look up the table
     * and return the absolute file offset of this item.
     */
    private def long getDataOffset(int p, int index) throws IOException {
        val lookup_table_offs = p * pagesize + START_TABLE + 2 * index
        val item_offs = readShortAt(lookup_table_offs).bitwiseAnd(0xffff)
        return  item_offs + p * pagesize
    }

    private def readPrevPgno(int pgno) throws IOException {
        return readIntAt(pagesize * pgno + 12)
    }

    private def readNextPgno(int pgno) throws IOException {
        return readIntAt(pagesize * pgno + 16)
    }

    private def readEntryCount(int pgno) throws IOException {
        return readShortAt(pagesize * pgno + 20)
    }

    private def readPageType(int pgno) throws IOException {
        return readByteAt(pagesize * pgno + 25)
    }

    private def readLastPgno() throws IOException {
        return readIntAt(32)
    }

    private def readMagic() throws IOException {
        return readIntAt(12)
    }

    private def readVersion() throws IOException {
        return readIntAt(16)
    }

    private def readPageSize() throws IOException {
        return readIntAt(20)
    }


    //
    // ************* random access file reading, using LITTLE endian
    //

    private def byte[] readByteArrayAt(long offset, int size) throws IOException {
        val result = newByteArrayOfSize(size)
        f.seek(offset)
        f.read(result)
        return result
    }

    private def int readIntAt(long offset) throws IOException {
        f.seek(offset)
        bb4.clear
        f.channel.read(bb4)
        bb4.flip
        return bb4.int
    }

    private def short readShortAt(long offset) throws IOException {
        f.seek(offset)
        bb2.clear
        f.channel.read(bb2)
        bb2.flip
        return bb2.short
    }

    private def byte readByteAt(long offset) throws IOException {
        f.seek(offset)
        return f.readByte
    }


    //
    // ************* saving (won't be implemented)
    //

    override save(File file, String password, String password2) throws Exception {
        throw new UnsupportedOperationException("Writing wallet.dat is not supported")
    }


    //
    // ************* helpers
    //

    private def xprintln(long n){
        println(String.format("0x%08X",n))
    }

    private def xprintln(byte[] buf){
        val formatter = new Formatter();
        for (b : buf){
            formatter.format("%02x", b);
        }
        println(buf.length * 8 + " " +  formatter.toString)
        formatter.close
    }
}



/**
 * Maintains collections of raw key data objects
 * and names while they are parsed from wallet.dat
 */
class WalletDatRawKeyDataList {
    public val Map<byte[], WalletDatRawKeyData> keys = new HashMap
    public val Map<String, String> names = new HashMap

    def findOrAddNew(byte[] pub){
        var key = keys.get(pub)
        if (key == null){
            key = new WalletDatRawKeyData
            keys.put(pub, key)
        }
        return key
    }

    def addName(String hash, String name){
        names.put(hash, name)
    }

    def addEncrypted(byte[] pub, byte[] encrypted){
        val key = findOrAddNew(pub)
        key.public_key = pub
        key.encrypted_private_key = encrypted
    }

    def addUnencrypted(byte[] pub, byte[] unencrypted){
        val key = findOrAddNew(pub)
        key.public_key = pub
        key.private_key = unencrypted
    }

    def clear(){
        keys.clear
        names.clear
    }
}


/**
 * raw key data for a single key parsed from wallet.dat
 */
class WalletDatRawKeyData {
    public var byte[] encrypted_private_key
    public var byte[] private_key
    public var byte[] public_key
    public var long created
}


/**
 * crypter used for wallet.dat encrypted keys
 */
class WalletDatCrypter {
    var  PaddedBufferedBlockCipher cipher

    /**
     * set key and iv from password and initialize cipher for decryption
     */
    def setKeyFromPassphrase(String pass, byte[] salt, int nDerivationIterations, int nDerivationMethod) throws Exception {
        if (nDerivationMethod != 0) {
            throw new Exception("unsupported key derivation method")
        }
        initCipher(getKeyParamFromPass(pass, salt, nDerivationIterations), false)
    }

    /**
     * set key and iv directly and initialize cipher for decryption.
     */
    def setKeyAndIV(byte[] key, byte[] iv){
        val params = new ParametersWithIV(new KeyParameter(key), iv)
        initCipher(params, false)
    }

    def decrypt(byte[] ciphertext)throws InvalidCipherTextException {
        val size = cipher.getOutputSize(ciphertext.length)
        val plaintext = newByteArrayOfSize(size)
        val processLength = cipher.processBytes(ciphertext, 0, ciphertext.length, plaintext, 0)
        val doFinalLength = cipher.doFinal(plaintext, processLength);
        return removePadding(plaintext, processLength + doFinalLength)
    }

    def removePadding(byte[] plaintext, int length){
        if (length == plaintext.length){
            return plaintext
        } else {
            val result = newByteArrayOfSize(length)
            System.arraycopy(plaintext, 0, result, 0, length)
            return result
        }
    }

    def getKeyParamFromPass(String pass, byte[] salt, int nDerivationIterations) throws UnsupportedEncodingException {
        val stretched = stretchPass(pass, salt, nDerivationIterations)
        // key is the first 32 bytes,
        // iv is the next 16 bytes
        val iv = newByteArrayOfSize(16)
        System.arraycopy(stretched, 32, iv, 0, 16)
        return new ParametersWithIV(new KeyParameter(stretched, 0, 32), iv)
    }

    def initCipher(ParametersWithIV key, boolean forEnryption){
        cipher = new PaddedBufferedBlockCipher(new CBCBlockCipher(new AESFastEngine))
        cipher.init(forEnryption, key)
    }

    def stretchPass(String pass, byte[] salt, int nDerivationIterations) throws UnsupportedEncodingException {
        var passbytes = pass.getBytes("UTF-8")
        var data = newByteArrayOfSize(64)
        val sha = new SHA512Digest
        sha.update(passbytes, 0, passbytes.length)
        sha.update(salt, 0, salt.length)
        sha.doFinal(data, 0)
        for (i : 1..<nDerivationIterations){
            sha.reset
            sha.update(data, 0, data.length)
            sha.doFinal(data, 0)
        }
        return data
    }

    /**
     * apply sha256 twice
     * @return sha256(sha256(data))
     */
    def doubleHash(byte[] data){
        val sha = new SHA256Digest
        val buf = newByteArrayOfSize(32)
        sha.update(data, 0, data.length)
        sha.doFinal(buf, 0)
        sha.reset
        sha.update(buf, 0, buf.length)
        sha.doFinal(buf, 0)
        return buf
    }
}
