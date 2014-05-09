package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Dimension
import java.io.File
import javax.swing.JButton
import javax.swing.JFrame
import javax.swing.JOptionPane
import javax.swing.JScrollPane
import javax.swing.JTable
import javax.swing.ScrollPaneConstants
import javax.swing.SwingUtilities
import javax.swing.UIManager
import javax.swing.filechooser.FileNameExtensionFilter
import net.miginfocom.swing.MigLayout
import org.apache.commons.cli.CommandLine
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.AbstractWallet
import prof7bit.bitcoin.wallettool.MultibitWallet

import static javax.swing.UIManager.*

class SwingMain extends JFrame{
    static val log = LoggerFactory.getLogger(SwingMain)

    var AbstractWallet wallet = null

    val promptFunc = [
        JOptionPane.showInputDialog(this, it)
    ]

    val alertFunc = [
        JOptionPane.showMessageDialog(this, it)
    ]

    var JButton btn_load
    var JButton btn_save
    var JTable table

    new() {
        super("wallet-key-tool")
        defaultCloseOperation = JFrame.EXIT_ON_CLOSE

        btn_load = new JButton("load...")
        btn_save = new JButton("save as...")
        table = new JTable

        btn_load.addActionListener [
            loadWallet("MultiBit wallet file", "wallet") [|
                new MultibitWallet(promptFunc, alertFunc)
            ]
        ]

        btn_save.addActionListener [
            saveWallet("MultiBit wallet file", "wallet") [|
                new MultibitWallet(promptFunc, alertFunc)
            ]
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

    def saveWallet(String filterDesc, String filterExt, ()=>AbstractWallet factory){
        if (wallet != null){
            val fd = new FileDialogEx(this, "select wallet file");
            fd.setFileFilter(new FileNameExtensionFilter(filterDesc, filterExt))
            if (fd.showSave) {
                // FIXME: don't allow overwriting of old wallet
                var file = fd.selectedFile
                if (!file.path.endsWith("." + filterExt)){
                    file = new File(file.path + "." + filterExt)
                }
                val pass = promptFunc.apply("please enter a pass phrase to encrypt the wallet")
                if (pass != null && pass.length > 0){
                    val pass2 = promptFunc.apply("please repeat the pass phrase")
                    if (pass2 != null && pass2.length > 0 && pass2.equals(pass)) {
                        val temp_wallet = factory.apply
                        temp_wallet.load(wallet)
                        temp_wallet.save(file, pass)
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
    }

    def loadWallet(String filterDesc, String filterExt, ()=>AbstractWallet factory){
        val fd = new FileDialogEx(this, "select wallet file")
        fd.setFileFilter(new FileNameExtensionFilter(filterDesc, filterExt))
        if (fd.showOpen) {
            wallet = factory.apply
            wallet.load(fd.selectedFile)
            table.model = new WalletTableModel(wallet)
        }
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
