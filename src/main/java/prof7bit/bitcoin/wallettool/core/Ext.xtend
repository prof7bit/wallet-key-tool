package prof7bit.bitcoin.wallettool.core

import com.google.common.base.Charsets
import java.io.UnsupportedEncodingException
import java.net.URLEncoder
import java.util.Formatter
import org.slf4j.Logger

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

    static def xprintln(long n){
        println(String.format("0x%08X",n))
    }

    static def xprintln(byte[] buf){
        if (buf == null){
            println("null")
        } else {
            val formatter = new Formatter();
            for (b : buf){
                formatter.format("%02x", b);
            }
            println(buf.length * 8 + " " +  formatter.toString)
            formatter.close
        }
    }

    static def hex2bytes(String s) {
        val len = s.length();
        val data = newByteArrayOfSize(len / 2);
        var i = 0
        while (i < len){
            data.set(
                i / 2,
                ((Character.digit(s.charAt(i), 16) << 4) + Character.digit(s.charAt(i+1), 16)) as byte
            )
            i = i + 2
        }
        return data;
    }
}
