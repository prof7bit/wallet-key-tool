package prof7bit.bitcoin.wallettool.ui.swing

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.params.MainNetParams
import java.awt.Frame
import javax.swing.JButton
import javax.swing.JDialog
import javax.swing.JLabel
import javax.swing.JTextField
import net.miginfocom.swing.MigLayout
import prof7bit.bitcoin.wallettool.WalletKeyTool

class AddKeyDialog extends JDialog{

    var WalletKeyTool keyTool
    var ECKey key = null

    val lbl_key = new JLabel("private key")
    val lbl_address = new JLabel("address")
    val lbl_year = new JLabel("year created")

    val txt_key = new JTextField() => [txt|
        txt.document.addDocumentListener(new DocumentChangedListener [

            // FIXME: make this configurable and also move it to a better place
            if (keyTool.params == null) {
                keyTool.params = new MainNetParams
            }

            key = keyTool.privkeyStrToECKey(txt.text)
            if (key != null) {
                txt_address.text = keyTool.ECKeyToAddressStr(key)
                btn_ok.enabled = true
            } else {
                if (txt.text.length > 0) {
                    txt_address.text = "<incomplete or invalid>"
                } else {
                    txt_address.text = ""
                }
                btn_ok.enabled = false
            }
        ])
    ]

    val txt_address = new JTextField => [
        editable = false
    ]

    val txt_year = new JTextField => [
        text = "2009"
    ]

    val btn_ok = new JButton("OK") => [
        enabled = false
        addActionListener [
            if (key != null){
                key.creationTimeSeconds = 0
                keyTool.add(key)
                visible = false
            }
        ]
    ]

    val btn_cancel = new JButton("Cancel") => [
        addActionListener [
            visible = false
        ]
    ]

    new(Frame owner, WalletKeyTool keyTool) {
        super(owner, "Add key", true)
        this.keyTool = keyTool

        // layout

        layout = new MigLayout("fill", "[right][250,grow,fill][250,grow,fill]", "[][][][20,grow,fill][]")
        add(lbl_key)
        add(txt_key, "spanx 2, wrap")
        add(lbl_address)
        add(txt_address, "spanx 2, wrap")
        add(lbl_year)
        add(txt_year, "spanx 2, wrap")
        add(btn_cancel, "newline, skip")
        add(btn_ok)

        pack
        locationRelativeTo = owner
        visible = true
    }
}
