package prof7bit.bitcoin.wallettool.core

import com.google.common.base.Charsets
import java.net.URLEncoder
import org.slf4j.Logger
import java.io.UnsupportedEncodingException

/**
 * a few small extension methods
 */
class Ext {
    static def stacktrace(Logger log, Exception ex){
        log.error(ex.message)
        log.trace(ex.message, ex)
    }

    static def urlencode(String s) throws UnsupportedEncodingException {
        // FIXME: need something better to avoid the +
        val result = URLEncoder.encode(s, Charsets.UTF_8.name)
        return result.replace("+", "%20")
    }

}
