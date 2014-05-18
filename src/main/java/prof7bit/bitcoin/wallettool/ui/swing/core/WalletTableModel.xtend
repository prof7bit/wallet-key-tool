package prof7bit.bitcoin.wallettool.ui.swing.core

import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import javax.swing.SwingUtilities
import javax.swing.table.AbstractTableModel
import prof7bit.bitcoin.wallettool.core.WalletKeyTool

class WalletTableModel extends AbstractTableModel {
    var WalletKeyTool kt;

    private val sdf = new SimpleDateFormat("yyyy-MM-dd") => [
        timeZone = TimeZone.getTimeZone("GMT")
    ]

    new(WalletKeyTool kt) {
        this.kt = kt
        kt.notifyChangeFunc = [
            // don't fire thousands of table updates while
            // the importer thread is adding keys to the list
            if (SwingUtilities.eventDispatchThread){
                fireTableDataChanged
            }
        ]
    }

    override getColumnClass(int columnIndex) {
        String
    }

    override getColumnCount() {
        5
    }

    override getRowCount() {
        kt.keyCount
    }

    override getColumnName(int columnIndex) {
        switch columnIndex {
            case 0: "address"
            case 1: "key"
            case 2: "creation date"
            case 3: "label"
            case 4: "balance"
        }
    }

    override getValueAt(int rowIndex, int columnIndex) {
        switch columnIndex {
            case 0: kt.getAddressStr(rowIndex)
            case 1: formatPrivateKey(kt.getPrivkeyStr(rowIndex))
            case 2: kt.getCreationTimeSeconds(rowIndex).formatDate
            case 3: kt.getLabel(rowIndex)
            case 4: formatBalance(kt.getBalance(rowIndex))
        }
    }

    private def formatDate(long unix){
        sdf.format(new Date(unix * 1000L))
    }

    private def formatPrivateKey(String key){
        if (key == null){
            return "WATCH ONLY"
        } else {
            return key
        }
    }

    private def formatBalance(long b){
        if (b<0){
            return ""
        } else {
            return b / 100000000D
        }
    }
}
