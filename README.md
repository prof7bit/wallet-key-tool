# wallet-key-tool

Dump addresses and private keys from a multibit wallet file to the console

## how to build from source

* have JDK 6 or 7 installed
* clone this repository
* in the root directory execute: <pre>./gradlew build</pre>

you will find the runnable .jar file in build/libs/

## I'm too lazy to do the above, where is the jar?

click the "releases" link (github project page in the middle above the files listing) and look for the "wallet-key-tool.jar" file, download and run it as described below.

## how to run

    java -jar wallet-key-tool.jar <filename>

Example session (I did not enter a passphrase, so no private keys to see here):

    java -jar build/libs/wallet-key-tool.jar /home/bernd/Schotter/Schotter.wallet 
    [main] INFO org.multibit.store.MultiBitWalletProtobufSerializer - Loading wallet extension org.multibit.walletProtect.2
    Wallet is encrypted. Enter passphrase: 
    no passphrase entered, will skip decryption
    1QKm5sWXuFJ6Zrvqw7NR7gYXyipPSqfv4n KEY DECRYPTION SKIPPED
    1DrL3o6ZMAGttc96SPxqTo2yooq52P62kf KEY DECRYPTION SKIPPED
    1E79vvzr1KkHXVXNUBwqoW7XDsMYULVqrq KEY DECRYPTION SKIPPED
    [...]


## How to import project in Eclipse

* have the gradle plugin installed in Eclipse
* import -> gradle -> gradle project
* [browse] select the root folder of this project
* [build model] and wait a few seconds
* [select all] the project should be in the list, make sure its selected
* [finish] and wait another few seconds until import is complete



