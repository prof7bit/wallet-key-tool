package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Frame
import java.text.SimpleDateFormat
import java.util.TimeZone
import javax.swing.JButton
import javax.swing.JDialog
import javax.swing.JLabel
import javax.swing.JTextField
import net.miginfocom.swing.MigLayout
import prof7bit.bitcoin.wallettool.WalletKeyTool
import prof7bit.bitcoin.wallettool.KeyObject

class AddKeyDialog extends JDialog{

    var WalletKeyTool keyTool
    var KeyObject key = null

    val lbl_key = new JLabel("private key")
    val lbl_address = new JLabel("address")
    val lbl_year = new JLabel("year created")

    val txt_key = new JTextField() => [
        document.addDocumentListener(new DocumentChangedListener [
            ProcessInput
        ])
    ]

    val txt_address = new JTextField => [
        editable = false
    ]

    val txt_year = new JTextField => [
        text = "2009"
        document.addDocumentListener(new DocumentChangedListener [
            ProcessInput
        ])
    ]

    val btn_ok = new JButton("OK") => [
        enabled = false
        addActionListener [
            if (key != null){
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

    /**
     * use the values of private key and creation year to produce
     * a key with proper creation date. If any of the inputs is
     * invalid it will set key=null and disable the ok button.
     * If after this has been run key!=null then we know we have
     * a valid key.
     */
    def void ProcessInput() {
        // key must be valid AND have a valid creation date
        try {
            key = new KeyObject(txt_key.text.trim, keyTool.params)
            txt_address.text = key.addrStr
            val dfm = new SimpleDateFormat("yyyy");
            dfm.timeZone = TimeZone.getTimeZone("GMT")
            try {
                key.creationTimeSeconds = dfm.parse(txt_year.text).time / 1000
                btn_ok.enabled = true
            } catch (Exception e) {
                key = null
                btn_ok.enabled = false
            }
        } catch (Exception e){
            key = null
            btn_ok.enabled = false
            if (txt_key.text.length > 0) {
                txt_address.text = "<incomplete or invalid>"
            } else {
                txt_address.text = ""
            }
        }
    }
}
