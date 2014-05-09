package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import java.io.File
import java.util.ArrayList
import java.util.List
import org.slf4j.Logger
import org.slf4j.LoggerFactory

import static extension prof7bit.bitcoin.wallettool.Ext.*

abstract class AbstractWallet {
    protected var Logger log
    protected var (String)=>String promptFunction
    protected var (String)=>void alertFunction
    @Property var NetworkParameters params
    @Property var List<ECKey> keychain = new ArrayList

    new ((String)=>String promptFunction, (String)=>void alertFunction){
        log = LoggerFactory.getLogger(this.class)
        this.promptFunction = promptFunction
        this.alertFunction = alertFunction
    }

    def void load(File file)
    def void save(File file, String passphrase)

    def load(AbstractWallet other_wallet) {
        params = other_wallet.params
        keychain.clear
        for (key : other_wallet.keychain){
            keychain.add(key.copy)
        }
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
