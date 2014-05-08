package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.FileDialog
import java.awt.Frame
import java.io.File

/**
 * A file dialog that will remember the last folder it has been used in
 */
class FileOpenDialog extends FileDialog {
    static var current_directory = new File("")

    new(Frame parent, String title){
        this(parent, title, null)
    }

    new(Frame parent, String title, File directory){
        super(parent, title)
        if (directory != null){
            current_directory = directory
        }
        this.directory = current_directory.path
    }

    def showOpen(){
        visible = true
        if (file != null){
            current_directory = new File(directory)
            true
        } else {
            false
        }
    }

    def getSelectedFile(){
        new File(directory, file)
    }
}
