package prof7bit.bitcoin.wallettool.ui.swing

import javax.swing.table.AbstractTableModel
import prof7bit.bitcoin.wallettool.WalletKeyTool

class WalletTableModel extends AbstractTableModel {
    var WalletKeyTool kt;

    new(WalletKeyTool kt) {
        this.kt = kt
        kt.notifyChangeFunc = [
            fireTableDataChanged
        ]
    }

    override getColumnClass(int columnIndex) {
        String
    }

    override getColumnCount() {
        2
    }

    override getColumnName(int columnIndex) {
        #["address", "key"].get(columnIndex)
    }

    override getRowCount() {
        kt.keyCount
    }

    override getValueAt(int rowIndex, int columnIndex) {
        switch columnIndex {
            case 0: kt.getAddressStr(rowIndex)
            case 1: kt.getPrivkeyStr(rowIndex)
        }
    }
}
