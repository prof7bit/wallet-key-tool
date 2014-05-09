package prof7bit.bitcoin.wallettool

import java.io.File
import org.slf4j.Logger
import org.slf4j.LoggerFactory

abstract class AbstractWallet {
    protected var Logger log
    protected var (String)=>String promptFunction
    protected var (String)=>void alertFunction
    protected var Boolean loaded

    new ((String)=>String promptFunction, (String)=>void alertFunction){
        log = LoggerFactory.getLogger(this.class)
        this.promptFunction = promptFunction
        this.alertFunction = alertFunction
        loaded = false
    }

    def void load(File file)
    def void load(AbstractWallet other_wallet)
    def void save(File file, String passphrase)
    def void dumpToConsole()
    def int getKeyCount()
    def KeyPair getKeyPair(int i)
    def String getAddressStr(int i)
    def String getPrivkeyStr(int i)
}
