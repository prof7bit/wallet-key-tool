package prof7bit.bitcoin.wallettool

import java.io.File

abstract class ImportExportStrategy {
    @Property var WalletKeyTool walletKeyTool

    abstract def Boolean load(File file, String pass)
    abstract def Boolean save(File file, String pass)
}
