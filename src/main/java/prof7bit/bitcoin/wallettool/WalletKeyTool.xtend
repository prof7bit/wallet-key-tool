package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.AddressFormatException
import com.google.bitcoin.core.DumpedPrivateKey
import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import java.io.File
import java.util.ArrayList
import java.util.Date
import java.util.List
import org.slf4j.LoggerFactory

import static extension prof7bit.bitcoin.wallettool.Ext.*

class WalletKeyTool {
    val log = LoggerFactory.getLogger(this.class)
    @Property var (String)=>String promptFunc = []
    @Property var (String)=>void alertFunc = []
    @Property var (Object)=>void notifyChangeFunc = []
    @Property var NetworkParameters params = null
    @Property var List<ECKey> keychain = new ArrayList
    @Property var List<KeyExtraInfo> extrainfo = new ArrayList

    var ImportExportStrategy importExportStrategy

    def prompt(String msg){
        promptFunc.apply(msg)
    }

    def alert(String msg){
        alertFunc.apply(msg)
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

    def add(ECKey key){
        fixCreationDate(key)
        for (existing : keychain){
            if (existing.equals(key)){
                log.info("duplicate {} not added", key.toAddress(params))
                return
            }
        }
        keychain.add(key.copy)
        extrainfo.add(new KeyExtraInfo)
        notifyChange
    }

    def remove(int i){
        keychain.remove(i)
        extrainfo.remove(i)
        notifyChange
    }

    def clear(){
        keychain.clear
        extrainfo.clear
        notifyChange
    }

    def getKeyCount() {
        keychain.length
    }

    def get(int i) {
        keychain.get(i)
    }

    def getExtraInfo(int i){
        extrainfo.get(i)
    }

    def getAddressStr(int i) {
        get(i).toAddress(params).toString
    }

    def getPrivkeyStr(int i) {
        val key = get(i)
        if (key.hasPrivKey) {
            key.getPrivateKeyEncoded(params).toString
        } else {
            "WATCH ONLY"
        }
    }

    def getCreationTimeSeconds(int i) {
        get(i).creationTimeSeconds
    }

    def getBalance(int i){
        getExtraInfo(i).balance
    }

    def getLabel(int i){
        getExtraInfo(i).label
    }

    def setCreationTimeSeconds(int i, long time) {
        get(i).creationTimeSeconds = time
        notifyChange
    }

    def setBalance(int i, long balance){
        getExtraInfo(i).balance = balance
    }

    def setLabel(int i, String label){
        getExtraInfo(i).label = label
    }

    def dumpToConsole() {
        for (i : 0 ..< keyCount) {
            println(getAddressStr(i) + " " + getPrivkeyStr(i))
        }
    }

    def ECKey privkeyStrToECKey(String privkey){
        try {
            new DumpedPrivateKey(params, privkey).key
        } catch (AddressFormatException e) {
            null
        }
    }

    def String ECKeyToAddressStr(ECKey key){
        if (key == null){
            null
        } else {
            key.toAddress(params).toString
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

    /**
     * we don't want keys with missing creation date. Especially MultiBit has a bug
     * where it starts behaving strange if creation date is not at least one second
     * later than that of the genesis block, it will either behave strange when
     * opening such a wallet and/or refuse to reset the block chain. Therefore we
     * ensure that no key has a creation time earlier than the time stamp of the
     * genesis block of its network plus 1 second.
     */
    def fixCreationDate(ECKey key){
        if (key.creationTimeSeconds <= params.genesisBlock.timeSeconds){
            log.debug("{} creation date {}, adjusting to time of genesis block",
                key.toAddress(params),
                key.creationTimeSeconds
            )
            key.creationTimeSeconds = params.genesisBlock.timeSeconds + 1
        }
    }
}
