package prof7bit.bitcoin.wallettool

import java.io.File

interface IWallet {
    def void load(File file)
    def void save(File file)
    def void dumpToConsole()
    def void setPromptFunction((String)=>String func)
    def int getKeyCount()
    def String getAddress(int i)
    def String getKey(int i)
}
