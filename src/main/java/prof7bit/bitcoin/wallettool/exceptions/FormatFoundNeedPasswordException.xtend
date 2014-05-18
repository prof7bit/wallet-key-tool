package prof7bit.bitcoin.wallettool.exceptions

import java.lang.Exception

/**
 * this is thrown during import format probing, during the first phase when
 * all strategies are asked to try importing without password. If a strategy is
 * 100% confident that it has identified the file format beyond any doubt and
 * only needs to be called again with password then it can throw this exception,
 * the probing of all other formats will then be canceled and the same strategy
 * will be called again with the password.
 */
class FormatFoundNeedPasswordException extends Exception {

}
