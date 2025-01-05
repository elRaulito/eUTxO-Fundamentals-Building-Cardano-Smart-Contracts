import { Lucid , Blockfrost,toUnit,Data,Constr,  fromHex,
    toHex,sha256  } from "https://unpkg.com/lucid-cardano@0.10.0/web/mod.js"
  const lucid = await Lucid.new(
    new Blockfrost("https://cardano-mainnet.blockfrost.io/api/v0", "API KEY"),
    "Mainnet",
  );
  
  import cnftScript from './contract.json' assert {type: 'json'};

   //Here replace with the wallet name according to cip30
   var wallet="eternl"

   let api = await window.cardano[wallet].enable();
   lucid.selectWallet(api);
   window.owner=await lucid.wallet.address()
   let{ paymentCredential,stakeCredential } = lucid.utils.getAddressDetails(
   await lucid.wallet.address(),
   );

  //this is the most tricky part, go to https://cbor.me/ and paste this datum, replace the fields with your listing data and get the new datum to replace this one
  let datumCancel="D86682008441FB4133D866820082181814D866820180"

  //example
  //102([0, [h'SELLER_SPENDING_KEY_HASH', h'ROYALTY_SPENDING_KEY_HASH', 102([0, [//LISTING_PRICE, //ROYALTY_PERCENTAGE_IN_MILLESIMALS]]), 102([1, []])]])
  //102([0, [h'FB2CD544A148D0BBC70C9863E3448224EE95C3DB699F864F8D6305E2', h'3342CA8C073A11B7664BD105123353E79C01116CC465915133FDCF75', 102([0, [249999000000, 20]]), 102([1, []])]])



    var redeemerCancel=Data.to(
      new Constr(0,[])
    )


    //THIS IS THE TXHASH OF THE LISTING TO BE CANCELLED REPLACE IT
    const utxoHash="dbd761d11fa7dde62c4899b0168c6618789ad68d34560e9fd7a40e5d498d3044"
    const index=0

    var utxo=await lucid.utxosByOutRef([{ txHash: utxoHash, outputIndex: index }])
    utxo[0].datum=datumCancel

    const tx = await lucid
    .newTx()
    .collectFrom(utxo,redeemerCancel)
    .attachSpendingValidator(cnftScript)
    .addSignerKey(paymentCredential.hash)
    .complete();

    const signedTx = await tx.sign().complete();
    const txHash = await signedTx.submit();