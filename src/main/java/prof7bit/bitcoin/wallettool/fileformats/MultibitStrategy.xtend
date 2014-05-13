package prof7bit.bitcoin.wallettool.fileformats

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.crypto.KeyCrypterScrypt
import com.google.common.base.Charsets
import com.google.common.base.Joiner
import com.google.common.io.Files
import java.io.File
import java.io.IOException
import java.net.URLDecoder
import java.net.URLEncoder
import java.util.ArrayList
import java.util.Hashtable
import java.util.List
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.params.KeyParameter
import prof7bit.bitcoin.wallettool.ImportExportStrategy
import prof7bit.bitcoin.wallettool.WalletKeyTool

import static extension prof7bit.bitcoin.wallettool.Ext.*
import java.io.UnsupportedEncodingException

/**
 * Load and save keys in MultiBit wallet format
 */
class MultibitStrategy extends ImportExportStrategy {
    val log = LoggerFactory.getLogger(this.class)

    override load(File file, String pass) throws Exception {
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

        // read the labels from the .info file
        val info = new MultibitInfo(file, walletKeyTool)
        info.readLabels
    }

    override save(File file, String passphrase) throws Exception {
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

            // write the .info file
            val info = new MultibitInfo(file, walletKeyTool)
            info.writeLabels

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
            walletKeyTool.alert(msg)
        } else {
            walletKeyTool.alert("there were no addresses or keys, wallet has not been exported")
        }
    }
}

/**
 * This represents the .info file that contains the labels
 */
class MultibitInfo {
    val log = LoggerFactory.getLogger(this.class)
    val list = new Hashtable<String, String>

    var File infofile
    var WalletKeyTool walletKeyTool

    new(File file, WalletKeyTool wkt){
        infofile = new File(file.parent, Files.getNameWithoutExtension(file.path) + ".info")
        walletKeyTool = wkt
    }

    def readLabels() {
        readInfoFile()
        for (key : walletKeyTool){
            val label = list.get(key.addrStr)
            if (label != null){
                key.label = label
            }
        }
    }

    def writeLabels(){
        var List<String> lines = new ArrayList
        val LS = System.getProperty("line.separator")
        lines.add("multiBit.info,1")
        lines.add("walletVersion,3")
        for (key : walletKeyTool){
            try {
                lines.add(String.format("receive,%s,%s",
                    key.addrStr, URLEncoder.encode(key.label, Charsets.UTF_8.name)
                ))
            } catch (UnsupportedEncodingException exc) {
                lines.add(String.format("receive,%s,unknown", key.addrStr))
            }
        }
        try {
            Files.write(Joiner.on(LS).join(lines), infofile, Charsets.UTF_8)
        } catch (IOException e) {
            log.stacktrace(e)
        }
    }

    private def readInfoFile(){
        try {
            val lines = Files.readLines(infofile, Charsets.UTF_8)
            for (line : lines) {
                val words = line.split(",")
                if (words.length == 3){
                    if (words.get(0) == "receive"){
                        list.put(words.get(1), URLDecoder.decode(words.get(2), Charsets.UTF_8.name))
                    }
                }
            }
        } catch (IOException e) {
            log.info("could not read info file {}", infofile)
        } catch (Exception e) {
            log.stacktrace(e)
        }
    }
}
