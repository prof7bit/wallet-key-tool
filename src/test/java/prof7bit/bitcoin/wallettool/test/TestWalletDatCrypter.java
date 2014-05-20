package prof7bit.bitcoin.wallettool.test;
import static org.junit.Assert.assertArrayEquals;

import java.io.UnsupportedEncodingException;
import java.util.Formatter;

import org.junit.Test;
import org.spongycastle.crypto.params.KeyParameter;
import org.spongycastle.crypto.params.ParametersWithIV;

import prof7bit.bitcoin.wallettool.fileformats.WalletDatCrypter;


public class TestWalletDatCrypter {

    WalletDatCrypter crypter = new WalletDatCrypter();

    int iter = 171900;
    String pass = "test";
    byte[] salt = hex2bytes("126ba59f232b334d");
    byte[] stretch_exp = hex2bytes("33f7603022dfaf593edd539e08288d81ad7721b5fb485dbdf8ad43f4efb66dd9b4345c8024abdc2a1b6dfc78eb8d274f6fe6ef845a678d27761db3b3222a4c6b");
    byte[] key_exp = hex2bytes("33f7603022dfaf593edd539e08288d81ad7721b5fb485dbdf8ad43f4efb66dd9");
    byte[] iv_exp = hex2bytes("b4345c8024abdc2a1b6dfc78eb8d274f");

    byte[] encrypted  = hex2bytes("c4329e57804fd6d333cb5989a0d61b2961eb2caaa94ce8472c0409d8561e6ab023b65b39a0914d0911f6d3ec59b8eb7d");
    byte[] decrypted  = hex2bytes("ee54f57cfe1038fc4664d71de3507406db2a4a67082e19375992a2a17c585f0710101010101010101010101010101010");
    byte[] decrypted2 = hex2bytes("ee54f57cfe1038fc4664d71de3507406db2a4a67082e19375992a2a17c585f0700000000000000000000000000000000");

    @Test
    public void test_stretch() throws UnsupportedEncodingException {
        byte[] stretch_act = crypter.stretchPass(pass, salt, iter);
        assertArrayEquals(stretch_exp, stretch_act);
    }

    @Test
    public void test_key() throws UnsupportedEncodingException {
        ParametersWithIV key = crypter.getKeyParamFromPass(pass, salt, iter);
        assertArrayEquals(key_exp, ((KeyParameter)key.getParameters()).getKey());
        assertArrayEquals(iv_exp, key.getIV());
    }

    @Test
    public void test_decrypt() throws Exception {
        crypter.setKeyFromPassphrase(pass, salt, iter, 0);
        byte[] dec_actual = crypter.decrypt(encrypted);
        xprintln(decrypted2);
        xprintln(dec_actual);
        assertArrayEquals(decrypted2, dec_actual);
    }



    private byte[] hex2bytes(String s) {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                                 + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }


    private void xprintln(byte[] buf){
        Formatter formatter = new Formatter();
        for (byte b : buf){
            formatter.format("%02x", b);
        }
        System.out.print(buf.length * 8 + " ");
        System.out.println(formatter.toString());
        formatter.close();
    }
}
