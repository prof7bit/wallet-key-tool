package prof7bit.bitcoin.wallettool.ui.swing

import com.google.common.io.Files
import java.awt.Dimension
import java.awt.Frame
import java.awt.Toolkit
import java.awt.datatransfer.StringSelection
import java.io.File
import javax.swing.JButton
import javax.swing.JFileChooser
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
import prof7bit.bitcoin.wallettool.WalletKeyTool
import prof7bit.bitcoin.wallettool.ui.swing.listeners.MouseDownListener
import prof7bit.bitcoin.wallettool.ui.swing.listeners.ResizeListener
import prof7bit.bitcoin.wallettool.ui.swing.misc.TableColumnAdjuster

import static extension prof7bit.bitcoin.wallettool.Ext.*

class WalletPanel extends JPanel{
    val log = LoggerFactory.getLogger(this.class)
    val Frame parentFrame

    @Property var WalletKeyTool keyTool = new WalletKeyTool => [
        promptFunc = [prompt(it)]
        alertFunc = [alert(it)]
        yesNoFunc = [confirm(it)]
    ]
    @Property var WalletKeyTool otherKeyTool = null
    @Property var String otherName = ""

    val btn_load = new JButton("load...") => [
        addActionListener [
            try {
                loadWallet()
            } catch (Exception e) {
                log.stacktrace(e)
            }
        ]
    ]

    val btn_save = new JButton("save as...") => [
        addActionListener [
            try {
                saveWallet()
            } catch (Exception e) {
                log.stacktrace(e)
            }
        ]
    ]

    val JTable table = new JTable => [
        model = new WalletTableModel(keyTool)
        autoResizeMode = JTable.AUTO_RESIZE_ALL_COLUMNS
        addComponentListener(new ResizeListener [
            columnAdjuster.adjustColumns
        ])
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
                        new JMenuItem("Fetch balance and creation date from blockchain.info") => [
                            popup.add(it)
                            addActionListener [
                                keyTool.doRemoteFetchBalance(row)
                                keyTool.doRemoteFetchCreationDate(row)
                            ]
                        ]
                        val key = keyTool.get(row)
                        var compOtherTxt = "compressed"
                        if (key.hasPrivKey){
                            if (key.compressed){
                                compOtherTxt = "uncompressed"
                            }
                            new JMenuItem("Add " + compOtherTxt + " version of this key") => [
                                popup.add(it)
                                addActionListener [
                                    keyTool.addOtherCompressedVersion(row)
                                ]
                            ]
                        }
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

    val columnAdjuster = new TableColumnAdjuster(table) => [
        onlyAdjustLarger = false
        dynamicAdjustment = true
        adjustColumns
    ]

    val fc = new JFileChooser => [
        addChoosableFileFilter(new FileNameExtensionFilter("Blockchain.info backup (*.aes.json)", "json"))
        addChoosableFileFilter(new FileNameExtensionFilter("Multibit backup (*.key)", "key"))
        setFileFilter(new FileNameExtensionFilter("Multibit wallet (*.wallet)", "wallet"))
        preferredSize = new Dimension(600, 500)
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

    def saveWallet() {
        if (keyTool.keyCount == 0){
            alert("Wallet is empty, nothing to save")
        } else {
            var File file
            var String filterExt
            var exitLoop = false
            while (!exitLoop) {
                //val fd = new FileDialogEx(parentFrame, "select wallet file");
                //fd.setFileFilters
                if (fc.showSaveDialog(this) == JFileChooser.APPROVE_OPTION) {
                    // FIXME: don't allow overwriting of old wallet
                    file = fc.selectedFile
                    if (fc.fileFilter.class.equals(FileNameExtensionFilter)) {
                        filterExt = (fc.fileFilter as FileNameExtensionFilter).extensions.get(0)
                        if (!file.path.endsWith("." + filterExt)){
                            file = new File(file.path + "." + filterExt)
                        }
                    }
                    if (file.exists){
                        alert("can not overwrite existing files. Please select a different file name")
                    }else{
                        if (!keyTool.hasStrategyForFileType(file)){
                            val ext = Files.getFileExtension(file.path)
                            alert(String.format("unknown file type: *.%s", ext))
                        }else{
                            exitLoop = true
                        }
                    }
                } else {
                    // file dialog exited with cancel
                    exitLoop = true
                    file = null
                }
            }

            if (file != null) {
                keyTool.getStrategyFromFileName(file)
                val pass = askPassTwice
                if (pass != null){
                    try {
                       keyTool.save(file, pass)
                    } catch (Exception e) {
                       log.stacktrace(e)
                       alert(e.message)
                    }
                }else{
                    log.debug("password dialog canceled")
                }
            } else {
                log.debug("file dialog canceled")
            }
        }
    }

    def loadWallet() {
        //val fd = new FileDialogEx(parentFrame, "select wallet file")
        //fd.setFileFilters
        if (fc.showOpenDialog(this) == JFileChooser.APPROVE_OPTION) {
            try {
                keyTool.load(fc.selectedFile, null)
            } catch (Exception e) {
                log.stacktrace(e)
                alert(e.message)
            }
        }
    }

    def prompt(String msg) {
        JOptionPane.showInputDialog(this, msg)
    }

    def alert(String msg) {
        JOptionPane.showMessageDialog(this, msg)
    }

    def confirm(String msg){
        val answer = JOptionPane.showConfirmDialog(this, msg, null, JOptionPane.YES_NO_OPTION)
        return answer == JOptionPane.YES_OPTION
    }

    /**
     * prompt for password and confirmation.
     * @return String password or null if dialog was canceled
     */
    def askPassTwice(){
        while(true){
            val pass = prompt("please enter a pass phrase to encrypt the wallet")
            if (pass == null){
                return null
            }else{
                val pass2 = prompt("please repeat the pass phrase")
                if (pass2 == null){
                    return null
                } else {
                    if (pass2.equals(pass)){
                        return pass
                    } else {
                        alert("pass phrase not repeated correctly, please try again")
                    }
                }
            }
        }
    }

    def setFileFilters(JFileChooser fd){
        fd.addChoosableFileFilter(new FileNameExtensionFilter("Multibit backup", "key"))
        fd.setFileFilter(new FileNameExtensionFilter("Multibit wallet", "wallet"))
    }
}

