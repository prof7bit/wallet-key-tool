package prof7bit.bitcoin.wallettool.ui.swing.core

import java.awt.Cursor
import java.awt.Dimension
import java.awt.Frame
import java.awt.Toolkit
import java.awt.datatransfer.StringSelection
import java.io.File
import javax.swing.JButton
import javax.swing.JFileChooser
import javax.swing.JLabel
import javax.swing.JMenuItem
import javax.swing.JOptionPane
import javax.swing.JPanel
import javax.swing.JPopupMenu
import javax.swing.JProgressBar
import javax.swing.JScrollPane
import javax.swing.JTable
import javax.swing.ScrollPaneConstants
import javax.swing.SwingUtilities
import javax.swing.border.BevelBorder
import javax.swing.filechooser.FileNameExtensionFilter
import net.miginfocom.swing.MigLayout
import org.slf4j.LoggerFactory
import prof7bit.bitcoin.wallettool.core.WalletKeyTool
import prof7bit.bitcoin.wallettool.fileformats.AbstractImportExportHandler
import prof7bit.bitcoin.wallettool.fileformats.MultibitHandler
import prof7bit.bitcoin.wallettool.fileformats.WalletDumpHandler
import prof7bit.bitcoin.wallettool.ui.swing.listeners.MouseDownListener
import prof7bit.bitcoin.wallettool.ui.swing.listeners.ResizeListener
import prof7bit.bitcoin.wallettool.ui.swing.misc.TableColumnAdjuster

import static extension prof7bit.bitcoin.wallettool.core.Ext.*

class WalletPanel extends JPanel{
    val log = LoggerFactory.getLogger(this.class)
    val Frame parentFrame

    @Property var WalletKeyTool keyTool = new WalletKeyTool => [
        promptFunc = [prompt(it)]
        alertFunc = [alert(it)]
        yesNoFunc = [confirm(it)]
        reportProgressFunc = [p, s | onProgress(p, s)]
    ]
    @Property var WalletKeyTool otherKeyTool = null
    @Property var String otherName = ""

    val btn_load = new JButton("load...") => [
        addActionListener [
            loadWallet
        ]
    ]

    val btn_save = new JButton("save as...") => [
        addActionListener [
            saveWallet
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

    val file_open = new JFileChooser => [
        addChoosableFileFilter(new FileNameExtensionFilter("Blockchain.info backup (*.aes.json)", "json"))
        addChoosableFileFilter(new FileNameExtensionFilter("Multibit key export file (*.key)", "key"))
        addChoosableFileFilter(new FileNameExtensionFilter("Bitcoin-core 'dumpwallet' file (*.txt)", "txt"))
        addChoosableFileFilter(new FileNameExtensionFilter("Bitcoin-core wallet.dat (*.dat)", "dat"))
        setFileFilter(new FileNameExtensionFilter("Multibit wallet (*.wallet)", "wallet"))
        preferredSize = new Dimension(600, 500)
    ]

    val file_save = new JFileChooser => [
        setAcceptAllFileFilterUsed(false)
        addChoosableFileFilter(new FileNameExtensionFilter("Multibit key export file (*.key)", "key"))
        addChoosableFileFilter(new FileNameExtensionFilter("Bitcoin-core 'dumpwallet' file (*.txt)", "txt"))
        setFileFilter(new FileNameExtensionFilter("Multibit wallet (*.wallet)", "wallet"))
        preferredSize = new Dimension(600, 500)
    ]

    val status_label = new JLabel("ready")
    val progress_bar = new JProgressBar => [
        minimum = 0
        maximum = 100
    ]
    val JPanel status_bar = new JPanel => [
        setBorder(new BevelBorder(BevelBorder.LOWERED))
        layout = new MigLayout("fill", "0[]0", "0[]0")
        add(progress_bar)
        add(status_label, "push, grow")
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
        add(status_bar, "dock south")
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
            var FileNameExtensionFilter filter
            var String filterExt
            var askPassword = true
            var Class<? extends AbstractImportExportHandler> strategy = null

            // we repeat the file dialog until we have a valid
            // file name or until the user clicks cancel.
            var repeatDialog = true
            while (repeatDialog) {
                if (file_save.showSaveDialog(this) == JFileChooser.APPROVE_OPTION) {
                    file = file_save.selectedFile
                    filter = file_save.fileFilter as FileNameExtensionFilter
                    filterExt = filter.extensions.get(0)
                    if (!filter.accept(file)){
                        file = new File(file.path + "." + filterExt)
                    }

                    if (file.exists){
                        alert("can not overwrite existing files. Please select a different file name")
                    } else {
                        switch(filterExt){
                            case "key"    : strategy = WalletDumpHandler
                            case "txt"    : {strategy = WalletDumpHandler; askPassword = false}
                            case "wallet" : strategy = MultibitHandler
                        }
                        repeatDialog = false
                        // here is where we exit the loop if all goes normal
                    }
                } else { // file dialog exited with cancel
                    repeatDialog = false
                    file = null
                }
            }

            if (file != null) {
                var String pass = ""
                if (askPassword){
                    pass = askPassTwice
                    // ""   = save unencrypted
                    // null = cancel
                }

                if (pass != null){
                    val ffile = file
                    val fpass = pass
                    val fstrategy = strategy
                    new Thread([|
                        try {
                           keyTool.save(ffile, fpass, fstrategy)
                        } catch (Exception e) {
                           log.stacktrace(e)
                           alert(e.message)
                        } finally {
                            SwingUtilities.invokeLater [|
                                onProgress(100, "")
                                keyTool.notifyChange
                            ]
                        }
                    ]).start
                }else{
                    log.debug("password dialog canceled")
                }
            }
        }
    }

    def loadWallet() {
        //val fd = new FileDialogEx(parentFrame, "select wallet file")
        //fd.setFileFilters
        if (file_open.showOpenDialog(this) == JFileChooser.APPROVE_OPTION) {
            new Thread([|
                try {
                    keyTool.load(file_open.selectedFile, null, null)
                } catch (Exception e) {
                    log.stacktrace(e)
                    alert(e.message)
                } finally {
                    SwingUtilities.invokeLater [|
                        onProgress(100, "")
                        keyTool.notifyChange
                    ]
                }
            ]).start
        }
    }

    def onProgress(int percent, String status){
        if (percent < 100){
            setCursor(Cursor.getPredefinedCursor(Cursor.WAIT_CURSOR))
            progress_bar.setValue(percent)
            status_label.text = status
        } else {
            setCursor(Cursor.getDefaultCursor())
            progress_bar.value = 0
            status_label.text = "ready"
        }
    }

    /**
     * prompt for password and confirmation.
     * @return String password or null if dialog was canceled
     */
    def askPassTwice(){
        while(true){
            val pass = prompt("please enter a pass phrase to encrypt the wallet")
            if (pass == null){
                return null // cancel
            }else{
                if (pass.length == 0){
                    // empty password means save unencrypted,
                    // we don't need to ask to repeat it
                    return pass
                }
                val pass2 = prompt("please repeat the pass phrase")
                if (pass2 == null){
                    return null // cancel
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

    def prompt(String msg) {
        callOnMainThread([|
            status_label.text = "waiting for user interaction"
            JOptionPane.showInputDialog(this, msg)
        ]) as String
    }

    def alert(String msg) {
        callOnMainThread([|
            status_label.text = "waiting for user interaction"
            JOptionPane.showMessageDialog(this, msg)
            return null
        ])
    }

    def confirm(String msg){
        callOnMainThread([|
            status_label.text = "waiting for user interaction"
            JOptionPane.showConfirmDialog(this, msg, null, JOptionPane.YES_NO_OPTION) == JOptionPane.YES_OPTION
        ]) as Boolean
    }

    def callOnMainThread(()=>Object func){
        if (SwingUtilities.eventDispatchThread){
            return func.apply
        } else {
            val Object[] ret = #[null] // need a final mutable object the closure can write to
            try {
                SwingUtilities.invokeAndWait [|
                    ret.set(0, func.apply)
                ]
            } catch (Exception e) {
                log.stacktrace(e)
                ret.set(0, null)
            }
            return ret.get(0)
        }
    }
}

