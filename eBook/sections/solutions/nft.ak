use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/primitive/bytearray.{to_string}
use aiken/primitive/string.{to_bytearray}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, from_asset, from_asset_list, zero}
use cardano/transaction.{
  Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use mocktail/virgin_key_hash.{mock_policy_id, mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}

pub type Action {
  Mint
  Burn
}

validator custom_minting(
  utxo_ref: OutputReference,
  owner: Option<VerificationKeyHash>,
) {
  mint(rdmr: Action, policy_id: PolicyId, tx: Transaction) {
    let Transaction { inputs, mint, .. } = tx

    let assets =
      mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()

    when rdmr is {
      Mint -> {
        let is_token_name_valid = validate_token_name(assets)
        let is_mint_valid = validate_mint(assets, tx, inputs, utxo_ref, owner)

        is_token_name_valid? && is_mint_valid?
      }
      Burn -> {
        let is_burn_valid = validate_burn(assets)

        is_burn_valid?
      }
    }
  }

  else(_) {
    fail
  }
}

fn validate_token_name(tokens) {
  let token_names =
    [@"always", @"onetime", @"fenix"]

  if list.all(
    tokens,
    fn(Pair(name, _amount)) {
      list.any(token_names, fn(n) { n == to_string(name) })
    },
  ) {
    trace @"All token names correct!..."
    True
  } else {
    trace @"Ooops.... wrong token name found"
    False
  }
}

fn validate_mint(
  tokens: Pairs<ByteArray, Int>,
  tx: Transaction,
  inputs: List<Input>,
  utxo_ref: OutputReference,
  owner: Option<VerificationKeyHash>,
) {
  let fenix_exists =
    if list.any(
      tokens,
      fn(Pair(name, _amount)) { to_bytearray(to_string(name)) == "fenix" },
    ) {
      True
    } else {
      False
    }

  if list.all(
    tokens,
    fn(Pair(name, amount)) {
      when to_bytearray(to_string(name)) is {
        "always" ->
          if fenix_exists {
            amount < 0
          } else {
            amount >= 1
          }
        "onetime" ->
          if fenix_exists {
            amount < 0
          } else {
            expect Some(_input) =
              list.find(
                inputs,
                fn(input) { input.output_reference == utxo_ref },
              )
            expect Some(owner_vk) = owner
            let is_signed = list.has(tx.extra_signatories, owner_vk)
            is_signed && amount == 1
          }
        "fenix" -> and {
            amount >= 1,
            list.any(
              tokens,
              fn(Pair(name, amount)) {
                to_bytearray(to_string(name)) == "always" && amount < 0
              },
            ),
            list.any(
              tokens,
              fn(Pair(name, amount)) {
                to_bytearray(to_string(name)) == "onetime" && amount < 0
              },
            ),
          }
        _ -> False
      }
    },
  ) {
    trace @"Tokens for minting validated successfully"
    True
  } else {
    trace @"Ooops. Validation of tokens for minting failed"
    False
  }
}

fn validate_burn(tokens: Pairs<ByteArray, Int>) {
  if list.all(tokens, fn(Pair(_name, amount)) { amount < 0 }) {
    trace @"Tokens for spending/burning validated successfully"
    True
  } else {
    trace @"Ooops. Validation of tokens for spending/burning failed"
    False
  }
}

fn get_tx(mint, sign: List<VerificationKeyHash>) {
  let tx_input =
    Input {
      output_reference: mock_utxo_ref(0, 0),
      output: Output {
        address: Address {
          payment_credential: Script(mock_policy_id(0)),
          stake_credential: None,
        },
        value: zero,
        datum: NoDatum,
        reference_script: None,
      },
    }
  let tx_inputs =
    [tx_input]

  Transaction {
    ..placeholder,
    mint: mint,
    inputs: tx_inputs,
    extra_signatories: sign,
  }
}

// mock new test
test burn_always_and_onetime() {
  let utxo = mock_utxo_ref(0, 0)

  let test_asset_name1 = "always"
  let test_asset_name2 = "onetime"
  let mint =
    from_asset_list(
      [
        Pair(
          mock_policy_id(0),
          [Pair(test_asset_name1, -3), Pair(test_asset_name2, -1)],
        ),
      ],
    )

  let tx = get_tx(mint, [])

  custom_minting.mint(utxo, None, Burn, mock_policy_id(0), tx)
}

test burn_always() {
  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset_list([Pair(mock_policy_id(0), [Pair("always", -3)])])

  let tx = get_tx(mint, [])

  custom_minting.mint(utxo, None, Burn, mock_policy_id(0), tx)
}

test burn_onetime() {
  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset_list([Pair(mock_policy_id(0), [Pair("onetime", -1)])])

  let tx = get_tx(mint, [])

  custom_minting.mint(utxo, None, Burn, mock_policy_id(0), tx)
}

test burn_fenix() {
  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset_list([Pair(mock_policy_id(0), [Pair("fenix", -1)])])

  let tx = get_tx(mint, [])

  custom_minting.mint(utxo, None, Burn, mock_policy_id(0), tx)
}

test mint_fenix() {
  let utxo = mock_utxo_ref(0, 0)

  let test_asset_name1 = "always"
  let test_asset_name2 = "onetime"
  let test_asset_name3 = "fenix"
  let mint =
    from_asset_list(
      [
        Pair(
          mock_policy_id(0),
          [
            Pair(test_asset_name1, -3),
            Pair(test_asset_name3, 1),
            Pair(test_asset_name2, -1),
          ],
        ),
      ],
    )

  let tx = get_tx(mint, [])

  // minting fenix token burns always and onetime
  custom_minting.mint(utxo, None, Mint, mock_policy_id(0), tx)
}

test mint_always() {
  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset_list([Pair(mock_policy_id(0), [Pair("always", 3)])])

  let tx = get_tx(mint, [])

  custom_minting.mint(utxo, None, Mint, mock_policy_id(0), tx)
}

test mint_onetime() {
  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset_list([Pair(mock_policy_id(0), [Pair("onetime", 1)])])

  let tx = get_tx(mint, [mock_pub_key_hash(0)])

  custom_minting.mint(
    utxo,
    Some(mock_pub_key_hash(0)),
    Mint,
    mock_policy_id(0),
    tx,
  )
}

test fail_mint_onetime() fail {
  // Testing onetime minting with different input utxos
  // Error parameter is a wrong output reference in tx2

  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset_list([Pair(mock_policy_id(0), [Pair("onetime", 1)])])

  let tx = get_tx(mint, [mock_pub_key_hash(0)])

  let tx_input =
    Input {
      output_reference: mock_utxo_ref(1, 0),
      output: Output {
        address: Address {
          payment_credential: Script(mock_policy_id(0)),
          stake_credential: None,
        },
        value: zero,
        datum: NoDatum,
        reference_script: None,
      },
    }
  let tx_inputs =
    [tx_input]

  let tx2 =
    Transaction {
      ..placeholder,
      mint: mint,
      inputs: tx_inputs,
      extra_signatories: [mock_pub_key_hash(0)],
    }

  custom_minting.mint(
    utxo,
    Some(mock_pub_key_hash(0)),
    Mint,
    mock_policy_id(0),
    tx,
  ) && custom_minting.mint(
    utxo,
    Some(mock_pub_key_hash(0)),
    Mint,
    mock_policy_id(0),
    tx2,
  )
}

test mint_single_always() {
  let utxo = mock_utxo_ref(0, 0)

  let mint = from_asset(mock_policy_id(0), "always", 3)

  let tx = get_tx(mint, [])

  custom_minting.mint(utxo, None, Mint, mock_policy_id(0), tx)
}
