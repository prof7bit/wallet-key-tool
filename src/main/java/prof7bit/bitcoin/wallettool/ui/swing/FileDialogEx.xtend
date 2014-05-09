package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.Frame
import java.io.File
import javax.swing.JFileChooser
import java.awt.Dimension

/**
 * A file dialog that will remember the last folder it has been used in
 */
class FileDialogEx extends JFileChooser {
    static var current_directory = new File("")
    var Frame parent

    new(Frame parent, String title){
        super(title)
        preferredSize = new Dimension(600, 500)
        this.parent = parent
        currentDirectory = current_directory
    }

    def showOpen(){
        if (showOpenDialog(parent) == JFileChooser.APPROVE_OPTION) {
            current_directory = selectedFile
            true
        } else {
            false
        }
    }

    def showSave(){
        if (showSaveDialog(parent) == JFileChooser.APPROVE_OPTION) {
            current_directory = selectedFile
            true
        } else {
            false
        }
    }
}
