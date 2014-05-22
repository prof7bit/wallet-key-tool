package prof7bit.bitcoin.wallettool.ui.swing.core

import java.awt.Dimension
import java.io.File
import javax.swing.JButton
import javax.swing.JCheckBox
import javax.swing.JFileChooser
import javax.swing.JPanel
import net.miginfocom.swing.MigLayout

/**
 * this is a file chooser with an accessory panel
 * with buttons for showing hidden files and quickly
 * navigating to important bitcoin-related and not
 * so well known (to the average user) folders.
 */
class JFileChooserEx extends JFileChooser {
    new(){
        super()
        fileHidingEnabled = true
        preferredSize = new Dimension(800, 500)
        accessory = new JPanel => [panel|
            panel.layout = new MigLayout("fillx")
            new JCheckBox("show hidden files") => [
                panel.add(it, "pushx, growx, wrap")
                selected = !fileHidingEnabled
                addActionListener [evt|
                    fileHidingEnabled = !selected
                ]
            ]
            addDirButton(panel, "home", System.getProperty("user.home"))
            addDirButton(panel, "APPDATA", System.getenv("APPDATA"))
            addDirButton(panel, "~/Library/Application Support",
                System.getProperty("user.home") + "/Library/Application Support"
            )
        ]
    }

    private def addDirButton(JPanel panel, String label, String path){
        val f = getFileOrNull(path)
        if (f != null){
            new JButton(label) => [
                panel.add(it, "pushx, growx, wrap")
                addActionListener [
                    currentDirectory = f
                ]
            ]
        }
    }

    private def getFileOrNull(String path){
        if (path != null){
            val f = new File(path)
            if (f.exists){
                return f
            }
        }
        return null
    }
}
