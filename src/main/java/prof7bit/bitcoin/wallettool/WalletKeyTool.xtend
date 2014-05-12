package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import java.io.File
import java.util.ArrayList
import java.util.Date
import java.util.Iterator
import java.util.List
import org.slf4j.LoggerFactory

class WalletKeyTool implements Iterable<KeyObject> {
    val log = LoggerFactory.getLogger(this.class)
    @Property var (String)=>String promptFunc = []
    @Property var (String)=>boolean YesNoFunc = []
    @Property var (String)=>void alertFunc = []
    @Property var (Object)=>void notifyChangeFunc = []
    @Property var NetworkParameters params = null
    private var List<KeyObject> keys = new ArrayList

    var ImportExportStrategy importExportStrategy

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

    def void setImportExportStrategy(Class<? extends ImportExportStrategy> strat){
        importExportStrategy = strat.newInstance
        importExportStrategy.walletKeyTool = this
    }

    def load(File file, String pass){
        importExportStrategy.load(file, pass)
        notifyChange
    }

    def save(File file, String pass){
        importExportStrategy.save(file, pass)
    }

    def add(KeyObject key){
        // FIXME: do something when params are from different network
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
            keys.add(key)
            notifyChange
        }
    }

    def add(ECKey ecKey){
        // KeyWrapper constructor will know what to do if params==null
        add(new KeyObject(ecKey, params))
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
            println(getAddressStr(i) + " " + getPrivkeyStr(i))
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
