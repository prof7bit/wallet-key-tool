package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Frame
import javax.swing.JButton
import javax.swing.JDialog
import javax.swing.JLabel
import javax.swing.JTextField
import net.miginfocom.swing.MigLayout
import prof7bit.bitcoin.wallettool.WalletKeyTool

class AddKeyDialog extends JDialog{

    val lbl_key = new JLabel("private key")
    val lbl_address = new JLabel("address")
    val txt_key = new JTextField()
    val txt_address = new JTextField => [
        editable = false
        text = "This dialog is not yet implemented"
    ]

    val btn_ok = new JButton("OK") => [
        addActionListener [
            visible = false
        ]
    ]

    val btn_cancel = new JButton("Cancel") => [
        addActionListener [
            visible = false
        ]
    ]

    new(Frame owner, WalletKeyTool keyTool) {
        super(owner, "Add key", true)

        // layout

        layout = new MigLayout("fill", "[right][150,grow,fill][150,grow,fill]", "[][][20,grow,fill][]")
        add(lbl_key)
        add(txt_key, "spanx 2, wrap")
        add(lbl_address)
        add(txt_address, "spanx 2, wrap")
        add(btn_cancel, "newline, skip")
        add(btn_ok)

        pack
        locationRelativeTo = owner
        visible = true
    }
}
