package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.crypto.KeyCrypterScrypt
import java.io.File
import org.spongycastle.crypto.params.KeyParameter

import static extension prof7bit.bitcoin.wallettool.Ext.*

/**
 * Load and save keys in MultiBit wallet format
 */
class MultibitWallet extends AbstractWallet {

    new((String)=>String promptFunction, (String)=>void alertFunction) {
        super(promptFunction, alertFunction)
    }

    /**
     * Load keys from the MultiBit .wallet file
     */
    override load(File file) {
        log.debug("loading wallet file: " + file.path)
        var KeyParameter aesKey = null
        try {
            val wallet = Wallet.loadFromFile(file)
            params = wallet.networkParameters
            if (wallet.encrypted) {
                log.debug("wallet is encrypted")
                val pass = promptFunction.apply("Wallet is encrypted. Enter pass phrase")
                if (pass != null && pass.length > 0) {
                    aesKey = wallet.keyCrypter.deriveKey(pass)
                }
            }

            for (key : wallet.keychain){
                if (key.encrypted){
                    if (aesKey != null) {
                        try {
                            keychain.add(key.decrypt(wallet.keyCrypter, aesKey))
                        } catch (KeyCrypterException e) {
                            keychain.add(new ECKey(null, key.pubKey))
                            log.error("DECRYPT ERROR: {} {}",
                                key.toAddress(params).toString,
                                key.encryptedPrivateKey.toString
                            )
                        }
                    } else {
                        keychain.add(new ECKey(null, key.pubKey))
                    }
                } else {
                    keychain.add(key)
                }
            }
            log.info("MultiBit wallet with {} addresses has been loaded",
                keychain.length
            )
        } catch (Exception e) {
            log.stacktrace(e)
        }
    }

    /**
     * Save keys to a MultiBit .wallet file
     */
    override save(File file, String passphrase) {
        val wallet = new Wallet(params)
        for (key : keychain){
            if (key.hasPrivKey) {
                wallet.keychain.add(key.copy)
            } else {
                log.error("could not add {} to wallet because private key is missing",
                    key.toAddress(params)
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
            if (wallet.keychain.length < keychain.length) {
                msg = msg.concat("\nsome private keys were missing, see error log for details!")
            }
            alertFunction.apply(msg)
        } else {
            alertFunction.apply("there were no private keys, wallet has not been exported")
        }
    }
}
