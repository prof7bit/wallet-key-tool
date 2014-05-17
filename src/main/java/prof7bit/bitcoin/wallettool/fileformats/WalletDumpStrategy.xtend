package prof7bit.bitcoin.wallettool.fileformats

import com.google.common.base.Charsets
import com.google.common.base.Joiner
import com.google.common.io.CharStreams
import com.google.common.io.Files
import java.io.File
import java.io.Reader
import java.io.StringReader
import java.io.UnsupportedEncodingException
import java.net.URLDecoder
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.ArrayList
import java.util.Date
import java.util.List
import java.util.TimeZone
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.InvalidCipherTextException
import org.spongycastle.crypto.PBEParametersGenerator
import org.spongycastle.crypto.engines.AESFastEngine
import org.spongycastle.crypto.generators.OpenSSLPBEParametersGenerator
import org.spongycastle.crypto.modes.CBCBlockCipher
import org.spongycastle.crypto.paddings.PaddedBufferedBlockCipher
import org.spongycastle.util.encoders.Base64
import prof7bit.bitcoin.wallettool.ImportExportStrategy
import prof7bit.bitcoin.wallettool.KeyObject

import static extension prof7bit.bitcoin.wallettool.Ext.*

/**
 * read and write Bitcoin-Qt "dumpwallet" format or
 * Multibit backup file (*.key) or Schildbach backup
 */
class WalletDumpStrategy  extends ImportExportStrategy {
    val log = LoggerFactory.getLogger(this.class)
    val LS = System.getProperty("line.separator")
    val formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'") => [
        timeZone = TimeZone.getTimeZone("GMT")
    ]

    override load(File file, String pass) throws Exception {
        try {
            log.debug("trying to read file: " + file.path)
            readUnencrypted(file)
            log.info("unencrypted backup import succeeded")
        } catch (Exception e) {
            log.debug("unreadable, maybe encrypted, trying again with password")
            var pass2 = pass
            if (pass2 == null){
                pass2 = walletKeyTool.prompt("Password")
            }
            if (pass2 != null && pass2.length > 0){
                try {
                    readEncrypted(file, pass2)
                    log.info("Multibit encrypted backup import succeeded")
                } catch (Exception e2) {
                    throw new Exception("decryption failed: " + e.message)
                }
            } else {
                log.info("import canceled")
            }
        }
    }

    override save(File file, String pass) throws Exception {
        val lines = formatLines
        val crypter = new MultibitBackupCrypter
        if (pass.length > 0){
            val encrypted = crypter.encrypt(lines, pass)
            Files.write(encrypted, file, Charsets.UTF_8)
            log.info("encrypted wallet dump file written to {}", file.path)
        } else {
            Files.write(lines, file, Charsets.UTF_8)
            log.info("unencrypted wallet dump file written to {}", file.path)
        }
    }

    private def readEncrypted(File file, String password) throws Exception {
        val encrypted = Files.toString(file, Charsets.UTF_8)
        val crypter = new MultibitBackupCrypter
        val plain = crypter.decrypt(encrypted, password)
        val reader = new StringReader(plain)
        try {
            reader.readLines
        } finally {
            reader.close
        }
    }

    private def readUnencrypted(File file) throws Exception {
        val contents = Files.toString(file, Charsets.UTF_8)
        val reader = new StringReader(contents)
        try {
            reader.readLines
        } finally {
            reader.close
        }
    }

    private def readLines(Reader r) throws Exception {
        val lines = CharStreams.readLines(r)
        var count = 0
        for (line : lines){
            if (!line.startsWith("#")){
                val fields = line.split(" ")
                if (fields.length > 1){
                    val key = new KeyObject(
                        fields.get(0),
                        walletKeyTool.params,
                        formatter.parse(fields.get(1)).time / 1000L
                    )

                    // additional fields are optional, the bitcoin-core client
                    // for example might add a label=something field into the next
                    // column and that is what we try to read now if it exists
                    for (i : 2..<fields.length){
                        val field = fields.get(i)
                        if (field.equals("change=1")){
                            key.label = key.label + "(change)"
                        }
                        if (field.equals("reserve=1")){
                            key.label = key.label + "(reserve)"
                        }
                        if (field.startsWith("label=")){
                            key.label = key.label + URLDecoder.decode(field.substring(6), Charsets.UTF_8.name)
                        }
                    }

                    log.debug("importing {}", key.addrStr)
                    walletKeyTool.add(key)
                }
            }
            count = count + 1
        }
    }

    private def formatLines() throws UnsupportedEncodingException {
        val List<String> lines = new ArrayList
        lines.add("# Wallet dump created by prof7bit/wallet-key-tool")
        lines.add("# * Created on " + formatter.format(new Date()))
        for (key : walletKeyTool) {
            var line = key.privKeyStr + " " + formatter.format(new Date(key.creationTimeSeconds * 1000L))
            if (key.label != ""){
                line = line + " label=" + key.label.urlencode
            }
            line = line + " # " + key.addrStr
            lines.add(line)
        }
        return Joiner.on(LS).join(lines)
    }
}


class MultibitBackupCrypter {
    static val NUM_ITER = 1024
    static val PREFIX = "Salted__"
    static val SALT_LENGTH = 8
    static val KEY_LENGTH = 256
    static val IV_LENGTH = 128

    static val random = new SecureRandom

    def decrypt(String cipherText, String password) throws InvalidCipherTextException {
        val textAsBytes = Base64.decode(cipherText)
        val lengthPrefix = PREFIX.length
        val lengthPrefixAndSalt = lengthPrefix + SALT_LENGTH
        val lengthCipherBytes = textAsBytes.length - lengthPrefix - SALT_LENGTH

        val cipherBytes = newByteArrayOfSize(lengthCipherBytes)
        System.arraycopy(textAsBytes, lengthPrefixAndSalt, cipherBytes, 0, lengthCipherBytes)

        val salt = newByteArrayOfSize(SALT_LENGTH)
        System.arraycopy(textAsBytes, lengthPrefix, salt, 0, SALT_LENGTH);

        val aes = createCipher(password, salt, false)
        val decryptedBytes = newByteArrayOfSize(aes.getOutputSize(lengthCipherBytes))
        val processLength = aes.processBytes(cipherBytes, 0, lengthCipherBytes, decryptedBytes, 0);
        aes.doFinal(decryptedBytes, processLength);

        return new String(decryptedBytes, Charsets.UTF_8).trim();
    }

    def encrypt(String plainText, String password) throws InvalidCipherTextException {
        val salt = newByteArrayOfSize(SALT_LENGTH)
        random.nextBytes(salt)

        val aes = createCipher(password, salt, true)

        val plainBytes = plainText.getBytes(Charsets.UTF_8)
        val encBytes = newByteArrayOfSize(aes.getOutputSize(plainBytes.length))
        val procLen = aes.processBytes(plainBytes, 0, plainBytes.length, encBytes, 0);
        val finalLen = aes.doFinal(encBytes, procLen);

        val resultLen = PREFIX.length + salt.length + procLen + finalLen
        val resultBytes = newByteArrayOfSize(resultLen)
        System.arraycopy(PREFIX.bytes, 0, resultBytes, 0, PREFIX.length)
        System.arraycopy(salt, 0, resultBytes, PREFIX.length, salt.length)
        System.arraycopy(encBytes, 0, resultBytes, PREFIX.length + salt.length, procLen + finalLen)
        return new String(Base64.encode(resultBytes))
    }

    private def createCipher(String password, byte[] salt, Boolean forEncryption){
        val generator = new OpenSSLPBEParametersGenerator
        val passbytes = PBEParametersGenerator.PKCS5PasswordToBytes(password.toCharArray)

        generator.init(passbytes, salt, NUM_ITER)
        val ivAndKey =  generator.generateDerivedParameters(KEY_LENGTH, IV_LENGTH);

        val cipher = new PaddedBufferedBlockCipher(new CBCBlockCipher(new AESFastEngine))
        cipher.init(forEncryption, ivAndKey)
        return cipher
    }
}
