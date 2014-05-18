package prof7bit.bitcoin.wallettool.core

import java.io.BufferedReader
import java.io.File
import java.io.IOException
import java.io.InputStreamReader
import org.apache.commons.cli.CommandLine
import org.apache.commons.cli.GnuParser
import org.apache.commons.cli.Options
import org.apache.commons.cli.ParseException
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.ui.swing.core.SwingMain

import static extension prof7bit.bitcoin.wallettool.core.Ext.*

static class Main {
    static val log = LoggerFactory.getLogger(Main)

    static val consolePromptFunc = [
        val br = new BufferedReader(new InputStreamReader(System.in))
        clearLine
        print(it + ": ")
        try {
            br.readLine
        } catch (IOException e) {
            log.stacktrace(e)
            System.exit(1)
        }
    ]

    static val consoleConfirmFunc = [
        clearLine
        val answer = consolePromptFunc.apply(it + " [y/n]")
        return (answer == "y" || answer == "")
    ]

    static val consoleProgressFunc = [int percent, String status|
        val prog1 = "###############"
        val prog2 = "---------------"
        val part1 = prog1.substring((100-percent) * prog1.length / 100)
        val part2 = prog2.substring(part1.length)
        val status_s = status.substring(0, Math.min(status.length, 60))
        val line = part1 + part2 + " " + status_s + "\r"
        clearLine
        print(line)
        return
    ]

    static val consoleAlertFunc = [
        clearLine
        println(it)
        return
    ]

    static def clearLine(){
        // 79 spaces
        print("\r                                                                               \r")
    }

    static def void main(String[] args) {
        try{
            val opt = parseOpt(args)
            if (opt.args.length == 0) {
                SwingMain.start(opt)
            } else {
                consoleStart(opt)
            }
        } catch (Exception e){
            log.stacktrace(e)
            System.exit(1)
        }
    }

    static def consoleStart(CommandLine opt) {
        val filename = opt.args.get(0)
        val pass = opt.getOptionValue("password")
        new WalletKeyTool => [
            promptFunc = consolePromptFunc
            alertFunc = consoleAlertFunc
            yesNoFunc = consoleConfirmFunc
            reportProgressFunc = consoleProgressFunc
            try {
                load(new File(filename), pass)
                dumpToConsole
            } catch (Exception e) {
                log.stacktrace(e)
            }
        ]
    }

    static def CommandLine parseOpt(String[] args) throws ParseException {
        val opt_defs = new Options
        opt_defs.addOption("p", "password", true, "password")
        val optparser = new GnuParser
        optparser.parse(opt_defs, args)
    }
}
