package prof7bit.bitcoin.wallettool.fileformats

import com.google.common.base.Charsets
import com.google.common.io.Files
import java.io.File
import java.io.IOException
import java.text.ParseException
import java.text.SimpleDateFormat
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.ImportExportStrategy
import prof7bit.bitcoin.wallettool.KeyObject
import com.google.bitcoin.core.AddressFormatException
import static extension prof7bit.bitcoin.wallettool.Ext.*

/**
 * read and write Multibit backup file (*.key).
 * this can also be used for Schildbach backups
 */
class MultibitBackupStrategy  extends ImportExportStrategy {
    val log = LoggerFactory.getLogger(this.class)
    val formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")

    override load(File file, String pass) throws Exception {
        log.debug("loading wallet file: " + file.path)
        try {
            readLines(file)
        } catch (Exception e) {
            log.stacktrace(e)
        }

    }

    override save(File file, String pass) throws Exception {
    }


    private def readLines(File f) throws IOException , ParseException , AddressFormatException {
        val lines = Files.readLines(f, Charsets.UTF_8)
        for (line : lines){
            if (!line.startsWith("#")){
                val fields = line.split(" ")
                if (fields.length == 2){
                    val key = new KeyObject(
                        fields.get(0),
                        walletKeyTool.params,
                        formatter.parse(fields.get(1)).time / 1000L
                    )
                    log.debug("importing {}", key.addrStr)
                    walletKeyTool.add(key)
                }
            }
        }
    }
}
