package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.AddressFormatException
import com.google.bitcoin.core.DumpedPrivateKey
import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.NetworkParameters
import com.google.bitcoin.params.MainNetParams
import org.slf4j.LoggerFactory

class KeyObject {
    static val log = LoggerFactory.getLogger(KeyObject)

    @Property var ECKey ecKey
    @Property var NetworkParameters params
    @Property var String label = ""
    @Property var long Balance = -1

    new (ECKey ecKey, NetworkParameters params){
        this.params = params
        this.ecKey = ecKey
    }

    new (String privkey, NetworkParameters params) throws AddressFormatException {
        if (params == null){
            this.params = new MainNetParams
        } else {
            this.params = params
        }
        this.ecKey = new DumpedPrivateKey(this.params, privkey).key
    }

    def getAddrStr(){
        _ecKey.toAddress(params).toString
    }

    def getPrivKeyStr(){
        try {
            return _ecKey.getPrivateKeyEncoded(params).toString
        } catch (Exception e) {
            return null
        }
    }

    def getCreationTimeSeconds(){
        _ecKey.creationTimeSeconds
    }

    def setCreationTimeSeconds(long t){
        _ecKey.creationTimeSeconds = t
    }

    def hasPrivKey(){
        _ecKey.hasPrivKey
    }

    /**
     * Set the ecKey. We don't want keys with missing creation date, so we fix it
     * here immediately. Especially MultiBit has a bug where it starts behaving
     * strange if creation date is not at least one second later than that of the
     * genesis block, it will either behave strange when opening such a wallet
     * and/or refuse to reset the block chain. Therefore we ensure that no key h
     * as a creation time earlier than the time stamp of the genesis block of its
     * network plus 1 second.
     */
    def void setEcKey(ECKey ecKey){
        if (ecKey.creationTimeSeconds <= params.genesisBlock.timeSeconds){
            log.debug("{} creation date {}, adjusting to time of genesis block",
                ecKey.toAddress(params),
                ecKey.creationTimeSeconds
            )
            ecKey.creationTimeSeconds = params.genesisBlock.timeSeconds + 1
        }
        _ecKey = ecKey
    }

    /**
     * Return a copy of the ECKey. We will not under any circumstances
     * allow a reference to the original to leave this wrapper object.
     */
    def getEcKey(){
        var ECKey result
        if (_ecKey.hasPrivKey){
            result = new ECKey(_ecKey.privKeyBytes, _ecKey.pubKey)
        } else {
            if (_ecKey.encrypted){
                result = new ECKey(_ecKey.encryptedPrivateKey, _ecKey.pubKey, _ecKey.keyCrypter)
            } else {
                // watch only
                result = new ECKey(null, _ecKey.pubKey)
            }
        }
        result.creationTimeSeconds = _ecKey.creationTimeSeconds
        return result
    }
}
