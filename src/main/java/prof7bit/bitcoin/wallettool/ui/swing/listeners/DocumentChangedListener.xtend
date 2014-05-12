package prof7bit.bitcoin.wallettool.ui.swing.listeners

import javax.swing.event.DocumentEvent
import javax.swing.event.DocumentListener

class DocumentChangedListener implements DocumentListener {

    var (DocumentEvent)=>void listener

    new ((DocumentEvent)=>void listener){
        this.listener = listener
    }

    override changedUpdate(DocumentEvent e) {
        listener.apply(e)
    }

    override insertUpdate(DocumentEvent e) {
        listener.apply(e)
    }

    override removeUpdate(DocumentEvent e) {
        listener.apply(e)
    }
}
