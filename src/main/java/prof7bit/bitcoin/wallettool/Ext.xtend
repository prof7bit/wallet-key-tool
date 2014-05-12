package prof7bit.bitcoin.wallettool

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
}
