package prof7bit.bitcoin.wallettool.ui.swing.listeners

import java.awt.event.MouseEvent
import java.awt.event.MouseListener

class MousePressedOrReleasedListener implements MouseListener {

    var (MouseEvent)=>void listener

    new ((MouseEvent)=>void listener){
       this.listener = listener
    }

    override mousePressed(MouseEvent e) {
        this.listener.apply(e)
    }

    override mouseReleased(MouseEvent e) {
        this.listener.apply(e)
    }

    override mouseClicked(MouseEvent e) {}
    override mouseEntered(MouseEvent e) {}
    override mouseExited(MouseEvent e) {}
}
