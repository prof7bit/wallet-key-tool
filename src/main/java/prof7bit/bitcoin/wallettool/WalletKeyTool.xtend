package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import java.io.File
import java.util.ArrayList
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

    def getKeyCount() {
        keychain.length
    }

    def get(int i) {
        keychain.get(i)
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

    def remove(int i){
        keychain.remove(i)
        notifyChange
    }

    def add(ECKey key){
        for (existing : keychain){
            if (existing.equals(key)){
                log.info("duplicate {} not added", key.toAddress(params))
                return
            }
        }
        keychain.add(key.copy)
        notifyChange
    }

    def clear(){
        keychain.clear
        notifyChange
    }

    def dumpToConsole() {
        for (i : 0 ..< keyCount) {
            println(getAddressStr(i) + " " + getPrivkeyStr(i))
        }
    }
}
