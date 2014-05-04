package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Dimension
import javax.swing.JButton
import javax.swing.JFileChooser
import javax.swing.JFrame
import javax.swing.JOptionPane
import javax.swing.JScrollPane
import javax.swing.JTable
import javax.swing.ScrollPaneConstants
import javax.swing.SwingUtilities
import net.miginfocom.swing.MigLayout
import prof7bit.bitcoin.wallettool.IWallet
import prof7bit.bitcoin.wallettool.MultibitWallet

class SwingMain {
	
  	static var IWallet wallet
  	static var filename = ""
  	 
    static def start() {
        SwingUtilities.invokeLater [|
        	wallet = new MultibitWallet
        	wallet.promptFunction = [
				JOptionPane.showInputDialog(it)
			]
			
	        val frame = new JFrame("wallet-key-tool")
	        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE	        
			val button = new JButton("open")
			val table = new JTable			
			
			button.addActionListener [
				val fc = new JFileChooser(filename);
				fc.fileHidingEnabled = false
				if (fc.showOpenDialog(frame) == JFileChooser.APPROVE_OPTION){
					filename = fc.selectedFile.canonicalPath
					wallet.load(filename)
					table.model = new WalletTableModel(wallet)
				}
			]
			

			// layout

			frame.layout = new MigLayout("fill")			
			frame.add(button, "wrap")
			
			val tablePane = new JScrollPane(table)
			tablePane.viewportView = table
        	tablePane.verticalScrollBarPolicy = ScrollPaneConstants.VERTICAL_SCROLLBAR_AS_NEEDED 
        	table.fillsViewportHeight = true
			frame.add(tablePane, "grow, push")
			
			frame.preferredSize = new Dimension(1000, 500)
	        frame.pack
	        frame.visible = true
        ]
    }
}