package prof7bit.bitcoin.wallettool.ui.swing

import java.awt.event.ComponentListener
import java.awt.event.ComponentEvent

class ResizeListener implements ComponentListener {
    var (ComponentEvent)=>void listener

    new((Object)=>void listener){
        this.listener = listener
    }

    override componentHidden(ComponentEvent e) {
    }

    override componentMoved(ComponentEvent e) {
    }

    override componentResized(ComponentEvent e) {
        listener.apply(e)
    }

    override componentShown(ComponentEvent e) {
    }

}
