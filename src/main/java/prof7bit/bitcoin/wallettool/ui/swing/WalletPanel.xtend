package prof7bit.bitcoin.wallettool.ui.swing

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

    @Property var WalletKeyTool keyTool = null
    @Property var WalletKeyTool otherKeyTool = null
    @Property var String otherName = ""

    var JButton btn_load
    var JButton btn_save
    var JTable table

    new() {
        super()

        keyTool = new WalletKeyTool => [
            promptFunc = [prompt(it)]
            alertFunc = [alert(it)]
        ]

        btn_load = new JButton("load...")
        btn_save = new JButton("save as...")
        table = new JTable
        table.model = new WalletTableModel(keyTool)

        table.addMouseListener(new MouseDownListener[evt|
            if (evt.popupTrigger) {
                val row = table.rowAtPoint(evt.point)
                val inside = (row >= 0 && row < table.model.rowCount)
                new JPopupMenu => [pop|
                    if (inside){
                        table.selectionModel.setSelectionInterval(row, row)
                        new JMenuItem("copy address to clipboard") => [
                            addActionListener [
                                copyToClipboard(row, 0)
                            ]
                            pop.add(it)
                        ]
                        new JMenuItem("copy private key to clipboard") => [
                            addActionListener [
                                copyToClipboard(row, 1)
                            ]
                            pop.add(it)
                        ]
                        new JMenuItem("copy selected key to " + otherName) => [
                            addActionListener [
                                if (otherKeyTool.params == null){
                                    otherKeyTool.params = keyTool.params
                                }
                                otherKeyTool.add(keyTool.get(row))
                            ]
                            pop.add(it)
                        ]
                        new JMenuItem("move selected key to " + otherName) => [
                            addActionListener [
                                if (otherKeyTool.params == null){
                                    otherKeyTool.params = keyTool.params
                                }
                                otherKeyTool.add(keyTool.get(row))
                                keyTool.remove(row)
                            ]
                            pop.add(it)
                        ]
                        new JMenuItem("Remove selected key") => [
                            addActionListener [
                                keyTool.remove(row)
                            ]
                            pop.add(it)
                        ]
                    }
                    new JMenuItem("Insert new key") => [
                        pop.add(it)
                    ]
                    new JMenuItem("Clear list") => [
                        addActionListener [
                            keyTool.clear
                        ]
                        pop.add(it)
                    ]
                    pop.show(table, evt.x, evt.y)
                ]
            }
        ])


        btn_load.addActionListener [
            loadWallet("MultiBit wallet file", "wallet", MultibitStrategy)
        ]

        btn_save.addActionListener [
            saveWallet("MultiBit wallet file", "wallet", MultibitStrategy)
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
        visible = true
    }

    def saveWallet(String filterDesc, String filterExt, Class<? extends ImportExportStrategy> strat) {
        if (keyTool.keyCount == 0){
            alert("Wallet is empty, nothing to save")
        } else {
            val fd = new FileDialogEx(this, "select wallet file");
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
        val fd = new FileDialogEx(this, "select wallet file")
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

    def copyToClipboard(int row, int col){
        val s = table.model.getValueAt(row, col) as String
        val selection = new StringSelection(s);
        val clipboard = Toolkit.defaultToolkit.systemClipboard
        clipboard.setContents(selection, selection);
    }
}

