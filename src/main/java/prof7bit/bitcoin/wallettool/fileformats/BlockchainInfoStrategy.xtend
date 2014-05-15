package prof7bit.bitcoin.wallettool.fileformats

import com.google.bitcoin.core.Base58
import com.google.bitcoin.core.ECKey
import com.google.bitcoin.params.MainNetParams
import com.google.common.base.Charsets
import com.google.common.io.Files
import java.io.File
import java.math.BigInteger
import org.json.JSONObject
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.InvalidCipherTextException
import org.spongycastle.crypto.PBEParametersGenerator
import org.spongycastle.crypto.engines.AESEngine
import org.spongycastle.crypto.generators.PKCS5S2ParametersGenerator
import org.spongycastle.crypto.modes.CBCBlockCipher
import org.spongycastle.crypto.paddings.ISO10126d2Padding
import org.spongycastle.crypto.paddings.PaddedBufferedBlockCipher
import org.spongycastle.crypto.params.ParametersWithIV
import org.spongycastle.util.encoders.Base64
import prof7bit.bitcoin.wallettool.ImportExportStrategy
import prof7bit.bitcoin.wallettool.KeyObject

/**
 * Strategy to handle the blockchain.info
 * "My Wallet" backup file format (*.aes.json)
 */
class BlockchainInfoStrategy extends ImportExportStrategy{
    private static final Logger log = LoggerFactory.getLogger(BlockchainInfoStrategy);

    static val AESBlockSize = 4
    static val AESKeySize = 256
    static val DefaultPBKDF2Iterations = 10;

    /**
     * Entry point for the WalletKeyTool import, tries to import the
     * file into the current WalletKeyTool instance.
     * @param file the file to be imported
     * @param pass the password for decryption or null (then it will prompt)
     * @throws Exception if import fails containing a human readable and comprehensible
     * error message explaining what happened (message string will be presented to the user)
     */
    override load(File file, String pass) throws Exception {
        var password = pass
        if (password == null){
            password = walletKeyTool.prompt("password")
            if (password == null || password.length == 0){
                throw new Exception("Import canceled")
            }
        }
        val b64Text = Files.toString(file, Charsets.UTF_8)
        val decrypted = decrypt(b64Text, password, DefaultPBKDF2Iterations)
        try {
            parseAndImport(decrypted)
        } catch (Exception e) {
            log.trace(decrypted)
            val e2 = new Exception("Decryption succeeded but import failed: '"
                + e.toString + "' Use log level TRACE to see all details"
            )
            e2.initCause(e)
            throw e2
        }
    }

    /**
     * Parse the decrypted json wallet and try to add all its keys to the
     * walletKeyTool instance.
     * @param jsonStr the plaintext json string representing the entire wallet
     * @throws Exception when the data is malformed and import fails
     */
    private def parseAndImport(String jsonStr)throws Exception {
        var int cntImported = 0
        var int cntMissing = 0
        val data = new JSONObject(jsonStr)
        val keys = data.getJSONArray("keys")
        for (i : 0..<keys.length){
            val bciKey = keys.getJSONObject(i)
            var String priv = null
            var ECKey ecKey = null
            val addr = bciKey.getString("addr")
            if (bciKey.has("priv")){
                priv = bciKey.getString("priv")
            }
            if (priv != null){
                ecKey = decodeBase58PK(priv, addr)
                if (bciKey.has("created_time")){
                    ecKey.creationTimeSeconds = bciKey.getLong("created_time")
                }

                // wrap it with our own object and set optional extra info
                val key = new KeyObject(ecKey, walletKeyTool.params)
                if (bciKey.has("label")){
                    key.label = bciKey.getString("label")
                }
                walletKeyTool.add(key)
                cntImported = cntImported + 1
            }else{
                // watch only not implemented
                log.info("skipped {} because it is watch only", addr)
                cntMissing = cntMissing + 1
            }
        }
        log.info("import complete: {} keys imported, {} skipped because keys were missing",
            cntImported, cntMissing
        )
    }


    override save(File file, String pass) throws Exception {
        throw new UnsupportedOperationException("blockchain.info export is not yet implemented")
    }

    /**
     * This is used to remove the outer layer of encryption (the whole file).
     * @param cipherText the base64 encoded text of the backup file
     * @param password needed for decryption, this is the blockchain.info user password
     * @param iterations the PBKDF2 iterations (10 by default if not otherwise specified)
     * @return decrypted plain text. This would be the json string representation of the wallet
     * @throws InvalidCipherTextException if decryption fails
     */
    private def decrypt(String cipherText, String password, int iterations) throws InvalidCipherTextException {
        val cipherdata = Base64.decode(cipherText);

        //Separate the IV and cipher data
        val iv = copyOfRange(cipherdata, 0, AESBlockSize * 4);
        val input = copyOfRange(cipherdata, AESBlockSize * 4, cipherdata.length);

        return decrypt(iv, input, password, iterations)
    }

    /**
     * Decrypt the byte array according to the specifications given by blockchain.info.
     * @param iv initialization vector used to initialize the cipher
     * @param input byte array with encrypted data
     * @param password used to derive the key
     * @param iterations number of PBKDF2 iterations
     * @throws InvalidCipherTextException if decryption fails
     */
    private def decrypt(byte[] iv, byte[] input, String password, int iterations) throws InvalidCipherTextException {
        val cipher = createCipher(password, iv, iterations, false)

        // decrypt
        val buf = newByteArrayOfSize(cipher.getOutputSize(input.length))
        var len = cipher.processBytes(input, 0, input.length, buf, 0)
        len = len + cipher.doFinal(buf, len)

        // remove padding
        val out = newByteArrayOfSize(len)
        System.arraycopy(buf, 0, out, 0, len);

        return new String(out, Charsets.UTF_8);
    }

    def encrypt(String plainText, String password) throws InvalidCipherTextException {
        return ""
    }

    /**
     * Create and initialize a Cipher object usable to perform the decryption according
     * to blockchain.info's specifications.
     * @param password used to derive the key
     * @param iv initialization vector
     * @param PBKDF2Iterations number of PBKDF2 iterations
     * @param forEncryption shall the cipher be initialized for encryption or decryption
     * @return a newly initialized Cipher object usable to encrypt or decrypt the data from blockchain.info
     */
    private def createCipher(String password, byte[] iv, int PBKDF2Iterations, Boolean forEncryption){
        val generator = new PKCS5S2ParametersGenerator
        val passbytes = PBEParametersGenerator.PKCS5PasswordToUTF8Bytes(password.toCharArray())
        generator.init(passbytes, iv, PBKDF2Iterations)
        val keyParam = generator.generateDerivedParameters(AESKeySize)

        val params = new ParametersWithIV(keyParam, iv)

        val padding = new ISO10126d2Padding
        val cipher = new PaddedBufferedBlockCipher(new CBCBlockCipher(new AESEngine()), padding)
        cipher.init(forEncryption, params)
        return cipher
    }

    private def copyOfRange(byte[] source, int from, int to) {
        val range = newByteArrayOfSize(to - from)
        System.arraycopy(source, from, range, 0, range.length);
        return range;
    }

    /**
     * Try to produce an ECKey Object from the given arguments.
     * BCI has a very uncommon way of encoding the private key, its not the
     * usual dumped private key format of the Satoshi client, its just base58 of
     * the key bytes. Most importantly it is also lacking the information whether
     * it is meant to produce a compressed or uncompressed public key. For this
     * we try both and compare with the supplied bitcoin address, if none of
     * them match (which should never happen) then this will throw an exception.
     *
     * @param base58Priv String containing the BCI encoded private key
     * @param addr String containing the bitcoin address
     * @return a new ECKey object representing this key
     * @throws Exception if the input can not be interpreted in any meaningful way
     */
    private def ECKey decodeBase58PK(String base58Priv, String addr) throws Exception {
        val privBytes = Base58.decode(base58Priv);
        var ecKey = new ECKey(new BigInteger(1, privBytes), null, false);
        if (ecKey.toAddress(new MainNetParams).toString.equals(addr)){
            log.debug("{} has uncompressed key", addr)
            return ecKey;
        } else {
            ecKey = new ECKey(new BigInteger(1, privBytes), null, true);
            if (ecKey.toAddress(new MainNetParams).toString.equals(addr)){
                log.debug("{} has compressed key", addr)
                return ecKey;
            } else {
                val err = addr + " and private key don't match, neither compressed nor uncompressed"
                log.error(err)
                throw new Exception(err)
            }
        }
    }
}
