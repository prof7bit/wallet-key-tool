package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.crypto.KeyCrypterScrypt
import java.io.File
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.params.KeyParameter

import static extension prof7bit.bitcoin.wallettool.Ext.*

/**
 * Load and save keys in MultiBit wallet format
 */
class MultibitStrategy extends ImportExportStrategy {
    val log = LoggerFactory.getLogger(this.class)

    override load(File file, String pass) {
        log.debug("loading wallet file: " + file.path)
        var KeyParameter aesKey = null
        val wallet = Wallet.loadFromFile(file)
        walletKeyTool.params = wallet.networkParameters
        if (wallet.encrypted) {
            log.debug("wallet is encrypted")
            if (pass == null){
                val pass_answered = walletKeyTool.prompt("Wallet is encrypted. Enter pass phrase")
                if (pass_answered != null && pass_answered.length > 0) {
                    aesKey = wallet.keyCrypter.deriveKey(pass_answered)
                }
            }else{
                aesKey = wallet.keyCrypter.deriveKey(pass)
            }
        }

        for (key : wallet.keychain){
            if (key.encrypted){
                if (aesKey != null) {
                    try {
                        walletKeyTool.add(key.decrypt(wallet.keyCrypter, aesKey))
                    } catch (KeyCrypterException e) {
                        // FIXME: creation date for watch only keys
                        walletKeyTool.add(new ECKey(null, key.pubKey))
                        log.error("DECRYPT ERROR: {} {}",
                            key.toAddress(walletKeyTool.params).toString,
                            key.encryptedPrivateKey.toString
                        )
                    }
                } else {
                    walletKeyTool.add(new ECKey(null, key.pubKey))
                }
            } else {
                walletKeyTool.add(key)
            }
        }
        log.info("MultiBit wallet with {} addresses has been loaded",
            wallet.keychain.length
        )
    }

    override save(File file, String passphrase) {
        val wallet = new Wallet(walletKeyTool.params)
        for (key : walletKeyTool.keychain){
            if (key.hasPrivKey) {
                wallet.keychain.add(key.copy)
            } else {
                log.error("could not add {} to wallet because private key is missing",
                    key.toAddress(walletKeyTool.params)
                )
            }
        }
        if (wallet.keychain.length > 0){
            val scrypt = new KeyCrypterScrypt
            val aesKey = scrypt.deriveKey(passphrase)
            wallet.encrypt(scrypt, aesKey)
            wallet.setDescription("created by wallet-key-tool")
            wallet.saveToFile(file)
            var msg = String.format("A new MultiBit wallet with %d addresses has been written to %s",
                wallet.keychain.length,
                file.path
            )
            if (wallet.keychain.length < walletKeyTool.keychain.length) {
                msg = msg.concat("\nsome private keys were missing, see error log for details!")
            }
            walletKeyTool.alert(msg)
        } else {
            walletKeyTool.alert("there were no private keys, wallet has not been exported")
        }
    }
}
