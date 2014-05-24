/**
 * (c) 2014 Bernd Kreuss
 */

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

/**
 * Wallet.dat import handler. This handler does not need any
 * non-java dependency to read the Berkeley-db B-tree files.
 * Reverse engineered with inspiration from pywallet.py,
 * db_page.h, db_dump and a hex editor.
 */
class WalletDatHandler extends AbstractImportExportHandler {
    val log = LoggerFactory.getLogger(this.class)

    /**
     * Try to import keys and labels from a bitcoin-core wallet.dat file.
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
                val addr = ecKey.toAddress(params).toString
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

/**
 * Parse a wallet.dat file and provide access
 * to its keys. This class can not be used to
 * write or create new wallets, its read-only.
 */
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

    /**
     * Parse the file (or throw exception if unreadable).
     * If the constructor returns then this WalletDat
     * Object will hold collections of all parsed keys
     * that can be read with the public methods that
     * are provided for this purpose. It can only read
     * existing and not write. The method isEncrypted()
     * can be used to test whether it is encrypted and
     * the decrypt() method should be used to decrypt
     * all keys.
     */
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
        rawKeyList.addLabel(hash, name)
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

    /**
     * @return true if the wallet contains an encrypted
     * master-key which means all keys are encrypted.
     */
    def isEncrypted(){
        mkey_encrypted_key != null
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
     * Decrypt (if encrypted) the keys in the raw key list.
     * If the wallet is not encrypted this does nothing.
     * After decryption succeeded the keys can be accessed
     * through the other methods, if it fails an exception
     * might be thrown. Because it is not guaranteed that
     * it will always throw when the password was wrong the
     * code that will later try to use the decrypted keys
     * must check that public and private keys actually make
     * sense and fit together (which the importer will do
     * anyways).
     */
    def decrypt(String password) throws Exception {
        if (encrypted){
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

    /**
     * Return the collection of all WalletDatRawKeyData objects.
     * This is used by the importer after the wallet has been
     * completely parsed and decrypted. They are not checked for
     * consistency or decryption errors, this must be done
     * separately by the application that uses them (must check
     * that private key and public key actually fit together)!
     */
    def getKeys() {
        rawKeyList.keyData.values
    }

    /**
     * get the label for a bitcoin address or "" if not found.
     */
    def getAddrLabel(String addr){
        rawKeyList.getLabel(addr)
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

        for (pgno : 0..last_pgno) {
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
    private def readAllLeafPages(BerkeleyDBLeafPage first) throws IOException {
        var page = first
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

/**
 * Abstract base class for all bdb pages. A Page is a block
 * of the file of fixed size, the entire file is made up of
 * such pages. There are several types of pages but all of
 * them share a minimum of information like page number,
 * next/previous page, page type, etc. This class does not
 * expose all these fields, only the bare minimum needed to
 * read through a b-tree file.
 */
abstract class BerkeleyDBPage {
    // page types
    static val P_LBTREE    = 5   /* B-tree leaf. */

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
 * this is a leaf page, it contains all the data. Data
 * is organized as key/value pairs. Each of them consists
 * of two entries, the page also contains a lookup table
 * to find the offsets of these data items to be able to
 * simply access them by index number. Even index numbers
 * are the key and the odd number directly following it is
 * its value. Its pretty simple actually.
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
 * This is only used for page #0 to read magic, version,
 * page size, etc. Although we read only the first few
 * bytes it should be noted that this is also a complete
 * page, its just mostly empty. More similar meta data
 * pages might appear later in the file but we only care
 * about the first one right at the start of the file,
 * it contains all we need.
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
 * and labels while they are parsed from wallet.dat
 */
class WalletDatRawKeyDataList {
    /**
     * the keys in this map are indexed by their public key
     * since this is also the way Bitcoin handles it.
     * Because we cannot directly use a byte[] as index of
     * a hash map (byte[] lacks proper implementation of
     * equals() and other comparable methods we are wrapping
     * it into a ByteBuffer which is a lightweight and simple
     * solution to this problem.
     */
    public val Map<ByteBuffer, WalletDatRawKeyData> keyData = new HashMap

    /**
     * we are collecting the labels in a separate map because
     * they are indexed by bitcoin address rather than public
     * key and at this stage (while still parsing stuff from
     * the bdb file) its just simpler that way. May higher
     * layers at a later time take care of combining them.
     */
    public val Map<String, String> labels = new HashMap

    /**
     * @param pub byte array with public key
     * @return WalletDatRawKeyData object for this key
     * or a newly created instance of such (that was
     * added to the map) if it was not yet in the map.
     */
    def findOrAddNew(byte[] pub){
        var key = getKeyData(pub)
        if (key == null){
            key = new WalletDatRawKeyData
            key.public_key = pub
            keyData.put(ByteBuffer.wrap(pub), key)
        }
        return key
    }

    /**
     * @param addr the bitcoin address
     * @param label to assign to this address
     */
    def addLabel(String addr, String label){
        labels.put(addr, label)
    }

    /**
     * @param the bitcoin address
     * @return the label or "" if not found.
     */
    def getLabel(String addr){
        var result = labels.get(addr)
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

    /**
     * This adds a flag to the key to mark it as "reserve",
     * this is done for all keys that are mentioned in the
     * "pool" list in the wallet file, so we can later
     * label them differently, otherwise there is nothing
     * special about these keys, they are treated like all
     * other keys, its up to the user to decide whether to
     * use that label for anything or just ignore it.
     */
    def addPoolFlag(byte[] pub){
        val key = findOrAddNew(pub)
        key.pool = true
    }

    def clear(){
        keyData.clear
        labels.clear
    }
}


/**
 * Raw key data for a single key parsed from wallet.dat
 * Objects of this type are stored in a map inside the
 * WalletDatRawKeyDataList container which is populated
 * during parsing the wallet. After completely reading
 * and optionally decrypting the wallet this contains
 * all information about a key with the only exception
 * of label which is stored in a separate map.
 *
 * Note: during decryption there is no check performed
 * that public and private key actually fit together,
 * this must be checked by the application that is going
 * to use these keys. The WalletDatHandler import handler
 * will perform this check (its needed anyways).
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
        return plaintext.take(processLength + doFinalLength)
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

    /**
     * concatenate passbytes and salt and then apply nDerivationIterations iterations of sha512
     * and return a new byte array of 64 bytes containing the result. This is used for deriving
     * key and iv from the wallet password.
     */
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
     * apply sha256 double hash
     * @param data byte array to be hashed
     * @return new byte array containing sha256(sha256(data))
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
