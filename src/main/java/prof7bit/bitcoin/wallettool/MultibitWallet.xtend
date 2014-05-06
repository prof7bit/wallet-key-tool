package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.NetworkParameters
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.params.KeyParameter

import static extension prof7bit.bitcoin.wallettool.Ext.*
import java.io.BufferedInputStream
import java.io.FileInputStream

class MultibitWallet implements IWallet {
    static val log = LoggerFactory.getLogger(MultibitWallet)
    var Wallet mbwallet
    var NetworkParameters mbparams
    var KeyParameter aesKey = null
    var (String)=>String promptFunction
    var loaded = false

    override save(String filename) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }

    override load(String filename) {
        log.debug("loading wallet file: " + filename)
        try {
            new BufferedInputStream(new FileInputStream(filename)).closeAfter [
                mbwallet = Wallet.loadFromFileStream(it)
            ]
            mbparams = mbwallet.networkParameters
            if (mbwallet.encrypted) {
                log.debug("wallet is encrypted")
                val pass = promptFunction.apply("Wallet is encrypted. Enter pass phrase")
                if (pass == null || pass.length == 0) {
                    log.debug("no pass phrase entered, will not attempt to decrypt")
                    aesKey = null
                } else {
                    log.debug("deriving AES key from pass phrase")
                    aesKey = mbwallet.keyCrypter.deriveKey(pass)
                }
            }
            loaded = true
        } catch (Exception e) {
            log.stacktrace(e)
        }
    }

    override dumpToConsole() {
        if (loaded){
            if (mbwallet.encrypted && aesKey == null) {
                println("no password entered, will not show keys")
            }
            for (i : 0 ..< keyCount) {
                println(getAddress(i) + " " + getKey(i))
            }
        } else {
            log.error("no wallet data was loaded")
        }
    }

    override setPromptFunction((String)=>String func) {
        promptFunction = func
    }

    override getKeyCount() {
        mbwallet.keychain.length
    }

    override getAddress(int i) {
        mbwallet.keychain.get(i).toAddress(mbparams).toString
    }

    override getKey(int i) {
        val key = mbwallet.keychain.get(i)
        if (key.encrypted) {
            if (aesKey != null) {
                try {
                    val key_unenc = key.decrypt(mbwallet.keyCrypter, aesKey)
                    key_unenc.getPrivateKeyEncoded(mbparams).toString
                } catch (KeyCrypterException e) {
                    "DECRYPTION ERROR " + key.encryptedPrivateKey.toString
                }
            } else {
                "ENCRYPTED"
            }
        } else {
            key.getPrivateKeyEncoded(mbparams).toString
        }
    }
}
