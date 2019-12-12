
Grab and install Haskell
```
curl -sSL https://get.haskellstack.org/ | sh
```

get the wallet
```
git clone https://github.com/input-output-hk/cardano-wallet.git
```
go into the wallet directory
```
cd cardano-wallet
```
build the wallet
```
stack build --test --no-run-tests
```
get coffee...

when its done, install executables to your path
```
stack install
```
test to make sure cardano-wallet-jormungandr works fine and generate your new mnemonics you will need below

```
cardano-wallet-jormungandr mnemonic generate
```

For the next command you are launching the wallet as a service.  you can either open another terminal window or use screen or something.  anyway, wherever you run this next command you won't be able to use anymore for a terminal until you stop the wallet 

change --node-port 3001 to wherever you have your jormungandr rest interface running.  for me it was 5001..  so
change --port 3002 to wherever you want to access the wallet interface at.  If you have other things running avoid those ports.  for most, 3002 should be free
just to future proof these instructions.  genesis should be whatever genesis you are on.

```
cardano-wallet-jormungandr serve --node-port 3001 --port 3002 --genesis-block-hash e03547a7effaf05021b40dd762d5c4cf944b991144f1ad507ef792ae54603197
```

--->in another window
replace foo, foo, foo with all your mnemnomics from the byron wallet you are restoring

Also, if you put your wallet on a different port than 3002, fix that too

```
curl -X POST -H "Content-Type: application/json" -d '{ "name": "legacy_wallet", "mnemonic_sentence": ["foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo"], "passphrase": "areallylongpassword"}' http://localhost:3002/v2/byron-wallets

```
Thats going to spit out some information about a wallet it creates, you should see the value of your wallet - hopefully its not zero.  And you need the wallet ID for the next step

remember all those mnemnomics you made above.. put them here instead of all the foo's.

```
curl -X POST -H "Content-Type: application/json" -d '{ "name": "pool_wallet", "mnemonic_sentence": ["foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo","foo"], "passphrase": "areallylongpasswordagain"}' http://localhost:3002/v2/wallets
```
Important thing to get is the wallet id from this command


Now yuou are ready to migrate your wallet.  replace the <old wallet id> and <new wallet id> with the values you got above

```
curl -X POST -H "Content-Type: application/json" -d '{"passphrase": "areallylongpassword"}' http://localhost:3002/v2/byron-wallets/<old wallet id>/migrations/<new wallet id>
```
Congratulations.  your funds are now in your new wallet.  From here you can send to another address created like we have been doing throughout the testnet process, or you can find a way to extract the private key from this wallet and use that.

If you want to send to another address use this, but replace the address that you want to send it to, the amount, and your <new wallet id>
```
curl -X POST -H "Content-Type: application/json" -d '{"payments": [ { "address": "<address to send to>"", "amount": { "quantity": 83333330000000, "unit": "lovelace" } } ], "passphrase": "areallylongpasswordagain"}' http://localhost:3002/v2/wallets/<new wallet id>/transactions
```


