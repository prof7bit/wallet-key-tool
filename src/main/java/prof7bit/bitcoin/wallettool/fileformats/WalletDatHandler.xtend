package prof7bit.bitcoin.wallettool.fileformats

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.params.MainNetParams
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.io.UnsupportedEncodingException
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.Arrays
import java.util.HashMap
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
import prof7bit.bitcoin.wallettool.core.KeyObject
import prof7bit.bitcoin.wallettool.exceptions.FormatFoundNeedPasswordException

class WalletDatHandler extends AbstractImportExportHandler {
    val log = LoggerFactory.getLogger(this.class)

    /**
     * Try to parse keys from a bitcoin-core wallet.dat file.
     * Reverse engineered with inspiration from pywallet.py,
     * db_page.h, db_dump and a hex editor.
     */
    override load(File file, String password, String password2) throws Exception {

        val wallet = new WalletDat(file)
        wallet.decrypt(password)

        var count = 0
        for (rawKey : wallet.keys){

            var ECKey ecKey
            if (rawKey.private_key.length > 32){
                // ASN.1 encoded key (found in unencrypted wallets)
                // make an uncompressed ECKey from it. This is the
                // only constructor that lets us pass ASN.1 so
                // we cannot directly instantiate a compressed key.
                ecKey = ECKey.fromASN1(rawKey.private_key)
                if (!Arrays.equals(ecKey.pubKey, rawKey.public_key)) {
                    // doesn't match, now try compressed, using the already decoded bytes
                    ecKey = new ECKey(new BigInteger(1, ecKey.privKeyBytes), null, true)
                }
            } else {
                // this is what we normally get from an encrypted wallet,
                // the keys are stored as the 256 bit integer
                ecKey = new ECKey(new BigInteger(1, rawKey.private_key), null, rawKey.compressed)
            }


            if (Arrays.equals(ecKey.pubKey, rawKey.public_key)) {
                val wktKey = new KeyObject(ecKey, params)
                val addr = ecKey.toAddress(walletKeyTool.params).toString
                if (rawKey.pool){
                    wktKey.label = "(reserve)"
                } else {
                    val label = wallet.getAddrLabel(addr)
                    wktKey.label = label
                    if (label == ""){
                       wktKey.label = "(change)"
                    }
                }
                walletKeyTool.add(wktKey)
                walletKeyTool.reportProgress(100 * count / wallet.keys.length, addr)
                count = count + 1

            } else {
                log.error("calculated public key does not match for {}", rawKey.public_key)
                count = count + 1
            }
        }

        log.info("import complete :-)")
    }

    private def getParams(){
        if (walletKeyTool.params == null){
            walletKeyTool.params = new MainNetParams
        }
        return walletKeyTool.params
    }

    /**
     * Save the keys to the wallet.dat file. This will always
     * throw an exception because it will not be implemented.
     */
    override save(File file, String password, String password2) throws Exception {
        throw new UnsupportedOperationException("Writing wallet.dat is not supported")
    }
}

class WalletDat {
    val log = LoggerFactory.getLogger(this.class)

    var RandomAccessFile raf
    var ByteBuffer currentKey = null

    /**
     * this object will contain all bitcoin keys, it will
     * be populated while going through the bdb key/value
     * pairs in the file.
     */
    val rawKeyList = new WalletDatRawKeyDataList

    // all bitcoin private keys are encrypted with the mkey
    // and the mkey itself is encrypted with the password.
    var int mkey_nID
    var byte[] mkey_encrypted_key
    var byte[] mkey_salt
    var int mkey_nDerivationMethod
    var int mkey_nDerivationIterations
    var String mkey_other_params

    new (File file) throws Exception {
        try {
            log.info("opening file {}", file)
            raf = new RandomAccessFile(file, "r")
            parseBerkeleyFile
        } finally {
            raf.close
        }
    }


    //
    //
    //
    // Bitcoin specific stuff

    /**
     * parse an individual key/value pair and see if it contains
     * relevant information, extract this information (we only
     * care about private keys and ignore all other stuff) and
     * add it to the rawKeyList. "key" here means key as in
     * "key/value", it does not mean bitcoin private key. This
     * method will be called for every key/value pair that is
     * found in the database while the database is being read.
     */
    private def processKeyValuePair(ByteBuffer key, ByteBuffer value) {
        if (Arrays.equals(key.array, "main".bytes)){
            // ignore this key, it appears on page #1
            // as the only item and seems to be some
            // bdb internal thing, not Bitcoin related.
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
            case "key" : parseKey(key, value)
            case "wkey": parseWkey(key, value)
            case "ckey": parseCkey(key, value)
            case "mkey": parseMkey(key, value)  // encrypted master key
            case "pool": parsePool(key, value)  // reserve address

            // ignoring a lot of other types (see pywallet)
            // because we are only interested in keys, not
            // in tx or other stuff
            default: log.trace("ignored: irrelevant type '{}'", type)
        }
    }

    private def parseName(ByteBuffer key, ByteBuffer value) {
        val hash = key.readString
        val name = value.readString
        log.trace("found: type 'name' {} {}", hash, name)
        rawKeyList.addName(hash, name)
    }

    private def parseKey(ByteBuffer key, ByteBuffer value) {
        val public_key = key.readSizePrefixedByteArray
        val private_key = value.readSizePrefixedByteArray
        log.trace("found: type 'key'")
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
        log.trace("found: type 'wkey'")
        rawKeyList.addUnencrypted(public_key, private_key)
        rawKeyList.keyData.get(public_key).created = created
    }

    private def parseCkey(ByteBuffer key, ByteBuffer value) {
        val public_key = key.readSizePrefixedByteArray
        val encrypted_private_key = value.readSizePrefixedByteArray
        log.trace("found: type 'ckey'")
        rawKeyList.addEncrypted(public_key, encrypted_private_key)
    }

    private def parseMkey(ByteBuffer key, ByteBuffer value) {
        mkey_nID = key.getInt
        mkey_encrypted_key = value.readSizePrefixedByteArray
        mkey_salt = value.readSizePrefixedByteArray
        mkey_nDerivationMethod = value.getInt
        mkey_nDerivationIterations = value.getInt
        mkey_other_params = value.readString
        log.trace("found: type 'mkey'")
    }

    private def parsePool(ByteBuffer key, ByteBuffer value) {
        val n = key.getLong
        value.getInt  // nVersion
        value.getLong // nTime
        val public_key = value.readSizePrefixedByteArray
        rawKeyList.addPoolFlag(public_key)
        log.trace("found: type 'pool' n={}", n)
    }

    private def readString(ByteBuffer buf) {
        new String(buf.readSizePrefixedByteArray)
    }

    private def readSizePrefixedByteArray(ByteBuffer buf){
        buf.readByteArray(buf.readCompactSize)
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


    /**
     * Decrypt (if encrypted) the keys in the raw key list,
     * do nothing if they are not encrypted
     */
    def decrypt(String password) throws Exception {
        if (mkey_encrypted_key != null){
            if (password == null){
                throw new FormatFoundNeedPasswordException
            }

            val crypter = new WalletDatCrypter

            // first we decrypt the encrypted master key...
            val mkey = crypter.decrypt(
                mkey_encrypted_key,
                password,
                mkey_salt,
                mkey_nDerivationIterations,
                mkey_nDerivationMethod
            )

            // ...then we use that to decrypt all the individual keys
            for (key : rawKeyList.keyData.values){
                if (key.encrypted_private_key != null){
                    key.private_key = crypter.decrypt(
                        key.encrypted_private_key,
                        mkey,
                        key.public_key
                    )
                }
            }
        }
    }

    def getKeys() {
        rawKeyList.keyData.values
    }

    def getAddrLabel(String addr){
        rawKeyList.getName(addr)
    }


    //
    //
    //
    // Berkeley-db specific stuff, not Bitcoin-related

    /**
     * Parse the wallet.dat file, find all b-tree leaf
     * pages in the file and process all their items.
     * Begin with the first leaf page and then follow the
     * next_pgno until there is no next page. When this
     * function has returned we will have iterated over
     * all key/value items in the entire database
     */
    private def parseBerkeleyFile() throws Exception {
        // these are the only ones we support
        val MAGIC   = 0x53162
        val VERSION = 9

        val head = new BerkeleyDBHeaderPage(raf)
        val magic = head.magic
        val version = head.version
        if (magic != MAGIC || version != VERSION) {
            throw new Exception("this is not a valid wallet.dat file")
        }
        val pagesize = head.pageSize
        val last_pgno = head.lastPgno

        for (pgno : 0..<last_pgno) {
            // find all first leaves. Actually there are at
            // least 2 trees in every wallet file, so we
            // will find two first leaves.
            val page = new BerkeleyDBLeafPage(raf, pgno, pagesize)
            if (page.isLBTREE && page.isFirstLeaf){
                readAllLeafPages(page)
            }
        }
    }

    /**
     * parse this leaf page and all following leaf pages
     * as indicated by next_pgno and process all of their
     * items until there is no next page anymore.
     */
    private def readAllLeafPages(BerkeleyDBLeafPage root) throws IOException {
        var page = root
        while (page.hasNextPage){
            readLeafPage(page)
            page = page.nextLeafPage
        }
    }

    /**
     * parse this leaf page and iterate over all
     * its items, read and process each of them.
     */
    private def readLeafPage(BerkeleyDBLeafPage page) {
        val count = page.entryCount
        log.debug("page {} contains {} entries", page.pgno , count)
        for (i : 0..<count){
            if (page.getItemType(i) == 1) {
                val item = page.getItemData(i)
                if (currentKey == null){
                    //even number, item is a key
                    currentKey = item
                } else {
                    // odd number, item is a value,
                    // previous item was its key
                    processKeyValuePair(currentKey, item)
                    currentKey = null
                }
            }
        }
    }
}

abstract class BerkeleyDBPage {
    // page types
    static val P_LBTREE    = 5   /* Btree leaf. */

    protected var ByteBuffer b
    protected var RandomAccessFile raf
    protected var int pgno
    protected var long pgsize

    new (RandomAccessFile raf, int pgno, long pgsize) throws IOException {
        this.raf = raf
        this.pgno = pgno
        this.pgsize = pgsize
        b = raf.channel.map(FileChannel.MapMode.READ_ONLY, pgno * pgsize, pgsize).order(ByteOrder.LITTLE_ENDIAN)
    }

    def getPgno() {
        pgno
    }

    def getPrevPgno() {
        b.getInt(12)
    }

    def getNextPgno() {
        b.getInt(16)
    }

    def isFirstLeaf() {
        prevPgno == 0
    }

    def hasNextPage() {
        nextPgno != 0
    }

    def isLBTREE() {
        pageType == P_LBTREE
    }

    def getPageType() {
        b.get(25)
    }
}

/**
 * this is a leaf page, it contains all the data
 */
class BerkeleyDBLeafPage extends BerkeleyDBPage {
    static val SIZE_LEAF_HEADER = 26

    new(RandomAccessFile raf, int pgno, long pgsize) throws IOException {
        super(raf, pgno, pgsize)
    }

    /**
     * Right after the header of a b-tree leaf page there is a
     * table with 16bit words, each item has an entry in this
     * table. They are the offsets of the actual data (relative to
     * the start of the page). Given an item index this function
     * will look up the table and return the offset (relative to
     * page start) of this item. Each row of data (key + value)
     * is actually made up of 2 consecutive items, the key and
     * the value. This method does not need to care whether its
     * a key or a value, it just takes an index and returns the
     * offset where to find the data.
     */
    private def getItemOffset(int index) {
        val lookup_table_offs = SIZE_LEAF_HEADER + 2 * index
        b.getShort(lookup_table_offs).bitwiseAnd(0xffff)
    }

    /**
     * read bytes from the specified offset and copy them
     * into a new ByteBuffer. The returned ByteBuffer will
     * be configured for little endian reading.
     */
    private def getBytes(int offset, int size){
        val a = newByteArrayOfSize(size)
        b.position(offset)
        b.get(a)
        ByteBuffer.wrap(a).order(ByteOrder.LITTLE_ENDIAN)
    }

    /**
     * get the type of the item with the index,
     * FIXME: see db_page.h for type constants
     */
    def getItemType(int index){
        val offset = getItemOffset(index)
        b.get(offset + 2)
    }

    /**
     * get the item data at the index, return it in
     * a newly allocated ByteBuffer. The Buffer will
     * be configured as little endian. "Item" can be
     * either a key or a value, its up to higher
     * levels to know what it actually is, as far as
     * this method is concerned its just a bunch of
     * bytes addressed by an index number.
     */
    def getItemData(int index){
        val offset = getItemOffset(index)
        val size = b.getShort(offset).bitwiseAnd(0xffff)
        getBytes(offset + 3, size)
    }

    /**
     * page number of next leaf page in this tree
     * or 0 if this is the last leaf page.
     */
    def getNextLeafPage() throws IOException {
        new BerkeleyDBLeafPage(raf, nextPgno, pgsize)
    }

    /**
     * Get count of items on this page. This is twice
     * the number of key/value pairs because key and
     * value are separate items. They are stored in
     * alternating sequence: {k1, v1, k2, v2, .., kn, vn}
     */
    def getEntryCount() {
        b.getShort(20)
    }

}

/**
 * this is only used for page 0 to read magic, version, page size, etc.
 */
class BerkeleyDBHeaderPage extends BerkeleyDBPage {
    static val SIZE_METADATA_HEADER = 72

    new (RandomAccessFile raf) throws IOException {
        super(raf, 0, SIZE_METADATA_HEADER)
    }

    def getLastPgno() {
        b.getInt(32)
    }

    def getMagic() {
        b.getInt(12)
    }

    def getVersion() {
        b.getInt(16)
    }

    def getPageSize() {
        b.getInt(20)
    }
}


/**
 * Maintains collections of raw key data objects
 * and names while they are parsed from wallet.dat
 */
class WalletDatRawKeyDataList {
    public val Map<ByteBuffer, WalletDatRawKeyData> keyData = new HashMap
    public val Map<String, String> names = new HashMap

    def findOrAddNew(byte[] pub){
        var key = getKeyData(pub)
        if (key == null){
            key = new WalletDatRawKeyData
            key.public_key = pub
            keyData.put(ByteBuffer.wrap(pub), key)
        }
        return key
    }

    def addName(String hash, String name){
        names.put(hash, name)
    }

    def getName(String hash){
        var result = names.get(hash)
        if (result == null){
            result = ""
        }
        return result
    }

    def getKeyData(byte[] pub){
        keyData.get(ByteBuffer.wrap(pub))
    }

    def addEncrypted(byte[] pub, byte[] encrypted){
        val key = findOrAddNew(pub)
        key.encrypted_private_key = encrypted
    }

    def addUnencrypted(byte[] pub, byte[] unencrypted){
        val key = findOrAddNew(pub)
        key.private_key = unencrypted
    }

    def addPoolFlag(byte[] pub){
        val key = findOrAddNew(pub)
        key.pool = true
    }

    def clear(){
        keyData.clear
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
    public var boolean pool = false
    public var long created

    def isCompressed(){
        public_key.get(0) != 0x04
    }
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

    /**
     * decrypt an encrypted private bitcoin key using the mkey. It also needs
     * the public bitcoin key because the iv is derived from its hash.
     */
    def decrypt(byte[] enc_priv_key, byte[] mkey, byte[] pub_key) throws InvalidCipherTextException {
        val iv = pub_key.doubleHash.take(16)
        setKeyAndIV(mkey, iv)
        return enc_priv_key.decrypt
    }

    /**
     * decrypt byte[] ciphertext using password, salt and iterations.
     * This is used for decrypting the encrypted master key
     */
    def decrypt(byte[] ciphertext, String pass, byte[] salt, int nDerivationIterations, int nDerivationMethod) throws Exception {
        setKeyFromPassphrase(pass, salt, nDerivationIterations, nDerivationMethod)
        return ciphertext.decrypt
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
