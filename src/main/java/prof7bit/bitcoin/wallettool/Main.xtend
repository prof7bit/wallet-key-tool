package prof7bit.bitcoin.wallettool

import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.ui.swing.SwingMain

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
        if (args.length == 0) {
            SwingMain.start
        } else {
            val filename = args.get(0)
            val wallet = new MultibitWallet
            wallet.setPromptFunction(consolePromptFunc)
            wallet.load(filename)
            wallet.dumpToConsole
        }
    }
}
