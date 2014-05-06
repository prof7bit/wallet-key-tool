package prof7bit.bitcoin.wallettool

import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import org.apache.commons.cli.CommandLine
import org.apache.commons.cli.GnuParser
import org.apache.commons.cli.Options
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.ui.swing.SwingMain
import static extension prof7bit.bitcoin.wallettool.Ext.*

static class Main {
    static val log = LoggerFactory.getLogger(Main)

    static val consolePromptFunc = [
        val br = new BufferedReader(new InputStreamReader(System.in))
        print(it + ": ")
        try {
            br.readLine
        } catch (IOException ioe) {
            log.error("IO error while reading interactive console input!")
            System.exit(1)
            ""
        }
    ]

    static def void main(String[] args) {

        try{
            val opt = parseOpt(args)
            if (opt.args.length == 0) {
                SwingMain.start
            } else {
                val filename = opt.args.get(0)
                val wallet = new MultibitWallet
                wallet.setPromptFunction(consolePromptFunc)
                wallet.load(filename)
                wallet.dumpToConsole
            }
        } catch (Exception e){
            log.stacktrace(e)
            System.exit(1)
        }
    }

    static def CommandLine parseOpt(String[] args) {
        val opt_defs = new Options
        val optparser = new GnuParser
        optparser.parse(opt_defs, args)
    }
}
