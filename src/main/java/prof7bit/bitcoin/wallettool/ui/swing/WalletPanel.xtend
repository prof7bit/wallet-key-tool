package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Frame
import java.awt.Toolkit
import java.awt.datatransfer.StringSelection
import java.io.File
import javax.swing.JButton
import javax.swing.JMenuItem
import javax.swing.JOptionPane
import javax.swing.JPanel
import javax.swing.JPopupMenu
import javax.swing.JScrollPane
import javax.swing.JTable
import javax.swing.ScrollPaneConstants
import javax.swing.filechooser.FileNameExtensionFilter
import net.miginfocom.swing.MigLayout
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.ImportExportStrategy
import prof7bit.bitcoin.wallettool.MultibitStrategy
import prof7bit.bitcoin.wallettool.WalletKeyTool

import static extension prof7bit.bitcoin.wallettool.Ext.*

class WalletPanel extends JPanel{
    val log = LoggerFactory.getLogger(this.class)
    val Frame parentFrame

    @Property var WalletKeyTool keyTool = new WalletKeyTool => [
        promptFunc = [prompt(it)]
        alertFunc = [alert(it)]
    ]
    @Property var WalletKeyTool otherKeyTool = null
    @Property var String otherName = ""

    val btn_load = new JButton("load...") => [
        addActionListener [
            loadWallet("MultiBit wallet file", "wallet", MultibitStrategy)
        ]
    ]

    val btn_save = new JButton("save as...") => [
        addActionListener [
            saveWallet("MultiBit wallet file", "wallet", MultibitStrategy)
        ]
    ]

    val JTable table = new JTable => [
        model = new WalletTableModel(keyTool)
        addMouseListener(new MouseDownListener[evt|
            if (evt.popupTrigger) {
                val row = rowAtPoint(evt.point)
                val inside = (row >= 0 && row < model.rowCount)
                new JPopupMenu => [popup|
                    if (inside){
                        selectionModel.setSelectionInterval(row, row)
                        new JMenuItem("copy address to clipboard") => [
                            popup.add(it)
                            addActionListener [
                                copyToClipboard(row, 0)
                            ]
                        ]
                        new JMenuItem("copy private key to clipboard") => [
                            popup.add(it)
                            addActionListener [
                                copyToClipboard(row, 1)
                            ]
                        ]
                        new JMenuItem("copy selected key to " + otherName) => [
                            popup.add(it)
                            addActionListener [
                                if (otherKeyTool.params == null){
                                    otherKeyTool.params = keyTool.params
                                }
                                otherKeyTool.addKeyFromOtherInstance(keyTool, row)
                            ]
                        ]
                        new JMenuItem("move selected key to " + otherName) => [
                            popup.add(it)
                            addActionListener [
                                if (otherKeyTool.params == null){
                                    otherKeyTool.params = keyTool.params
                                }
                                otherKeyTool.addKeyFromOtherInstance(keyTool, row)
                                keyTool.remove(row)
                            ]
                        ]
                        new JMenuItem("Remove selected key") => [
                            popup.add(it)
                            addActionListener [
                                keyTool.remove(row)
                            ]
                        ]
                        new JMenuItem("Fetch creation date from blockchain.info") => [
                            popup.add(it)
                            addActionListener [
                                keyTool.doRemoteFetchCreationDate(row)
                            ]
                        ]
                        new JMenuItem("Fetch balance from blockchain.info") => [
                            popup.add(it)
                            addActionListener [
                                keyTool.doRemoteFetchBalance(row)
                            ]
                        ]
//                        new JMenuItem("Fetch all data for all keys from blockchain.info") => [
//                            popup.add(it)
//                            addActionListener [
//                                keyTool.doRemoteUpdateAll
//                            ]
//                        ]
                    }
                    new JMenuItem("Add new key") => [
                        popup.add(it)
                        addActionListener [
                            new AddKeyDialog(parentFrame, keyTool)
                        ]
                    ]
                    new JMenuItem("Clear list") => [
                        popup.add(it)
                        addActionListener [
                            keyTool.clear
                        ]
                    ]
                    popup.show(table, evt.x, evt.y)
                ]
            }
        ])
    ]

    new(Frame parentFrame) {
        super()
        this.parentFrame = parentFrame

        // layout

        layout = new MigLayout("fill", "[][grow]", "[][grow]")
        add(btn_load)
        add(btn_save, "wrap")
        val tablePane = new JScrollPane(table)
        tablePane.viewportView = table
        tablePane.verticalScrollBarPolicy = ScrollPaneConstants.VERTICAL_SCROLLBAR_AS_NEEDED
        table.fillsViewportHeight = true
        add(tablePane, "spanx, grow, push")
        visible = true
    }

    def copyToClipboard(int row, int col){
        val s = this.table.model.getValueAt(row, col) as String
        val selection = new StringSelection(s);
        val clipboard = Toolkit.defaultToolkit.systemClipboard
        clipboard.setContents(selection, selection);
    }

    def saveWallet(String filterDesc, String filterExt, Class<? extends ImportExportStrategy> strat) {
        if (keyTool.keyCount == 0){
            alert("Wallet is empty, nothing to save")
        } else {
            val fd = new FileDialogEx(parentFrame, "select wallet file");
            fd.setFileFilter(new FileNameExtensionFilter(filterDesc, filterExt))
            if (fd.showSave) {
                // FIXME: don't allow overwriting of old wallet
                var file = fd.selectedFile
                if (!file.path.endsWith("." + filterExt)){
                    file = new File(file.path + "." + filterExt)
                }
                val pass = prompt("please enter a pass phrase to encrypt the wallet")
                if (pass != null && pass.length > 0){
                    val pass2 = prompt("please repeat the pass phrase")
                    if (pass2 != null && pass2.length > 0 && pass2.equals(pass)) {
                        keyTool.importExportStrategy = strat
                        keyTool.save(file, pass)
                    } else {
                        alert("pass phrase not repeated correctly")
                        log.info("saving canceled because of pass phrase mismatch")
                    }
                }else{
                    log.info("saving canceled")
                }
            }
        }
    }

    def loadWallet(String filterDesc, String filterExt, Class<? extends ImportExportStrategy> strat) {
        val fd = new FileDialogEx(parentFrame, "select wallet file")
        fd.setFileFilter(new FileNameExtensionFilter(filterDesc, filterExt))
        if (fd.showOpen) {
            keyTool.importExportStrategy = strat
            try {
                keyTool.load(fd.selectedFile, null)
            } catch (Exception e) {
                log.stacktrace(e)
                alert(e.toString)
            }
        }
    }

    def prompt(String msg) {
        JOptionPane.showInputDialog(this, msg)
    }

    def alert(String msg) {
        JOptionPane.showMessageDialog(this, msg)
    }

}

