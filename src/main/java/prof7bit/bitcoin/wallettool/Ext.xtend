package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import java.io.InputStream
import org.slf4j.Logger

/**
 * a few small extension methods
 */
class Ext {
    static def stacktrace(Logger log, Exception ex){
        log.error(ex.message)
        log.debug(ex.message, ex)
    }

    static def closeAfter(InputStream s, (InputStream)=>void proc){
        try {
            proc.apply(s)
        } finally {
            s.close
        }
    }

    static def ECKey copy(ECKey key){
        var ECKey result
        if (key.hasPrivKey){
            result = new ECKey(key.privKeyBytes, key.pubKey)
        } else {
            if (key.encrypted){
                result = new ECKey(key.encryptedPrivateKey, key.pubKey, key.keyCrypter)
            } else {
                // watch only
                result = new ECKey(null, key.pubKey)
            }
        }
        result.creationTimeSeconds = key.creationTimeSeconds
        result
    }
}
