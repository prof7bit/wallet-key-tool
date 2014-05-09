package prof7bit.bitcoin.wallettool.ui.swing

import javax.swing.table.TableModel
import javax.swing.event.TableModelListener
import prof7bit.bitcoin.wallettool.AbstractWallet

class WalletTableModel implements TableModel {
    var AbstractWallet wallet;

    new(AbstractWallet wallet) {
        this.wallet = wallet
    }

    override addTableModelListener(TableModelListener l) {
        //
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
        wallet.keyCount
    }

    override getValueAt(int rowIndex, int columnIndex) {
        switch columnIndex {
            case 0: wallet.getAddressStr(rowIndex)
            case 1: wallet.getPrivkeyStr(rowIndex)
        }
    }

    override isCellEditable(int rowIndex, int columnIndex) {
        true
    }

    override removeTableModelListener(TableModelListener l) {
        //
    }

    override setValueAt(Object aValue, int rowIndex, int columnIndex) {
        //
    }
}
