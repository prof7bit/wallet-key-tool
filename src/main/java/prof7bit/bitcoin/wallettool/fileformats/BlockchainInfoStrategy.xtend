package prof7bit.bitcoin.wallettool.fileformats

import com.google.common.base.Charsets
import com.google.common.io.Files
import java.io.File
import org.json.simple.JSONArray
import org.json.simple.JSONObject
import org.json.simple.JSONValue
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
import com.google.bitcoin.core.DumpedPrivateKey

class BlockchainInfoStrategy extends ImportExportStrategy{
    static val AESBlockSize = 4
    static val AESKeySize = 256
    static val DefaultPBKDF2Iterations = 10;

    override load(File file, String pass) throws Exception {
        val b64Text = Files.toString(file, Charsets.UTF_8)
        val decrypted = decrypt_outer(b64Text, "test", DefaultPBKDF2Iterations)

        println(decrypted)

        val json = JSONValue.parse(decrypted) as JSONObject
        val keys = json.get("keys") as JSONArray
        for (key : keys){
            val addr = (key as JSONObject).get("addr") as String
            val priv = (key as JSONObject).get("priv") as String

            println(addr + " " + priv)
        }
    }

    override save(File file, String pass) throws Exception {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }


    def decrypt_outer(String cipherText, String password, int iterations) throws InvalidCipherTextException {
        val cipherdata = Base64.decode(cipherText);

        //Seperate the IV and cipher data
        val iv = copyOfRange(cipherdata, 0, AESBlockSize * 4);
        val input = copyOfRange(cipherdata, AESBlockSize * 4, cipherdata.length);

        return decrypt(iv, input, password, iterations)
    }

    def decrypt(byte[] iv, byte[] input, String password, int iterations)throws InvalidCipherTextException {
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
}
