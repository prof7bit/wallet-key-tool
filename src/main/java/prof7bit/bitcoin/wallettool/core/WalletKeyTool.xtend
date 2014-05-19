package prof7bit.bitcoin.wallettool.core

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import java.io.File
import java.math.BigInteger
import java.util.ArrayList
import java.util.Date
import java.util.Iterator
import java.util.List
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.exceptions.FormatFoundNeedPasswordException
import prof7bit.bitcoin.wallettool.fileformats.AbstractImportExportHandler
import prof7bit.bitcoin.wallettool.fileformats.BlockchainInfoHandler
import prof7bit.bitcoin.wallettool.fileformats.MultibitHandler
import prof7bit.bitcoin.wallettool.fileformats.WalletDumpHandler
import prof7bit.bitcoin.wallettool.exceptions.NeedSecondaryPasswordException

class WalletKeyTool implements Iterable<KeyObject> {
    val log = LoggerFactory.getLogger(this.class)
    @Property var (String)=>String promptFunc = []
    @Property var (String)=>boolean YesNoFunc = []
    @Property var (String)=>void alertFunc = []
    @Property var (Object)=>void notifyChangeFunc = []
    @Property var (int,String)=>void reportProgressFunc = [p, s|]
    @Property var NetworkParameters params = null
    private var List<KeyObject> keys = new ArrayList

    var AbstractImportExportHandler importExportStrategy

    def prompt(String msg){
        promptFunc.apply(msg)
    }

    def alert(String msg){
        alertFunc.apply(msg)
    }

    def confirm(String msg){
        yesNoFunc.apply(msg)
    }

    def notifyChange(){
        notifyChangeFunc.apply(null)
    }

    def reportProgress(int percent, String status){
        reportProgressFunc.apply(percent, status)
    }

    def void setImportExportStrategy(Class<? extends AbstractImportExportHandler> strat) {
        try {
            importExportStrategy = strat.newInstance
        } catch (Exception e) {
            // WTF? This is impossible!
            throw new RuntimeException("you just found a bug, please report it", e)
        }
        importExportStrategy.walletKeyTool = this
    }

    private val IMPORT_SUCCESS = 0
    private val IMPORT_UNREADABLE = 1
    private val IMPORT_FORMAT_IDENTIFIED_NEED_PASSWORD = 2
    private val IMPORT_NEED_SECONDARY_PASSWORD = 3

    /**
     * Try to load with all of the existing handlers. The function will attempt to determine
     * automatically which file type this is and which handler to use. It works in several
     * phases, first it will try all handlers without password, then ask for password and try
     * them all again. There is a shortcut: If in the first round a handler returns that it can
     * identify this format and just needs a password then only this handler will be tried again
     * in subsequent rounds instead of all of them. A secondary password will only be asked if
     * one of the handlers explicitly asks for it, again in this case it is assumed that the
     * format is now identified and no other handlers need to be tried anymore. If this
     * function returns then the import has succeeded, the only other possible exit from this
     * function is an Exception which means unreadable file format, wrong pass or user cancel.
     * @param file the file to load
     * @param pass primary password (or null which may cause a prompt if needed)
     * @param pass2 secondary password (or null which may cause a prompt if needed)
     * @throws Exception if none of the import handlers succeeded or if the user clicks cancel
     */
    def load(File file, String pass, String pass2) throws Exception {
        var password1 = pass
        var password2 = pass
        var tryAll = true

        // there are 3 exits from this loop:
        // * return on success
        // * exception when it fails even with password
        // * exception in the askImportPass() method (user cancel)
        while (true){
            val result = tryLoad(file, password1, password2, tryAll)
            if (result == IMPORT_SUCCESS) {
                return
            } else if (result == IMPORT_NEED_SECONDARY_PASSWORD) {
                tryAll = false
                password2 = askImportPass("please enter secondary password")
            } else if (result == IMPORT_FORMAT_IDENTIFIED_NEED_PASSWORD){
                tryAll = false
                password1 = askImportPass("please enter password")
            } else if (result == IMPORT_UNREADABLE){
                if (password1 == null){
                    password1 = askImportPass("please enter password")
                } else {
                    throw new Exception("import failed, see log level TRACE for details")
                }
            }
        }
    }

    /**
     * Try to load the file, with all handlers until one of them returns
     * something other than IMPORT_UNREADABLE. If tryAll is false then
     * try only with the current (last used) handler.
     * @param file the file to load
     * @param pass primary password (or null)
     * @param pass2 secondary password (or null)
     * @param tryAll should all handlers be tried or only the current one
     * @return the return status (one of the IMPORT_* constants)
     */
    private def tryLoad(File file, String pass, String pass2, Boolean tryAll){
        if (tryAll){
            return tryLoadWithEveryStrat(file, pass, pass2)
        } else {
            return tryLoadWithStrategy(file, pass, pass2, null)
        }
    }

    /**
     * Try to load with every available handler, stop if one of them returns
     * something other than IMPORT_UNREADABLE.
     * @param file the file to load
     * @param pass primary password (or null)
     * @param pass2 secondary password (or null)
     * @return the return status (one of the IMPORT_* constants)
     */
    private def tryLoadWithEveryStrat(File file, String pass, String pass2){
        val int[] result = #[0]
        val strategies = #[
            WalletDumpHandler,
            MultibitHandler,
            BlockchainInfoHandler
        ]
        strategies.findFirst[
            result.set(0, tryLoadWithStrategy(file, pass, pass2, it as Class<AbstractImportExportHandler>))
            return result.get(0) != IMPORT_UNREADABLE
        ]
        return result.get(0)
    }

    /**
     * Try to load with the handler class that is passed as the last argument. If it is
     * null then use the current (last used) handler.
     * @param file the file to load
     * @param pass primary password (or null)
     * @param pass2 secondary password (or null)
     * @param strat the import handler class (or null if it should reuse the last one)
     * @return the return status (one of the IMPORT_* constants)
     */
    private def tryLoadWithStrategy(File file, String pass, String pass2, Class<AbstractImportExportHandler> strat) {
        if (strat != null){
            setImportExportStrategy(strat)
        }
        val stratName = importExportStrategy.class.simpleName
        if (pass == null){
            log.info("trying import strategy " + stratName)
        }else{
            log.info("trying encrypted import strategy " + stratName)
        }
        try {
            importExportStrategy.load(file, pass, pass2)
            log.info(stratName + " succeeded!")
            return IMPORT_SUCCESS

        } catch (FormatFoundNeedPasswordException e) {
            log.info(stratName + " said it knows this file type but needs a password")
            return IMPORT_FORMAT_IDENTIFIED_NEED_PASSWORD

        } catch (NeedSecondaryPasswordException e) {
            log.info(stratName + " said it needs the secondary password")
            return IMPORT_NEED_SECONDARY_PASSWORD

        } catch (Exception e) {
            log.info(stratName + " said: " + e.message)
            log.trace("attempt to use " + stratName + " failed", e)
            return IMPORT_UNREADABLE
        }
    }

    private def askImportPass(String txtPrompt)throws Exception {
        val pass = prompt(txtPrompt)
        if (pass == null || pass.length == 0){
            throw new Exception("import canceled")
        }
        return pass
    }

    def save(File file, String pass, Class<? extends AbstractImportExportHandler> strat) throws Exception {
        setImportExportStrategy(strat)
        importExportStrategy.save(file, pass, null)
    }

    def add(KeyObject key){
        var skip = false
        var KeyObject duplicate = null
        for (existingKey : keys){
            if (existingKey.addrStr.equals(key.addrStr)){
                if (!existingKey.hasPrivKey && key.hasPrivKey){
                    log.info("replace watch-only {} with private key", existingKey.addrStr)
                    duplicate = existingKey
                } else {
                    log.info("skip existing {}", existingKey.addrStr)
                    skip = true
                }
            }
        }
        if (duplicate != null){
            keys.remove(duplicate)
        }
        if (!skip){
            if (params == null){
                params = key.params
                log.debug("initialized params of WalletKeyTool with params of first added key")
            }
            if (params.equals(key.params)){
                keys.add(key)
                notifyChange
            }else{
                log.error("{} is from a different network. Cannot mix them in the same wallet",
                    key.addrStr
                )
            }
            return key
        } else {
            return null
        }
    }

    def add(ECKey ecKey){
        // KeyWrapper constructor will know what to do if params==null
        val k = new KeyObject(ecKey, params)
        return add(k)
    }

    def addKeyFromOtherInstance(WalletKeyTool other, int i){
        val key = other.get(i)
        keys.add(key)
        notifyChange
    }

    def remove(int i){
        keys.remove(i)
        notifyChange
    }

    def clear(){
        keys.clear
        params = null
        notifyChange
    }

    def addOtherCompressedVersion(int i){
        val KeyObject ko_this = get(i)
        var ECKey ec_other
        var String label
        if (ko_this.compressed) {
            ec_other = new ECKey(new BigInteger(1, ko_this.ecKey.privKeyBytes), null, false)
            label = "uncompressed version of "
        } else {
            ec_other = new ECKey(new BigInteger(1, ko_this.ecKey.privKeyBytes), null, true)
            label = "compressed version of "
        }
        val ko_other = new KeyObject(ec_other, params)
        ko_other.label = label + ko_this.addrStr + " " + ko_this.label
        return add(ko_other)
    }

    def getKeyCount() {
        keys.length
    }

    def get(int i) {
        keys.get(i)
    }

    def getAddressStr(int i) {
        get(i).addrStr
    }

    def getPrivkeyStr(int i) {
        get(i).privKeyStr
    }

    def getCreationTimeSeconds(int i) {
        get(i).creationTimeSeconds
    }

    def getBalance(int i){
        get(i).balance
    }

    def getLabel(int i){
        get(i).label
    }

    def setCreationTimeSeconds(int i, long time) {
        get(i).creationTimeSeconds = time
        notifyChange
    }

    def setBalance(int i, long balance){
        get(i).balance = balance
    }

    def setLabel(int i, String label){
        get(i).label = label
    }

    def dumpToConsole() {
        for (i : 0 ..< keyCount) {
            println(getAddressStr(i) + " " + getPrivkeyStr(i) + " " + getLabel(i))
        }
    }

    def doRemoteFetchCreationDate(int i){
        val d = RemoteAddressInfo.getFirstSeen(getAddressStr(i))
        if (d > 0){
            get(i).creationTimeSeconds = d
            notifyChange
        } else {
            //  0 means not yet seen, set time to today
            // -1 means error, don't do anything
            if (d == 0){
                get(i).creationTimeSeconds = new Date().time / 1000L
                notifyChange
            }
        }
    }

    def doRemoteFetchBalance(int i){
        val b = RemoteAddressInfo.getBalance(getAddressStr(i))
        if (b > -1) {
            setBalance(i, b)
            notifyChange
        }
    }

    override iterator() {
        return new WalletKeyToolIterator(this)
    }
}

class WalletKeyToolIterator implements Iterator<KeyObject> {
    var index = 0
    var WalletKeyTool wkt

    new(WalletKeyTool wkt){
        this.wkt = wkt
    }

    override hasNext() {
        index < wkt.keyCount
    }

    override next() {
        index = index + 1
        return wkt.get(index - 1)
    }

    override remove() {
        wkt.remove(index)
    }
}
