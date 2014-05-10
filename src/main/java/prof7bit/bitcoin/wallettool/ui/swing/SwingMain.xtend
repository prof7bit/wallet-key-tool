package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Dimension
import javax.swing.JFrame
import javax.swing.JTabbedPane
import javax.swing.SwingUtilities
import javax.swing.UIManager
import org.apache.commons.cli.CommandLine
import org.slf4j.LoggerFactory

import static javax.swing.UIManager.*

class SwingMain extends JFrame{
    static val log = LoggerFactory.getLogger(WalletPanel)

    new(){
        super("wallet-key-tool")
        defaultCloseOperation = JFrame.EXIT_ON_CLOSE

        val panelA = new WalletPanel
        val panelB = new WalletPanel

        panelA.otherKeyTool = panelB.keyTool
        panelA.otherName = "Wallet B"
        panelB.otherKeyTool = panelA.keyTool
        panelB.otherName = "Wallet A"

        new JTabbedPane => [
            addTab("Wallet A", panelA)
            addTab("Wallet B", panelB)
            this.add(it)
        ]

        preferredSize = new Dimension(1000, 500)
        pack
        visible = true
    }

    static def start(CommandLine opt) {
        val laf = UIManager.installedLookAndFeels.findFirst[("Nimbus".equals(it.name))]
        if (laf != null) {
            try {
                UIManager.lookAndFeel = laf.className
            } catch (Exception e) {
                log.debug("could not set LAF", e)
            }
        }
        SwingUtilities.invokeLater [|
            new SwingMain
        ]
    }
}
