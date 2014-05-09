package prof7bit.bitcoin.wallettool

class KeyPair {
    @Property var address = ""
    @Property var privkey = ""
    @Property var errorstr = ""

    def hasKey(){
        privkey.length > 0
    }

    def hasError(){
        errorstr.length > 0
    }
}
