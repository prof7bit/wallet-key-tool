package prof7bit.bitcoin.wallettool.test

import java.util.Formatter

class Ext {
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

    static def void xprintln(byte[] buf){
        val formatter = new Formatter()
        for (byte b : buf){
            formatter.format("%02x", b)
        }
        println(buf.length * 8 + " " + formatter.toString())
        formatter.close()
    }
}
