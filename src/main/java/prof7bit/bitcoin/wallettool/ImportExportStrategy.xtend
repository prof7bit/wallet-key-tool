package prof7bit.bitcoin.wallettool

import java.io.File

abstract class ImportExportStrategy {
    @Property var WalletKeyTool walletKeyTool

    abstract def void load(File file, String pass) throws Exception
    abstract def void save(File file, String pass) throws Exception
}
