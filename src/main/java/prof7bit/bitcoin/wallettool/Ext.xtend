package prof7bit.bitcoin.wallettool

import org.slf4j.Logger

/**
 * a few small extension methods
 */
class Ext {
    static def stacktrace(Logger log, Exception ex){
        log.error(ex.message)
        log.trace(ex.message, ex)
    }
}
