import {
    BlockfrostProvider,
    BrowserWallet,
    MeshTxBuilder,
    deserializeAddress,
    mConStr0,
  } from "@meshsdk/core"

  const provider = new BlockfrostProvider("API KEY");

  //contract.json contains the double CBOR encoded script, for example { "type": "PlutusV2", "script": "59..." }
  import cnftScript from './contract.json' assert {type: 'json'};

   //Here replace with the wallet name according to cip30
   var walletName="eternl"

   const wallet = await BrowserWallet.enable(walletName);
   window.owner=await wallet.getChangeAddress()
   const { pubKeyHash: paymentCredentialHash } = deserializeAddress(
   window.owner,
   );

  //this is the most tricky part, go to https://cbor.me/ and paste this datum, replace the fields with your listing data and get the new datum to replace this one
  let datumCancel="D86682008441FB4133D866820082181814D866820180"

  //example
  //102([0, [h'SELLER_SPENDING_KEY_HASH', h'ROYALTY_SPENDING_KEY_HASH', 102([0, [//LISTING_PRICE, //ROYALTY_PERCENTAGE_IN_MILLESIMALS]]), 102([1, []])]])
  //102([0, [h'FB2CD544A148D0BBC70C9863E3448224EE95C3DB699F864F8D6305E2', h'3342CA8C073A11B7664BD105123353E79C01116CC465915133FDCF75', 102([0, [249999000000, 20]]), 102([1, []])]])



    var redeemerCancel=mConStr0([])


    //THIS IS THE TXHASH OF THE LISTING TO BE CANCELLED REPLACE IT
    const utxoHash="dbd761d11fa7dde62c4899b0168c6618789ad68d34560e9fd7a40e5d498d3044"
    const index=0

    const [scriptUtxo]=await provider.fetchUTxOs(utxoHash, index)

    const utxos=await wallet.getUtxos()
    const collateral=(await wallet.getCollateral())[0]

    const txBuilder = new MeshTxBuilder({
      fetcher: provider,
      submitter: provider,
    });

    await txBuilder
    .spendingPlutusScriptV2()
    .txIn(
      scriptUtxo.input.txHash,
      scriptUtxo.input.outputIndex,
      scriptUtxo.output.amount,
      scriptUtxo.output.address
    )
    .txInScript(cnftScript.script)
    .txInDatumValue(datumCancel, "CBOR")
    .txInRedeemerValue(redeemerCancel)
    .requiredSignerHash(paymentCredentialHash)
    .txInCollateral(
      collateral.input.txHash,
      collateral.input.outputIndex,
      collateral.output.amount,
      collateral.output.address
    )
    .changeAddress(window.owner)
    .selectUtxosFrom(utxos)
    .complete();

    const signedTx = await wallet.signTx(txBuilder.txHex);
    const txHash = await wallet.submitTx(signedTx);
