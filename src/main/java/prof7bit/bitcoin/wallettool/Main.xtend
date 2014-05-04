package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.store.UnreadableWalletException
import java.io.BufferedInputStream
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStreamReader
import org.spongycastle.crypto.params.KeyParameter

static class Main {

	static def void main(String[] args) {
		
		if (args.length != 1){
			val jarname = new File(Main.protectionDomain.codeSource.location.path).name
			println("usage: " + jarname + " <walletfile>");
		}else{
			val filename = args.get(0)
			dumpWallet(filename)
		}
	}
	
	static def dumpWallet(String filename){
		var FileInputStream fileInputStream = null
		var BufferedInputStream stream = null
		
		val walletFile = new File(filename)
		try {
			fileInputStream = new FileInputStream(walletFile)
			stream = new BufferedInputStream(fileInputStream)
			try {
				val wallet = Wallet.loadFromFileStream(stream)
				stream.close
				fileInputStream.close
				listKeys(wallet);
			} catch (UnreadableWalletException e) {
				println("unreadable wallet file: " + filename)
				e.printStackTrace
			}
			stream.close
			fileInputStream.close
		} catch (FileNotFoundException e) {
			println("file not found: " + filename)
		} catch (IOException e) {
			e.printStackTrace
		}
	}
	
	static def listKeys(Wallet wallet){
		val params = wallet.networkParameters
		val keyCrypter = wallet.keyCrypter
		val list = wallet.keychain
		var pass = "";
		var out = ""
		var KeyParameter aesKey = null
		var ECKey key_unenc = null		
		
		if (wallet.encrypted){
			pass = input("Wallet is encrypted. Enter passphrase")
			if (!pass.equals("")){
				println("deriving AES key from passphrase...")
				aesKey = keyCrypter.deriveKey(pass)
			}else{
				println("no passphrase entered, will skip decryption")
			}
		}
		
		for (key : list){
			System.out.print(key.toAddress(params))
			
			if (key.encrypted){
				if (aesKey == null){
					out = " KEY DECRYPTION SKIPPED"
				}else{
					try {
						key_unenc = key.decrypt(keyCrypter, aesKey)
						out = " DECRYPTED " + key_unenc.getPrivateKeyEncoded(params).toString 
					} catch (KeyCrypterException e) {
						out = " DECRYPTION ERROR " + key.getEncryptedPrivateKey().toString 
					}
				}
			}else{
				out = " UNENCRYPTED " + key.getPrivateKeyEncoded(params).toString
			}
			println(out)
		}
	}
	
	static def String input(String prompt){
		val br = new BufferedReader(new InputStreamReader(System.in))
	    print(prompt + ": ")
	    try {
	       br.readLine()
	    } catch (IOException ioe) {
	       println("IO error while reading interactive console input!")
	       System.exit(1)
	       ""
	    }
	}
}
