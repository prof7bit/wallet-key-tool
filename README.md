# wallet-key-tool

Comfortable GUI application to edit the contents of various
Bitcoin wallet files, add or remove keys, read one format and
export to another, move keys between different wallets, etc.

## how to build from source

* have JDK 7 installed (6 will not work)
* clone this repository
* in the root directory execute: <pre>./gradlew assemble</pre>

you will find the runnable .jar file in build/libs/

## I'm too lazy to build it myself, where is the jar?

click the "releases" link (github project page in the
middle above the files listing) and look for the
"wallet-key-tool.jar" file, download and run it as
described below.

This release version might be a bit behind the latest
master branch, so I recommend to getting the source and
build it yourself, its really not that complicated, the
gradle build system does a wonderful job of automating
it all, you don't even need gradle to be installed, it
will download it for you.


## how to run

    java -jar wallet-key-tool.jar <filename>

will ask for a password (if the file is encrypted), then dump
the addresses and keys to the console and exit. If you run it
without file name

    java -jar wallet-key-tool.jar

it will show a simple Swing GUI where you can use a file dialog to
open the wallet file, a tabular interface to edit the wallet contents
comfortably using the mouse, move keys between two wallets and the
ability to export the edited files as new wallet files in all
supported file formats (currently only MultiBit).

Example session in the console (I did not enter a passphrase,
so no private keys to see here):

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
* have the Xtend plugin installed in Eclipse
* import -> gradle -> gradle project
* [browse] select the root folder of this project
* [build model] and wait a few seconds
* [select all] the project should be in the list, make sure its selected
* [finish] and wait another few seconds until import is complete



