package prof7bit.bitcoin.wallettool.fileformats

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.crypto.KeyCrypterScrypt
import java.io.File
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.params.KeyParameter

/**
 * Load and save keys in MultiBit wallet format
 */
class MultibitStrategy extends prof7bit.bitcoin.wallettool.ImportExportStrategy {
    val log = LoggerFactory.getLogger(this.class)

    override load(File file, String pass) {
        log.debug("loading wallet file: " + file.path)
        var KeyParameter aesKey = null
        val wallet = Wallet.loadFromFile(file)
        log.info("MultiBit wallet with {} addresses has been loaded",
            wallet.keychain.length
        )
        getWalletKeyTool.params = wallet.networkParameters
        if (wallet.encrypted) {
            log.debug("wallet is encrypted")
            if (pass == null){
                val pass_answered = getWalletKeyTool.prompt("Wallet is encrypted. Enter pass phrase")
                if (pass_answered != null && pass_answered.length > 0) {
                    aesKey = wallet.keyCrypter.deriveKey(pass_answered)
                }
            }else{
                aesKey = wallet.keyCrypter.deriveKey(pass)
            }
        }

        var allowFailed = false
        for (key : wallet.keychain){
            if (key.encrypted){
                if (aesKey != null) {
                    try {
                        getWalletKeyTool.add(key.decrypt(wallet.keyCrypter, aesKey))
                    } catch (KeyCrypterException e) {
                        val watch_only_key = new ECKey(null, key.pubKey)
                        log.error("DECRYPT ERROR: {} {}",
                            key.toAddress(getWalletKeyTool.getParams).toString,
                            key.encryptedPrivateKey.toString
                        )
                        if (!allowFailed){
                            if (getWalletKeyTool.confirm("decryption error, continue?")){
                                allowFailed = true
                            } else {
                                return
                            }
                        }
                        watch_only_key.creationTimeSeconds = key.creationTimeSeconds
                        getWalletKeyTool.add(watch_only_key)
                    }
                } else {
                    val watch_only_key = new ECKey(null, key.pubKey)
                    watch_only_key.creationTimeSeconds = key.creationTimeSeconds
                    log.info("importing {} as WATCH ONLY", watch_only_key.toAddress(wallet.params))
                    getWalletKeyTool.add(watch_only_key)
                }
            } else {
                getWalletKeyTool.add(key)
            }
        }
    }

    override save(File file, String passphrase) {
        val wallet = new Wallet(getWalletKeyTool.getParams)
        log.debug("")
        for (key : getWalletKeyTool){
            if (key.hasPrivKey) {
                wallet.addKey(key.getEcKey)
            } else {
                wallet.addWatchedAddress(key.getEcKey.toAddress(key.getParams), key.getCreationTimeSeconds)
                log.error("set {} as WATCH ONLY because private key is missing",
                    key.getAddrStr
                )
            }
        }
        if (wallet.keychain.length + wallet.watchedScripts.length > 0){
            val scrypt = new KeyCrypterScrypt
            val aesKey = scrypt.deriveKey(passphrase)
            wallet.encrypt(scrypt, aesKey)
            wallet.setDescription("created by wallet-key-tool")
            wallet.setLastBlockSeenHeight(0)
            wallet.saveToFile(file)
            var msg = String.format("A new MultiBit wallet with %d addresses has been written to %s",
                wallet.keychain.length + wallet.watchedScripts.length,
                file.path
            )
            if (wallet.watchedScripts.length > 0) {
                msg = msg.concat(String.format(
                    "\n%d private keys were missing, exported them as watch-only. (watch-only is currently "
                    + "\nnot really supported by MultiBit, the result might not be what you expect.",
                    wallet.watchedScripts.length
                ))
            }
            getWalletKeyTool.alert(msg)
        } else {
            getWalletKeyTool.alert("there were no addresses or keys, wallet has not been exported")
        }
    }
}
