package prof7bit.bitcoin.wallettool

interface IWallet {
	def void save()
	def void saveAs(String filename)
	def void load(String filename)
	def void dumpToConsole()
	def void setPromptFunction((String)=>String func)
	def int getKeyCount()
	def String getAddress(int i)
	def String getKey(int i)
}