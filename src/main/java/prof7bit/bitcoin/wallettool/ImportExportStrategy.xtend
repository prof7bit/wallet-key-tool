package prof7bit.bitcoin.wallettool

import java.io.File

abstract class ImportExportStrategy {
    @Property var WalletKeyTool walletKeyTool

    /**
     * Load the keys or test whether this is the right file format. There
     * are two modes: First it will be called with pass=null. If it cannot
     * read the file without password it should throw an exception. It will
     * be called again with password and then again try to import or throw.
     */
    abstract def void load(File file, String pass) throws Exception

    /**
     * Save the keys. If password is "" then it should disable encryption
     */
    abstract def void save(File file, String pass) throws Exception
}
