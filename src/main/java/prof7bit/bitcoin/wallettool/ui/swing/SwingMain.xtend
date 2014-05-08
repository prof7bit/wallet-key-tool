package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Dimension
import javax.swing.JButton
import javax.swing.JFrame
import javax.swing.JOptionPane
import javax.swing.JScrollPane
import javax.swing.JTable
import javax.swing.ScrollPaneConstants
import javax.swing.SwingUtilities
import javax.swing.UIManager
import net.miginfocom.swing.MigLayout
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.MultibitWallet

class SwingMain extends JFrame{
    static val log = LoggerFactory.getLogger(SwingMain)

    new() {
        super("wallet-key-tool")

        defaultCloseOperation = JFrame.EXIT_ON_CLOSE

        val button = new JButton("open")
        val table = new JTable
        val wallet = new MultibitWallet
        wallet.promptFunction = [
            JOptionPane.showInputDialog(it)
        ]

        button.addActionListener [
            val fd = new FileOpenDialog(this, "select wallet file");
            if (fd.showOpen) {
                wallet.load(fd.selectedFile)
                table.model = new WalletTableModel(wallet)
            }
        ]

        // layout

        layout = new MigLayout("fill")
        add(button, "wrap")
        val tablePane = new JScrollPane(table)
        tablePane.viewportView = table
        tablePane.verticalScrollBarPolicy = ScrollPaneConstants.VERTICAL_SCROLLBAR_AS_NEEDED
        table.fillsViewportHeight = true
        add(tablePane, "grow, push")
        preferredSize = new Dimension(1000, 500)
        pack
        visible = true
    }

    static def start() {

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
