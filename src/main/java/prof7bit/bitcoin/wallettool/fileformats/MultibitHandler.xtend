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
import java.io.UnsupportedEncodingException
import java.net.URLDecoder
import java.util.ArrayList
import java.util.Hashtable
import java.util.List
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.params.KeyParameter
import prof7bit.bitcoin.wallettool.core.WalletKeyTool
import prof7bit.bitcoin.wallettool.exceptions.FormatFoundNeedPasswordException
import static extension prof7bit.bitcoin.wallettool.core.Ext.*

/**
 * Load and save keys in MultiBit wallet format
 */
class MultibitHandler extends AbstractImportExportHandler {
    val log = LoggerFactory.getLogger(this.class)

    override load(File file, String pass, String pass2) throws Exception {
        var KeyParameter aesKey = null
        val wallet = Wallet.loadFromFile(file)
        log.debug("MultiBit wallet with {} addresses has been loaded",
            wallet.keychain.length
        )
        getWalletKeyTool.params = wallet.networkParameters
        if (wallet.encrypted) {
            log.debug("wallet is encrypted")
            if (pass == null){
                throw new FormatFoundNeedPasswordException
            }else{
                aesKey = wallet.keyCrypter.deriveKey(pass)
            }
        }

        var allowFailed = false
        var count = 0
        for (ecKey : wallet.keychain){
            val addrStr = ecKey.toAddress(wallet.networkParameters).toString
            walletKeyTool.reportProgress(100 * count / wallet.keychain.length, addrStr)
            if (ecKey.encrypted){
                if (aesKey != null) {
                    try {
                        walletKeyTool.add(ecKey.decrypt(wallet.keyCrypter, aesKey))
                    } catch (KeyCrypterException e) {
                        val watch_only_key = new ECKey(null, ecKey.pubKey)
                        log.error("DECRYPT ERROR: {} {}",
                            addrStr,
                            ecKey.encryptedPrivateKey.toString
                        )
                        if (!allowFailed){
                            if (getWalletKeyTool.confirm("decryption error, continue?")){
                                allowFailed = true
                            } else {
                                throw new Exception("decryption failed")
                            }
                        }
                        watch_only_key.creationTimeSeconds = ecKey.creationTimeSeconds
                        walletKeyTool.add(watch_only_key)
                    }
                } else {
                    val watch_only_key = new ECKey(null, ecKey.pubKey)
                    watch_only_key.creationTimeSeconds = ecKey.creationTimeSeconds
                    log.info("importing {} as WATCH ONLY", addrStr)
                    walletKeyTool.add(watch_only_key)
                }
            } else {
                walletKeyTool.add(ecKey)
            }
            count = count + 1
        }

        // read the labels from the .info file
        val info = new MultibitInfo(file, walletKeyTool)
        info.readLabels
        log.debug("done")
    }

    override save(File file, String passphrase, String pass2) throws Exception {
        val wallet = new Wallet(getWalletKeyTool.getParams)

        var KeyParameter aesKey = null
        if (passphrase.length > 0){
            wallet.keyCrypter = new KeyCrypterScrypt
            aesKey = wallet.keyCrypter.deriveKey(passphrase)
        }

        val total = walletKeyTool.keyCount
        var count = 0
        for (key : getWalletKeyTool){
            val addr = key.addrStr
            val ecKey = key.ecKey
            walletKeyTool.reportProgress(100 * count / total, addr)
            if (key.hasPrivKey) {
                if (aesKey != null){
                    wallet.addKey(ecKey.encrypt(wallet.keyCrypter, aesKey))
                } else {
                    wallet.addKey(ecKey)
                }
            } else {
                wallet.addWatchedAddress(ecKey.toAddress(key.getParams), key.getCreationTimeSeconds)
                log.error("set {} as WATCH ONLY because private key is missing", addr)
            }
            count = count + 1
        }
        if (wallet.keychain.length + wallet.watchedScripts.length > 0){
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
        log.debug("reading Multibit .info file: " + infofile.path)
        readInfoFile()
        for (key : walletKeyTool){
            val label = list.get(key.addrStr)
            if (label != null){
                key.label = label
            }
        }
    }

    def writeLabels(){
        log.debug("writing Multibit .info file: " + infofile.path)
        val List<String> lines = new ArrayList
        val LS = System.getProperty("line.separator")
        lines.add("multiBit.info,1")
        lines.add("walletVersion,3")
        for (key : walletKeyTool){
            try {
                lines.add(String.format("receive,%s,%s",
                    key.addrStr, key.label.urlencode
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
