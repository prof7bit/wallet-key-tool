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

class BlockchainInfoStrategy extends ImportExportStrategy{
    private static final Logger log = LoggerFactory.getLogger(BlockchainInfoStrategy);

    static val AESBlockSize = 4
    static val AESKeySize = 256
    static val DefaultPBKDF2Iterations = 10;

    override load(File file, String pass) throws Exception {
        val b64Text = Files.toString(file, Charsets.UTF_8)
        val decrypted = decrypt_outer(b64Text, pass, DefaultPBKDF2Iterations)
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
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }


    private def decrypt_outer(String cipherText, String password, int iterations) throws InvalidCipherTextException {
        val cipherdata = Base64.decode(cipherText);

        //Seperate the IV and cipher data
        val iv = copyOfRange(cipherdata, 0, AESBlockSize * 4);
        val input = copyOfRange(cipherdata, AESBlockSize * 4, cipherdata.length);

        return decrypt(iv, input, password, iterations)
    }

    private def decrypt(byte[] iv, byte[] input, String password, int iterations)throws InvalidCipherTextException {
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

    }

    private def createCipher(String password, byte[] iv, int PBKDF2Iterations, Boolean forEncryption){
        val generator = new PKCS5S2ParametersGenerator
        val passbytes = PBEParametersGenerator.PKCS5PasswordToUTF8Bytes(password.toCharArray())
        generator.init(passbytes, iv, PBKDF2Iterations)
        val keyParam = generator.generateDerivedParameters(AESKeySize)

        val params = new ParametersWithIV(keyParam, iv)

        val padding = new ISO10126d2Padding
        val cipher = new PaddedBufferedBlockCipher(new CBCBlockCipher(new AESEngine()), padding)
        cipher.reset
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
