package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.DumpedPrivateKey
import com.google.bitcoin.core.NetworkParameters
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.crypto.KeyCrypterScrypt
import com.google.bitcoin.params.MainNetParams
import java.io.File
import org.spongycastle.crypto.params.KeyParameter

import static extension prof7bit.bitcoin.wallettool.Ext.*

/**
 * This is my own wrapper around a MultiBit wallet. It wraps
 * an instance of com.google.bitcoin.core.Wallet and uses it
 * to load/save and decrypt/encrypt the keys. It does NOT care
 * about transaction history, if it is used to import keys from
 * other wallets or add/remove individual keys then all tx
 * history will be stripped away, it will just be a container
 * for the keys and the block chain will have to be replayed
 * after opening the modified wallet with MultiBit.
 */
class MultibitWallet extends AbstractWallet {
    var Wallet mbwallet
    var NetworkParameters mbparams
    var KeyParameter aesKey = null

    new((String)=>String promptFunction, (String)=>void alertFunction) {
        super(promptFunction, alertFunction)
    }

    override save(File file, String passphrase) {
        if (aesKey != null){
            // actually this is not meant to happen, the way I think I'm
            // going to implement it is to load a new temporary wallet
            // from an existing one, then encrypt, save and dispose it.
            // Therefore this save() method would only ever be called on
            // newly created unencrypted wallets that are only instantiated
            // for this one purpose and disposed immediately afterwards.
            throw new IllegalStateException("Congratulations, you just found a bug")
        } else {
            log.debug("encrypting with new pass phrase")
            val scrypt = new KeyCrypterScrypt
            aesKey = scrypt.deriveKey(passphrase)
            mbwallet.encrypt(scrypt, aesKey)
            mbwallet.saveToFile(file)
            log.info("A MultiBit wallet with {} keys has been saved to {}",
                mbwallet.keychain.length, file.path
            )
        }
    }

    /**
     * Load MultiBit wallet from the .wallet file
     */
    override load(File file) {
        log.debug("loading wallet file: " + file.path)
        try {
            mbwallet = Wallet.loadFromFile(file)
            mbparams = mbwallet.networkParameters
            if (mbwallet.encrypted) {
                log.debug("wallet is encrypted")
                val pass = promptFunction.apply("Wallet is encrypted. Enter pass phrase")
                if (pass == null || pass.length == 0) {
                    aesKey = null
                } else {
                    aesKey = mbwallet.keyCrypter.deriveKey(pass)
                }
            }
            loaded = true
            log.info("MultiBit wallet with {} addresses has been loaded",
                mbwallet.keychain.length
            )
        } catch (Exception e) {
            log.stacktrace(e)
        }
    }

    /**
     * Load this MultiBit wallet with the keys from another IWallet.
     * The existing contents of this wallet will be replaced.
     * this is used for converting between different wallet formats.
     */
    override load(AbstractWallet other_wallet){
        mbparams = new MainNetParams
        mbwallet = new Wallet(mbparams)
        for (i : 0..<other_wallet.keyCount) {
            val kp = other_wallet.getKeyPair(i)
            if (kp.hasKey){
                val dpk = new DumpedPrivateKey(mbparams, kp.privkey)
                mbwallet.keychain.add(dpk.key)
            }
        }
        loaded = true
        aesKey = null
        log.debug("A new MultiBit wallet with {} keys has been instantiated",
            mbwallet.keychain.length
        )
    }

    override dumpToConsole() {
        if (loaded){
            if (mbwallet.encrypted && aesKey == null) {
                println("no password entered, will not show keys")
            }
            for (i : 0 ..< keyCount) {
                println(getAddressStr(i) + " " + getPrivkeyStr(i))
            }
        } else {
            log.error("no wallet data was loaded")
        }
    }

    override getKeyCount() {
        mbwallet.keychain.length
    }

    override getKeyPair(int i) {
        val kp = new KeyPair
        val mbkey = mbwallet.keychain.get(i)
        kp.address = mbkey.toAddress(mbparams).toString
        if (mbkey.encrypted){
            if (aesKey != null) {
                try {
                    val mbkey_unenc = mbkey.decrypt(mbwallet.keyCrypter, aesKey)
                    kp.privkey = mbkey_unenc.getPrivateKeyEncoded(mbparams).toString
                } catch (KeyCrypterException e) {
                    kp.errorstr = "DECRYPTION ERROR " + mbkey.encryptedPrivateKey.toString
                }
            } else {
                kp.errorstr = "MISSING PASSPHRASE"
            }
        } else {
            kp.privkey = mbkey.getPrivateKeyEncoded(mbparams).toString
        }
        kp
    }

    override getAddressStr(int i) {
        getKeyPair(i).address
    }

    override getPrivkeyStr(int i) {
        val addr = getKeyPair(i)
        if (addr.hasKey) {
            addr.privkey
        } else {
            addr.errorstr
        }
    }

}
