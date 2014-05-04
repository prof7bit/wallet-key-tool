package prof7bit.bitcoin.wallettool.ui.swing

import prof7bit.bitcoin.wallettool.IWallet
import javax.swing.table.TableModel
import javax.swing.event.TableModelListener

class WalletTableModel implements TableModel{
	var IWallet wallet;
	
	new(IWallet wallet){
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
			case 0: wallet.getAddress(rowIndex)
			case 1: wallet.getKey(rowIndex)
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