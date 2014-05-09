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

import static javax.swing.UIManager.*
import org.apache.commons.cli.CommandLine
import prof7bit.bitcoin.wallettool.AbstractWallet

class SwingMain extends JFrame{
    static val log = LoggerFactory.getLogger(SwingMain)

    var AbstractWallet wallet = null

    new() {
        super("wallet-key-tool")

        defaultCloseOperation = JFrame.EXIT_ON_CLOSE

        val promptFunc = [
            JOptionPane.showInputDialog(this, it)
        ]

        val alertFunc = [
            JOptionPane.showMessageDialog(this, it)
        ]

        val btn_load = new JButton("load...")
        val btn_save = new JButton("save as...")
        val table = new JTable


        btn_load.addActionListener [
            val fd = new FileDialogEx(this, "select wallet file");
            if (fd.showOpen) {
                wallet = new MultibitWallet(promptFunc, alertFunc)
                wallet.load(fd.selectedFile)
                table.model = new WalletTableModel(wallet)
            }
        ]

        btn_save.addActionListener [
            if (wallet != null){
                val fd = new FileDialogEx(this, "select wallet file");
                if (fd.showSave) {
                    // FIXME: don't allow overwriting of old wallet
                    val pass = promptFunc.apply("please enter a pass phrase to encrypt the wallet")
                    if (pass != null && pass.length > 0){
                        val pass2 = promptFunc.apply("please repeat the pass phrase")
                        if (pass2 != null && pass2.length > 0 && pass2.equals(pass)) {
                            val temp_wallet = new MultibitWallet(promptFunc, alertFunc)
                            temp_wallet.load(wallet)
                            temp_wallet.save(fd.selectedFile, pass)
                        } else {
                            alertFunc.apply("pass phrase not repeated correctly")
                            log.info("saving canceled because of pass phrase mismatch")
                        }
                    }else{
                        log.info("saving canceled")
                    }
                }
            } else {
                log.error("no wallet loaded, nothing to save")
            }
        ]

        // layout

        layout = new MigLayout("fill", "[][grow]", "[][grow]")
        add(btn_load)
        add(btn_save, "wrap")
        val tablePane = new JScrollPane(table)
        tablePane.viewportView = table
        tablePane.verticalScrollBarPolicy = ScrollPaneConstants.VERTICAL_SCROLLBAR_AS_NEEDED
        table.fillsViewportHeight = true
        add(tablePane, "spanx, grow, push")
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
