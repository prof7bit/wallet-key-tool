package prof7bit.bitcoin.wallettool.fileformats

import java.io.File
import prof7bit.bitcoin.wallettool.core.WalletKeyTool

abstract class AbstractImportExportHandler {
    @Property var WalletKeyTool walletKeyTool

    /**
     * Load the keys or test whether this is the right file format. There
     * are two passes: First it will be called with password=null. If it cannot
     * read the file without password it should throw an exception. It will
     * later be called again with password. If even without password during
     * the first pass the handler is 100% confident that it recognizes this
     * file type and only needs the password then it may throw
     * FormatFoundNeedPasswordException which will cause the probing of all
     * other file formats to be canceled, the user will be asked for password
     * and it will be called again. Likewise with the secondary password, if
     * the handler determines it needs the secondary password it should
     * throw NeedSecondaryPasswordException and it will be called yet again
     * with the secondary password.
     */
    abstract def void load(File file, String password, String password2) throws Exception

    /**
     * Save the keys. If password is "" then it should disable encryption
     */
    abstract def void save(File file, String password, String password2) throws Exception
}
