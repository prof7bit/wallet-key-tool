package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Dimension
import javax.swing.JButton
import javax.swing.JFileChooser
import javax.swing.JFrame
import javax.swing.JOptionPane
import javax.swing.JScrollPane
import javax.swing.JTable
import javax.swing.ScrollPaneConstants
import javax.swing.SwingUtilities
import javax.swing.UIManager
import net.miginfocom.swing.MigLayout
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.IWallet
import prof7bit.bitcoin.wallettool.MultibitWallet

import static javax.swing.UIManager.*

class SwingMain {

    static var IWallet wallet
    static var filename = ""
    static val log = LoggerFactory.getLogger(SwingMain)

    static def start() {

        val laf = UIManager.installedLookAndFeels.findFirst[("Nimbus".equals(it.name))]
        if (laf != null) {
            try {
                UIManager.lookAndFeel = laf.className
            } catch (Exception e) {
                log.debug("could not set LAF", e)
            }
        }

        SwingUtilities.invokeLater [ |
            val frame = new JFrame("wallet-key-tool")
            frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
            val button = new JButton("open")
            val table = new JTable

            wallet = new MultibitWallet
            wallet.promptFunction = [
                JOptionPane.showInputDialog(it)
            ]

            button.addActionListener [
                val fc = new JFileChooser(filename);
                fc.preferredSize = new Dimension(600, 400)
                fc.fileHidingEnabled = false
                if (fc.showOpenDialog(frame) == JFileChooser.APPROVE_OPTION) {
                    filename = fc.selectedFile.canonicalPath
                    wallet.load(filename)
                    table.model = new WalletTableModel(wallet)
                } else {
                    log.debug("file chooser dialog canceled")
                }
            ]

            // layout

            frame.layout = new MigLayout("fill")
            frame.add(button, "wrap")
            val tablePane = new JScrollPane(table)
            tablePane.viewportView = table
            tablePane.verticalScrollBarPolicy = ScrollPaneConstants.VERTICAL_SCROLLBAR_AS_NEEDED
            table.fillsViewportHeight = true
            frame.add(tablePane, "grow, push")
            frame.preferredSize = new Dimension(1000, 500)
            frame.pack
            frame.visible = true
        ]
    }
}
