package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import java.io.File
import java.util.ArrayList
import java.util.List

class WalletKeyTool {
    @Property var (String)=>String promptFunc = []
    @Property var (String)=>void alertFunc = []
    @Property var (Object)=>void notifyChangeFunc = []
    @Property var ImportExportStrategy importExportStrategy
    @Property var NetworkParameters params
    @Property var List<ECKey> keychain = new ArrayList

    def prompt(String msg){
        promptFunc.apply(msg)
    }

    def alert(String msg){
        alertFunc.apply(msg)
    }

    def notifyChange(){
        notifyChangeFunc.apply(null)
    }

    def void setImportExportStrategy(ImportExportStrategy s){
        _importExportStrategy = s
        s.walletKeyTool = this
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

    def getKeyPair(int i) {
        keychain.get(i)
    }

    def getAddressStr(int i) {
        getKeyPair(i).toAddress(params).toString
    }

    def getPrivkeyStr(int i) {
        val key = getKeyPair(i)
        if (key.hasPrivKey) {
            key.getPrivateKeyEncoded(params).toString
        } else {
            "WATCH ONLY"
        }
    }

    def dumpToConsole() {
        for (i : 0 ..< keyCount) {
            println(getAddressStr(i) + " " + getPrivkeyStr(i))
        }
    }
}
