package prof7bit.bitcoin.wallettool.test

import java.io.UnsupportedEncodingException
import org.junit.Assert
import org.junit.Test
import org.spongycastle.crypto.params.KeyParameter
import prof7bit.bitcoin.wallettool.fileformats.WalletDatCrypter

import static extension prof7bit.bitcoin.wallettool.test.Ext.*
import org.spongycastle.crypto.InvalidCipherTextException

public class TestWalletDatCrypter {

    WalletDatCrypter crypter = new WalletDatCrypter()

    /**
     * key stretching function used in bitcoin wallet: sha512(pass + salt) multiple times
     */
    @Test
    def test_stretch() throws UnsupportedEncodingException {
        val pass        = "test"
        val salt        = "126ba59f232b334d".hex2bytes
        val iter        = 171900
        val stretch_exp = "33f7603022dfaf593edd539e08288d81ad7721b5fb485dbdf8ad43f4efb66dd9b4345c8024abdc2a1b6dfc78eb8d274f6fe6ef845a678d27761db3b3222a4c6b".hex2bytes

        val stretch_act = crypter.stretchPass(pass, salt, iter)
        Assert.assertArrayEquals(stretch_exp, stretch_act)
    }

    /**
     * derive key parameters (iv and key) from password and salt
     */
    @Test
    def test_key() throws UnsupportedEncodingException {
        val pass        = "test"
        val salt        = "126ba59f232b334d".hex2bytes
        val iter        = 171900
        val key_exp     = "33f7603022dfaf593edd539e08288d81ad7721b5fb485dbdf8ad43f4efb66dd9".hex2bytes
        val iv_exp      = "b4345c8024abdc2a1b6dfc78eb8d274f".hex2bytes

        val key = crypter.getKeyParamFromPass(pass, salt, iter)
        Assert.assertArrayEquals(key_exp, (key.getParameters() as KeyParameter).getKey())
        Assert.assertArrayEquals(iv_exp, key.getIV())
    }

    /**
     * decrypting an encrypted master key with password and salt
     */
    @Test
    def test_decrypt_mkey() throws Exception {
        val pass        = "test"
        val salt        = "126ba59f232b334d".hex2bytes
        val iter        = 171900
        val encrypted   = "c4329e57804fd6d333cb5989a0d61b2961eb2caaa94ce8472c0409d8561e6ab023b65b39a0914d0911f6d3ec59b8eb7d".hex2bytes
        val decrypted   = "ee54f57cfe1038fc4664d71de3507406db2a4a67082e19375992a2a17c585f07".hex2bytes

        val dec_actual = crypter.decrypt(encrypted, pass, salt, iter, 0)
        Assert.assertArrayEquals(decrypted, dec_actual)
    }

    /**
     * decrypting an encrypted private key using mkey and iv
     */
    @Test
    def test_decrypt_privkey() throws InvalidCipherTextException {
        val ckey        = "1cdb048a69a35ce026053810296ed9161bd7ec3bb61350c632ed0a0edb1e1b1d5e2d0f7278a1b98369fd7742fe823a3d".hex2bytes
        val mkey        = "ee54f57cfe1038fc4664d71de3507406db2a4a67082e19375992a2a17c585f07".hex2bytes
        val iv          = "7aa9308e3ab81b4c3e98596f0beafe16".hex2bytes
        val decrypted   = "38d1e2cbf2f474949bef51dd3ac6e31a75e600648c2a18496e819001cf49b33c".hex2bytes

        // using mkey and iv
        crypter.setKeyAndIV(mkey, iv)
        val decrypted_act = crypter.decrypt(ckey)
        Assert.assertArrayEquals(decrypted, decrypted_act)

    }
    /**
     * decrypting an encrypted private key using mkey and pubkey
     */
    @Test
    def test_decrypt_privkey2() throws InvalidCipherTextException {
        val ckey        = "1cdb048a69a35ce026053810296ed9161bd7ec3bb61350c632ed0a0edb1e1b1d5e2d0f7278a1b98369fd7742fe823a3d".hex2bytes
        val mkey        = "ee54f57cfe1038fc4664d71de3507406db2a4a67082e19375992a2a17c585f07".hex2bytes
        val pub_key     = "0200e8e2ce78be4716e11aeecb4c52e982e75be735a53ede34913ae03350e2cfd5".hex2bytes
        val decrypted   = "38d1e2cbf2f474949bef51dd3ac6e31a75e600648c2a18496e819001cf49b33c".hex2bytes

        // using pubkey and mkey
        val decrypted_act = crypter.decrypt(ckey, mkey, pub_key)
        Assert.assertArrayEquals(decrypted, decrypted_act)
    }

    /**
     * the double hash: sha256(sha256(x))
     */
     @Test
    def test_hash(){
        val pub_key     = "0200e8e2ce78be4716e11aeecb4c52e982e75be735a53ede34913ae03350e2cfd5".hex2bytes
        val hash        = "7aa9308e3ab81b4c3e98596f0beafe16c663535ad1fd1594ce1ebed5f58f0144".hex2bytes

        val hash_act = crypter.doubleHash(pub_key)
        Assert.assertArrayEquals(hash, hash_act)
    }

}
