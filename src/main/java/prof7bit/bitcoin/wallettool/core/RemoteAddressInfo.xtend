package prof7bit.bitcoin.wallettool.core

import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import org.slf4j.LoggerFactory
import static extension prof7bit.bitcoin.wallettool.core.Ext.*

class RemoteAddressInfo {
    static val SERVER = "http://blockchain.info"

    static val log = LoggerFactory.getLogger(RemoteAddressInfo)

    static def int getFirstSeen(String address){
        toInt(getHttp(String.format("%s/q/addressfirstseen/%s", SERVER, address)))
    }

    static def int getBalance(String address){
        toInt(getHttp(String.format("%s/q/addressbalance/%s", SERVER, address)))
    }

    private static def toInt(String s){
        try {
            Integer.parseInt(s)
        } catch (Exception e) {
            -1
        }
    }

    private static def String getHttp(String url) {
        var String line
        var result = ""
        try {
            val conn = new URL(url).openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            val rd = new BufferedReader(new InputStreamReader(conn.inputStream))
            while ((line = rd.readLine) != null) {
                result = result.concat(line)
            }
            rd.close
        } catch (IOException e) {
            log.stacktrace(e)
        } catch (Exception e) {
            log.stacktrace(e)
        }
        return result;
    }
}
